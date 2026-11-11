@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class, kotlinx.cinterop.BetaInteropApi::class)

package com.langhuan.reader.ui.book.read

import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.toArgb
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.BookChapter
import com.langhuan.reader.help.AppWebDavShared
import com.langhuan.reader.help.book.BookImageDownloadShared
import com.langhuan.reader.help.showSourceLogin
import com.langhuan.reader.help.book.isEpub
import com.langhuan.reader.help.book.isLocal
import com.langhuan.reader.help.book.isLocalTxt
import com.langhuan.reader.help.book.isNotShelf
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.help.config.AppConfigProviders
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.help.config.ReadBookConfigProviders
import com.langhuan.reader.help.config.ThemeConfigProviders
import com.langhuan.reader.help.storage.BackupShared
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.help.tts.IosReadAloudHost
import com.langhuan.reader.ui.book.read.ReadBookEvents
import com.langhuan.reader.ui.book.read.page.SelectionGeometry
import com.langhuan.reader.ui.compose.platform.SharedThemeStoreProvider
import com.langhuan.reader.ui.root.AppNavigatorProviders
import com.langhuan.reader.ui.root.AppOverlay
import com.langhuan.reader.ui.reader.ReaderImageActionMenu
import com.langhuan.reader.ui.reader.ReaderImageActions
import com.langhuan.reader.ui.reader.ReaderTextActionMenu
import com.langhuan.reader.ui.reader.ReaderTextActions
import com.langhuan.reader.ui.reader.ReaderTextSelectionRequest
import com.langhuan.reader.ui.reader.readerMenuAnchor
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.RouteResults
import com.langhuan.reader.ui.root.toRouteRef
import com.langhuan.reader.ui.widget.dialog.encodePhotoOverlayPayload
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.usePinned
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import platform.Foundation.NSData
import platform.Foundation.create
import platform.UIKit.UIDevice
import platform.UIKit.UIImage
import platform.UIKit.UIImageWriteToSavedPhotosAlbum

/**
 * iOS 阅读页平台能力: 菜单可见/可切, 导航经 [AppNavigator] 桥接, 电量用 [UIDevice]。
 *
 * 结构对照 desktop `DesktopReaderPlatformProvider` (顶/底栏 UI 由 shared ReadMenuOverlay
 * 渲染, 此处只持有状态 + 导航回调); 差异仅 getBatteryLevel 用 UIDevice 真实电量。
 *
 * 朗读已接入: 短按经 [IosReadAloudHost] (ReadAloudControllerShared) 启动/暂停/恢复,
 * 长按弹共享朗读控制面板; 退出阅读页停朗读 (iOS 无前台 Service 维持阅读实例;
 * 播放期间的锁屏/控制中心播控卡片由 SystemMediaControl 接管, 见 IosMediaNotificationController)。
 *
 * # 不实现
 * - 沉浸式色彩: 纯色阅读背景时菜单栏跟随阅读背景色+文字色 (shared createReadMenuColors,
 *   同 desktop); 图片阅读背景/无窗口背景图时用 AppTheme 默认色
 */
object IosReaderPlatformProvider : ReaderPlatformProvider {

    /** 图片长按动作协程 scope (Main: UIKit 操作/toast 需主线程, 网络下载在 loadBytes 内部切 IO)。 */
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /** 页内文字选择请求 (null = 不显示自绘浮动菜单), 由 [TextSelectionHost] 渲染。 */
    private var textSelection by mutableStateOf<ReaderTextSelectionRequest?>(null)

    /** 当次选择的动作集: 动作要 screenModel, 故在 onTextSelected 装配好存下。 */
    private var textActions by mutableStateOf<ReaderTextActions?>(null)

    override fun createMenuController(
        navigator: AppNavigator,
        screenModel: ReaderScreenModel,
    ): ReadMenuController = IosReadMenuController(navigator, screenModel)

    /**
     * 本窗口已接纳的绑定身份 = (页面模型, 控制器)。
     *
     * 只记 controller 不够: 同一个 provider 可能先后服务两个阅读页, 旧页 `onExit` 会把新页的
     * 控制器当成"自己的"释放掉。带上 model 后, 释放/退出只作用于自己这条绑定。
     */
    private var activeMenuBinding: Pair<ReaderScreenModel, ReadMenuController>? = null

    override fun activateMenuController(
        screenModel: ReaderScreenModel,
        controller: ReadMenuController,
    ) {
        activeMenuBinding = screenModel to controller
    }

    override fun releaseMenuController(
        screenModel: ReaderScreenModel,
        controller: ReadMenuController,
    ) {
        if (activeMenuBinding?.first === screenModel && activeMenuBinding?.second === controller) {
            activeMenuBinding = null
        }
    }

    // TTS 语速变更后重新应用当前语速 (重读配置 + pause/resume 让新语速立刻作用到当前段;
    // 本方法不写配置, 只按现配置重放)
    override fun upTtsSpeechRate(screenModel: ReaderScreenModel) = IosReadAloudHost.upSpeechRate()

    /**
     * 图片长按: 弹共享自绘浮动菜单 (查看/刷新/保存; iOS 无 SAF"选择目录", 保存直落系统相册)。
     * 菜单项收尾对照原版 popupAction 点击 → onDismiss → postSelectionCancel。
     */
    override fun onImageLongPress(screenModel: ReaderScreenModel, src: String, x: Float, y: Float) {
        if (src.isBlank()) return
        ReaderImageActionMenu.show(
            anchor = readerMenuAnchor(x, y),
            actions = ReaderImageActions(
                view = { viewImage(screenModel, src) },
                refresh = {
                    refreshReaderImage(screenModel.currentBook, screenModel.currentChapter, src)
                },
                save = { saveImageToAlbum(screenModel, src) },
            ),
        )
    }

    /**
     * 页内文字选择完成: 弹共享自绘浮动文本操作菜单
     * (见 [ReaderTextActionMenu], 宿主 [TextSelectionHost] 挂在 MainViewController 根组合)。
     */
    override fun onTextSelected(
        screenModel: ReaderScreenModel,
        text: String,
        geometry: SelectionGeometry,
    ) {
        if (text.isBlank()) return
        textActions = ReaderTextActions(
            onReplace = screenModel.replaceTextCallback(),
            onBookmark = screenModel.bookmarkTextCallback(),
            onUnderline = screenModel.underlineTextCallback(),
            onReadAloud = screenModel.readAloudTextCallback(),
            onSearchContent = screenModel.searchContentTextCallback(),
        )
        textSelection = ReaderTextSelectionRequest(text = text, geometry = geometry)
    }

    /**
     * 页内选区已消失（点按取消选择/翻页/重排等任意路径）：收起浮动菜单
     * （对照原版 onCancelSelect → textActionMenu.dismiss）。幂等：菜单未显示时无操作。
     */
    override fun onTextSelectionDismissed(screenModel: ReaderScreenModel) = dismissActionMenus()

    /**
     * 同步立即关闭浮动菜单（点按取消选择等手势分支同帧同步直调，对照原版 ACTION_DOWN →
     * textActionMenu.dismiss() 同步语义，避免事件链异步延迟的菜单"闪一下再消失"）。
     * 幂等，事件链兜底重复调用安全。
     */
    override fun dismissTextActionMenu(screenModel: ReaderScreenModel) = dismissActionMenus()

    /** 对照 master ReadBookActivity.cancelSelect: 文本/图片菜单互斥, 同时 dismiss。 */
    private fun dismissActionMenus() {
        textSelection = null
        ReaderImageActionMenu.dismiss()
    }

    /** 阅读页销毁: 释放控制器/协程; 收起浮动菜单 + 停朗读, 避免残留 (对照原版 onDestroy → textActionMenu.dismiss)。
     *  iOS 无前台 Service 维持阅读实例 (朗读在进程内编排), 离开阅读页即失去阅读上下文, 显式停止;
     *  播放期间的锁屏/控制中心播控卡片 (SystemMediaControl) 随 stop 一并撤下。 */
    override fun onExit(screenModel: ReaderScreenModel) {
        // 只放自己这条绑定 (不经模型取新控制器)
        activeMenuBinding
            ?.takeIf { it.first === screenModel }
            ?.second
            ?.let { releaseMenuController(screenModel, it) }
        dismissActionMenus()
        textActions = null
        IosReadAloudHost.stop()
        BackupShared.autoBack()
    }

    /**
     * 阅读页文本操作菜单宿主 (挂在 MainViewController 根组合, 对照 desktop
     * DesktopReaderPlatformProvider.TextSelectionHost)。
     */
    @Composable
    fun TextSelectionHost() {
        val actions = textActions ?: return
        ReaderTextActionMenu(
            request = textSelection,
            actions = actions,
            // 对照原版 onMenuActionFinally: 关菜单 + 取消页内选择
            onFinally = {
                textSelection = null
                ReadBookEvents.postSelectionCancel()
            },
        )
    }

    /** 查看大图: 弹共享全屏大图 Overlay (key="photo", 口径同 desktop/ohos/android)。 */
    private fun viewImage(screenModel: ReaderScreenModel, src: String) {
        val book = screenModel.currentBook
        AppNavigatorProviders.get().showOverlay(
            AppOverlay.Dialog(
                key = "photo",
                payload = encodePhotoOverlayPayload(
                    src, screenModel.viewModel.durChapterIndex.value
                ),
                sourceOrigin = book?.origin?.takeIf { !book.isLocal && it.isNotBlank() },
            )
        )
    }

    /** 保存到相册: 读已缓存图片字节 → UIImageWriteToSavedPhotosAlbum (无完成回调, 保存后提示)。 */
    private fun saveImageToAlbum(screenModel: ReaderScreenModel, src: String) {
        Toasters.get().toast("正在保存")
        scope.launch {
            val image = loadCachedImage(screenModel.currentBook, screenModel.currentChapter, src)
            if (image == null) {
                Toasters.get().toast("图片保存失败")
                return@launch
            }
            UIImageWriteToSavedPhotosAlbum(image, null, null, null)
            Toasters.get().toast("已保存到相册")
        }
    }

    /**
     * 取已缓存的图并解成 [UIImage] (只读缓存/本地书内嵌图, 不触发下载); 取不到返回 null。
     *
     * 字节读取在 [BookImageDownloadShared.imageBytesToSave] 内部切 IO, 返回后可直接操作 UIKit。
     */
    private suspend fun loadCachedImage(book: Book?, chapter: BookChapter?, src: String): UIImage? {
        val bytes = book?.let { BookImageDownloadShared.imageBytesToSave(it, src, chapter) }
            ?: return null
        return runCatching {
            val nsData = bytes.usePinned { pinned ->
                NSData.create(bytes = pinned.addressOf(0), length = bytes.size.toULong())
            }
            UIImage.imageWithData(nsData)
        }.getOrNull()
    }

    // UIDevice 电池监控: 返回 0~100, 未启用或未知回落 100 (用户拍板 2026-08: 电量恒显示)
    override fun getBatteryLevel(): Int {
        val device = UIDevice.currentDevice
        if (!device.batteryMonitoringEnabled) {
            device.batteryMonitoringEnabled = true
        }
        val level = device.batteryLevel
        return if (level < 0f) 100 else (level * 100).toInt()
    }

    /** 朗读控制桥: 长按面板动作落到 [IosReadAloudHost] + 偏好项 (对照 desktop DesktopReadAloudControls)。 */
    override fun readAloudControls(
        navigator: AppNavigator,
        screenModel: ReaderScreenModel,
    ): ReadAloudControls = IosReadAloudControls(navigator, screenModel)
}

private class IosReadMenuController(
    navigator: AppNavigator,
    screenModel: ReaderScreenModel,
) : ReadMenuController {
    override val state: ReadMenuState = IosReadMenuState(navigator, screenModel)
    override fun showMenu() = (state as IosReadMenuState).show()
    override fun hideMenu() = (state as IosReadMenuState).hide()
}

/**
 * iOS 阅读菜单状态: visibleState 可切, 字段从 screenModel.viewModel 取实时值。
 * 菜单显隐时刷新动态项 (书源按钮/顶栏勾选/夜间态), 对齐 app 端 AndroidReaderMenuState.show()。
 */
private class IosReadMenuState(
    navigator: AppNavigator,
    screenModel: ReaderScreenModel,
) : BaseReadMenuState(navigator, screenModel) {

    // 菜单栏配色 (对照原版 ReadMenu.upColorConfig, 逻辑见 shared createReadMenuColors)
    private val menuTheme: ReadMenuColors
        get() = createReadMenuColors(
            ReadBookConfigProviders.get().config,
            SharedThemeStoreProvider().bottomBackground.toArgb(),
        )
    override val immersive: Boolean get() = menuTheme.immersive
    override val bgColor: Int get() = menuTheme.bgColor
    override val textColor: Int get() = menuTheme.textColor

    // 窗口背景图时顶栏透明让背景图透出; 与 LanghuanApp 壁纸层同一数据源
    override val hasBgImage: Boolean
        get() = hasBgImageByPath(SharedThemeStoreProvider().bgImagePath)

    // 朗读短按: 切换播放/暂停
    override fun clickReadAloud() {
        screenModel.viewModel.toggleReadAloud()
    }
}

/**
 * iOS 端朗读控制桥: 面板动作落到 [IosReadAloudHost] + 偏好项。
 *
 * 语速/跟随系统/定时默认值直接读写 PreferKey (与原版 AppConfig 同 key),
 * 对照 desktop `DesktopReadAloudControls`。
 */
private class IosReadAloudControls(
    private val navigator: AppNavigator,
    private val screenModel: ReaderScreenModel,
) : ReadAloudControls {

    private val prefs get() = PreferenceProviders.get()

    override val isPlaying: Boolean get() = !IosReadAloudHost.isPause

    override val timerMinute: Int
        get() = IosReadAloudHost.timeMinute
            .takeIf { it > 0 }
            ?: prefs.getInt(PreferKey.ttsTimer, 0)

    override val speechRate: Int get() = prefs.getInt(PreferKey.ttsSpeechRate, 5)

    override val followSys: Boolean get() = prefs.getBoolean(PreferKey.ttsFollowSys, true)

    override fun playPause() = IosReadAloudHost.toggle()

    override fun stop() = IosReadAloudHost.stop()

    override fun prevChapter() {
        screenModel.viewModel.moveToPrevChapter()
    }

    override fun nextChapter() {
        screenModel.viewModel.moveToNextChapter()
    }

    override fun prevParagraph() = IosReadAloudHost.prevParagraph()

    override fun nextParagraph() = IosReadAloudHost.nextParagraph()

    override fun setTimer(minute: Int) {
        IosReadAloudHost.setTimer(minute)
    }

    override fun setSpeechRate(rate: Int) {
        prefs.putInt(PreferKey.ttsSpeechRate, rate.coerceIn(0, 45))
        IosReadAloudHost.setSpeechRate(rate)
    }

    override fun setFollowSys(follow: Boolean) {
        prefs.putBoolean(PreferKey.ttsFollowSys, follow)
        // 跟随系统时回落默认语速 (对照原版 AppConfig.speechRatePlay)
        IosReadAloudHost.setSpeechRate(if (follow) 5 else speechRate)
    }

    override fun openChapterList() {
        // 对照原版 朗读面板目录按钮 → TocDialog 底部弹窗
        screenModel.postDialogEvent(ReaderDialogEvent.Toc)
    }

    override fun openSettings() {
        // 对照原版 ReadAloudDialog 设置按钮 → ReadAloudConfigDialog
        screenModel.postDialogEvent(ReaderDialogEvent.ReadAloudConfig)
    }

    override fun toBackstage() {
        navigator.pop()
    }
}
