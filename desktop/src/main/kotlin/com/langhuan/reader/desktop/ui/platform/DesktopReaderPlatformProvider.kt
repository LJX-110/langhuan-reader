package com.langhuan.reader.desktop.ui.platform

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.constant.EventBus
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.BookChapter
import com.langhuan.reader.help.book.BookImageDownloadShared
import com.langhuan.reader.help.book.isLocal
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.help.config.ReadBookConfigProviders
import com.langhuan.reader.help.source.SourceVerificationHelpShared
import com.langhuan.reader.help.storage.BackupShared
import com.langhuan.reader.help.storage.DataStorageProviders
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.help.writeBytesAtomically
import com.langhuan.reader.ui.book.read.BaseReadMenuState
import com.langhuan.reader.ui.book.read.ReadAloudControls
import com.langhuan.reader.ui.book.read.ReadBookEvents
import com.langhuan.reader.ui.book.read.ReadConfigChange
import com.langhuan.reader.ui.book.read.ReadMenuColors
import com.langhuan.reader.ui.book.read.ReadMenuController
import com.langhuan.reader.ui.book.read.ReadMenuState
import com.langhuan.reader.ui.book.read.ReaderDialogEvent
import com.langhuan.reader.ui.book.read.ReaderPlatformProvider
import com.langhuan.reader.ui.book.read.ReaderScreenModel
import com.langhuan.reader.ui.book.read.createReadMenuColors
import com.langhuan.reader.ui.book.read.hasBgImageByPath
import com.langhuan.reader.ui.book.read.page.SelectionGeometry
import com.langhuan.reader.ui.book.read.refreshReaderImage
import com.langhuan.reader.ui.compose.platform.DesktopThemeStoreProvider
import com.langhuan.reader.ui.reader.ReaderImageActionMenu
import com.langhuan.reader.ui.reader.ReaderImageActions
import com.langhuan.reader.ui.reader.ReaderTextActionMenu
import com.langhuan.reader.ui.reader.ReaderTextActions
import com.langhuan.reader.ui.reader.ReaderTextSelectionRequest
import com.langhuan.reader.ui.reader.readerMenuAnchor
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppNavigatorProviders
import com.langhuan.reader.ui.root.AppOverlay
import com.langhuan.reader.ui.widget.dialog.encodePhotoOverlayPayload
import com.langhuan.reader.utils.FileUtilsBase
import com.langhuan.reader.utils.FlowBus
import com.langhuan.reader.desktop.help.DesktopBattery
import com.langhuan.reader.desktop.help.tts.DesktopReadAloudHost
import com.langhuan.reader.desktop.ui.DesktopDialogRequest
import com.langhuan.reader.desktop.ui.DesktopDialogs
import com.langhuan.reader.desktop.ui.DesktopPlatformCapabilities
import com.langhuan.reader.desktop.ui.withDialogCancel
import com.langhuan.reader.desktop.ui.component.FileDialogs
import com.langhuan.reader.desktop.ui.readerWindowTint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.concurrent.Volatile

/**
 * desktop 端 [ReaderPlatformProvider] 真实实现: 菜单可见/可切, 导航经 [AppNavigator] 桥接。
 *
 * 对照 app 端 [com.langhuan.reader.ui.book.read.AndroidReaderPlatformProvider]:
 * - createMenuController: 返回真实 [DesktopReadMenuController] (visibleState 可切, 非恒 false)
 * - getBatteryLevel: Windows 经 kernel32 (JNA) / macOS 经 `pmset -g batt` /
 *   Linux 经 sysfs BAT/capacity 读真实电量, 无电池/失败回落 100 (信息条恒显示电量)
 * - 顶/底栏菜单 UI 由 shared [com.langhuan.reader.ui.book.read.ReadMenuOverlay] 渲染, 此处只持有状态
 * - 导航回调 (clickCatalog/clickSearch/clickSetting 等) 经 [AppNavigator] 跳 shared Route
 * - 章节导航 (clickPre/clickNext/onSeekStop) 委托 [ReaderScreenModel.viewModel]
 * - ReadAloud (朗读): app 端走 ReadAloud + BaseReadAloudService, desktop 无 Service, 改由
 *   [DesktopReadAloudHost] 驱动 ReadAloudControllerShared; 长按弹共享朗读控制面板。
 *   朗读宿主是进程级媒体会话, 退出阅读页不停朗读; Windows 下的后台/系统播控由
 *   desktop.audio.DesktopSmtc (SMTC 卡片) 与 desktop.ui.tray.DesktopTaskbarMedia (任务栏媒体控件) 承接
 *
 * # 不实现 (与 app 端差异)
 * - ThemeConfig.applyDayNight: app 端切夜间主题后调 Activity 重启 UI, desktop 经
 *   [com.langhuan.reader.help.config.ThemeConfigProviders] (FileThemeConfigProvider.applyDayNight)
 *   写 ThemeStore 色 + themeMode 并 emit RECREATE, AppTheme 重组重读新色
 * - 沉浸式色彩 (immersive/bgColor/textColor): 对照原版 ReadMenu.upColorConfig, 纯色阅读背景时
 *   菜单栏跟随阅读背景色+文字色 (shared createReadMenuColors); 图片阅读背景时走 AppTheme 默认色
 */
class DesktopReaderPlatformProvider : ReaderPlatformProvider {

    /** 页内文字选择请求快照 (null = 不显示自绘浮动菜单), 由 [TextSelectionHost] 渲染。 */
    private var rawSelection by mutableStateOf<RawTextSelection?>(null)

    /** 当次选择的动作集: 动作要 screenModel, 故在 onTextSelected 装配好存下。 */
    private var textActions by mutableStateOf<ReaderTextActions?>(null)

    /** 窗口标题栏着色协程 (阅读页激活期间订阅背景色变化, 见 [readerWindowTint])。 */
    private var titleBarTintJob: Job? = null

    /** 标题栏着色协程作用域 (Main)。 */
    private val titleBarScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /** 图片保存协程作用域 (Main: toast 需主线程; 下载/写盘在 IO 块内切换)。 */
    private val imageActionScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /** 触发标题栏着色刷新的配置变更集合。 */
    private val titleBarTintChanges = setOf(
        ReadConfigChange.BG,
        ReadConfigChange.BG_ALPHA,
        ReadConfigChange.STYLE,
    )

    override fun createMenuController(
        navigator: AppNavigator,
        screenModel: ReaderScreenModel,
    ): ReadMenuController = DesktopReadMenuController(navigator, screenModel)

    /**
     * 本窗口已接纳的绑定身份 = (页面模型, 控制器): 自动翻页/退出只作用于自己这条绑定,
     * 旧阅读页的 onExit 不会释放新页的控制器。
     */
    private var activeMenuBinding: Pair<ReaderScreenModel, ReadMenuController>? = null

    override fun activateMenuController(
        screenModel: ReaderScreenModel,
        controller: ReadMenuController,
    ) {
        activeMenuBinding = screenModel to controller
        (controller.state as? DesktopReadMenuState)?.startAloudPageWatch()
    }

    override fun releaseMenuController(
        screenModel: ReaderScreenModel,
        controller: ReadMenuController,
    ) {
        val state = controller.state as? DesktopReadMenuState ?: return
        state.stopAloudPageWatch()
        state.dispose()
        if (activeMenuBinding?.first === screenModel && activeMenuBinding?.second === controller) {
            activeMenuBinding = null
        }
    }

    // TTS 语速变更后重新应用当前语速 (重读配置 + pause/resume 让新语速立刻作用到当前段;
    // 本方法不写配置, 只按现配置重放)
    override fun upTtsSpeechRate(screenModel: ReaderScreenModel) = DesktopReadAloudHost.upSpeechRate()

    override fun getBatteryLevel(): Int = DesktopBattery.getBatteryLevel()

    /**
     * 阅读页进入: 把窗口系统标题栏着色为阅读背景色 (视为状态栏着色,
     * 对照 app 端状态栏随阅读背景变化; 用户要求 2026-08-06)。
     * 订阅配置变更实时刷新; 阅读页退出 ([onExit]) 时清除回落 AppTheme 主题色。
     */
    override fun onEnter(screenModel: ReaderScreenModel) {
        titleBarTintJob?.cancel()
        titleBarTintJob = titleBarScope.launch {
            fun updateTint() {
                val color = runCatching {
                    ReadBookConfigProviders.get().config.curBgColor()
                }.getOrNull() ?: return
                // 标题栏不着半透明, 取不透明阅读背景色
                readerWindowTint.value = Color(color).copy(alpha = 1f)
            }
            updateTint()
            // RECREATE 也要刷: 切日/夜换的是 curBgColor 的日/夜分支, 不发 ReadConfigChange,
            // app 端靠 Activity 重启重取, 桌面端只重组 ⇒ 漏订阅时控制条残留上一套底色
            merge(
                ReadBookEvents.configChange.filter { changes ->
                    changes.any { it in titleBarTintChanges }
                },
                FlowBus.with(EventBus.RECREATE),
            ).collect { updateTint() }
        }
    }

    /**
     * 阅读页销毁: 释放页面控制器/协程，清理窗口与浮层状态。
     * 朗读宿主是进程级媒体会话，不随阅读路由销毁而停止，以保留后台/托盘控制语义。
     */
    override fun onExit(screenModel: ReaderScreenModel) {
        // 只放自己这条绑定 (不经模型取新控制器)
        activeMenuBinding
            ?.takeIf { it.first === screenModel }
            ?.second
            ?.let { releaseMenuController(screenModel, it) }
        titleBarTintJob?.cancel()
        titleBarTintJob = null
        readerWindowTint.value = null
        ReaderImageActionMenu.dismiss()
        rawSelection = null
        textActions = null
        BackupShared.autoBack()
    }

    /**
     * 页内文字选择完成（长按/划选文字后抬起）：弹自绘浮动文本操作菜单
     * （见共享 [ReaderTextActionMenu]，宿主 [TextSelectionHost] 挂在桌面 Compose 根）。
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
        rawSelection = RawTextSelection(text, geometry)
    }

    /**
     * 页内选区已消失（点按取消选择/翻页/重排等任意路径）：收起浮动文本操作菜单
     * （对照原版 onCancelSelect → textActionMenu.dismiss）。幂等：菜单未显示时无操作。
     */
    override fun onTextSelectionDismissed(screenModel: ReaderScreenModel) = dismissActionMenus()

    /**
     * 同步立即关闭浮动文本操作菜单（点按取消选择等手势分支在选区清除的同帧同步直调）。
     * 幂等，事件链兜底重复调用安全。
     */
    override fun dismissTextActionMenu(screenModel: ReaderScreenModel) = dismissActionMenus()

    /** 对照 master ReadBookActivity.cancelSelect: 文本/图片菜单互斥, 同时 dismiss。 */
    private fun dismissActionMenus() {
        rawSelection = null
        ReaderImageActionMenu.dismiss()
    }

    /**
     * 图片长按: 弹共享自绘图片操作菜单 (查看/刷新/保存/选择目录, 对照原版
     * ReadBookActivity.onImageLongPress; 桌面有目录选择器故保留"选择目录")。
     * 菜单项收尾对照原版 popupAction 点击 → onDismiss → postSelectionCancel。
     */
    override fun onImageLongPress(
        screenModel: ReaderScreenModel,
        src: String,
        x: Float,
        y: Float,
    ) {
        if (src.isBlank()) return
        ReaderImageActionMenu.show(
            anchor = readerMenuAnchor(x, y),
            actions = ReaderImageActions(
                view = { viewImage(screenModel, src) },
                refresh = { refreshImage(screenModel, src) },
                save = { saveImage(screenModel, src) },
                selectDirectory = { saveImageToSelectedDir(screenModel, src) },
            ),
        )
    }

    /** 查看大图: 弹共享全屏大图 Overlay (key="photo" → PhotoViewOverlayDialog, 全屏黑底+缩放;
     *  带书源身份走防盗链 header + coverDecodeJs 封面解密, 与列表封面同款身份, 本地书不传)。
     *  payload 携带当前章节索引: 对话框优先查阅读时已落盘的章节图片缓存
     *  (BookImageStorage, 对照原版 PhotoDialog.loadPhoto 的章节缓存文件分支)。 */
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

    /**
     * 刷新图片: 删该图磁盘缓存文件 + 清共享内存缓存 + 重载当前章 (四端同一份,
     * 见 shared [refreshReaderImage])。
     */
    private fun refreshImage(screenModel: ReaderScreenModel, src: String) {
        refreshReaderImage(screenModel.currentBook, screenModel.currentChapter, src)
    }

    /** 保存图片: 原生保存对话框选路径 → 读图片缓存字节 → 落盘, toast 提示路径。 */
    private fun saveImage(screenModel: ReaderScreenModel, src: String) {
        val book = screenModel.currentBook
        imageActionScope.launch {
            // 受控选择能力 (withDialogCancel): 面板被撤后不写盘、不提示成功。
            // 阻塞式选择器必须切 IO (对照漫画阅读页 onSaveImage 的 withContext(IoDispatcher))
            val destPath = withDialogCancel { handle ->
                withContext(Dispatchers.IO) {
                    FileDialogs.pickSaveFile(
                        title = "保存图片",
                        defaultName = "langhuan-${System.currentTimeMillis()}.jpg",
                        initialDir = defaultImageSaveDir(),
                        handle = handle,
                    )?.absolutePath
                }
            } ?: return@launch
            Toasters.get().toast("正在保存")
            val savedPath = withContext(Dispatchers.IO) {
                writeImageBytes(src, book, screenModel.currentChapter, File(destPath))
            }
            Toasters.get().toast(if (savedPath != null) "保存成功\n$savedPath" else "保存失败")
        }
    }

    /**
     * 选择目录保存 (T8, 对照 app 端 showImageActionMenu 的 selectFolder 分支):
     * 阻塞式选目录 → 在该目录下落盘当前图（文件名取时间戳，建议名 .jpg, 写入后按魔数修正扩展名）。
     * 桌面无 SAF 默认保存目录持久化 (app 端 ACache.imagePathKey), 故"选择目录"直接把当前图存进所选目录,
     * 语义对齐 app 的 selectImageDir 分支 (选目录后继续保存)。
     */
    private fun saveImageToSelectedDir(screenModel: ReaderScreenModel, src: String) {
        val book = screenModel.currentBook
        imageActionScope.launch {
            // 受控选择能力 (withDialogCancel): 面板被撤后不写盘、不提示成功、不交结果
            val dir = withDialogCancel { handle ->
                withContext(Dispatchers.IO) {
                    FileDialogs.pickDirectory(title = "选择保存目录", handle = handle)
                }
            } ?: return@launch
            Toasters.get().toast("正在保存")
            val savedPath = withContext(Dispatchers.IO) {
                writeImageBytes(
                    src, book, screenModel.currentChapter,
                    File(dir, "langhuan-${System.currentTimeMillis()}.jpg"),
                )
            }
            Toasters.get().toast(if (savedPath != null) "保存成功\n$savedPath" else "保存失败")
            // 目录选择后作为后续保存对话框默认起始目录 (对照 app 端写入 imagePathKey 的记忆语义)
            if (savedPath != null && dir.isDirectory) {
                lastImageSaveDir = dir
            }
        }
    }

    /**
     * 取已缓存图片字节写入 [dest], 返回最终绝对路径 (写入后按魔数修正扩展名); 取不到缓存返回 null。
     *
     * 保存只导出已看过的图 (对照原版 BaseReadViewModel.saveImage 的读取段), 不触发下载;
     * 建议名恒为 .jpg, 与实际格式不符时按魔数改名 (shared 统一 helper, 与漫画保存一致)。
     *
     * 落盘整份归位: 目标已存在时 (用户选了同名文件) 覆盖写会先把旧图截断, 写到一半被打断
     * 就留下一张半截图。
     */
    private suspend fun writeImageBytes(
        src: String,
        book: Book?,
        chapter: BookChapter?,
        dest: File,
    ): String? = try {
        val bytes = book?.let { BookImageDownloadShared.imageBytesToSave(it, src, chapter) }
            ?: return null
        if (!writeBytesAtomically(dest.path, bytes)) error("保存图片失败: ${dest.path}")
        FileUtilsBase.fixImageExtension(dest).absolutePath
    } catch (e: Exception) {
        AppLog.put("保存图片出错\n${e.localizedMessage}", e)
        null
    }

    /** 保存对话框默认起始目录 (用户可见产物目录 桌面/langhuan, 与漫画保存一致)。 */
    private fun defaultImageSaveDir(): File? = runCatching {
        (lastImageSaveDir ?: File(DataStorageProviders.get().userExportDir))
            .takeIf { it.isDirectory || it.mkdirs() }
    }.getOrNull()

    /** 最近一次"选择目录"保存时选定的目录 (T8, 供后续"保存"对话框默认起始目录)。 */
    @Volatile
    private var lastImageSaveDir: File? = null

    /**
     * 阅读页自绘浮动文本菜单宿主 (挂在阅读内容容器内, 坐标系与页面完全一致)。
     */
    @Composable
    fun TextSelectionHost() {
        val actions = textActions
        val selection = rawSelection
        val request = remember(selection) {
            selection?.let {
                ReaderTextSelectionRequest(text = it.text, geometry = it.geometry)
            }
        }
        if (actions != null) {
            ReaderTextActionMenu(
                request = request,
                actions = actions,
                onFinally = {
                    rawSelection = null
                    ReadBookEvents.postSelectionCancel()
                },
            )
        }
    }

    override fun readAloudControls(
        navigator: AppNavigator,
        screenModel: ReaderScreenModel,
    ): ReadAloudControls = DesktopReadAloudControls(navigator, screenModel)
}

/** 页内文字选择快照 (选区几何与页面坐标系一致, 见 [TextSelectionHost])。 */
private data class RawTextSelection(
    val text: String,
    val geometry: SelectionGeometry,
)

/**
 * 桌面端朗读控制桥: 面板动作落到 [DesktopReadAloudHost] + 偏好项。
 *
 * 语速/跟随系统/定时默认值直接读写 PreferKey (与原版 AppConfig 同 key), 桌面端没有
 * AppConfig setter, 与 [DesktopReadMenuState] 写 themeMode 的做法一致。
 */
private class DesktopReadAloudControls(
    private val navigator: AppNavigator,
    private val screenModel: ReaderScreenModel,
) : ReadAloudControls {

    private val prefs get() = PreferenceProviders.get()

    override val isPlaying: Boolean get() = !DesktopReadAloudHost.isPause

    override val timerMinute: Int
        get() = DesktopReadAloudHost.timeMinute
            .takeIf { it > 0 }
            ?: prefs.getInt(PreferKey.ttsTimer, 0)

    override val speechRate: Int get() = prefs.getInt(PreferKey.ttsSpeechRate, 5)

    override val followSys: Boolean get() = prefs.getBoolean(PreferKey.ttsFollowSys, true)

    override fun playPause() = DesktopReadAloudHost.toggle()

    override fun stop() = DesktopReadAloudHost.stop()

    override fun prevChapter() {
        screenModel.viewModel.moveToPrevChapter()
    }

    override fun nextChapter() {
        screenModel.viewModel.moveToNextChapter()
    }

    override fun prevParagraph() = DesktopReadAloudHost.prevParagraph()

    override fun nextParagraph() = DesktopReadAloudHost.nextParagraph()

    override fun setTimer(minute: Int) {
        DesktopReadAloudHost.setTimer(minute)
    }

    override fun setSpeechRate(rate: Int) {
        prefs.putInt(PreferKey.ttsSpeechRate, rate.coerceIn(0, 45))
        DesktopReadAloudHost.setSpeechRate(rate)
    }

    override fun setFollowSys(follow: Boolean) {
        prefs.putBoolean(PreferKey.ttsFollowSys, follow)
        // 跟随系统时回落默认语速 (对照原版 AppConfig.speechRatePlay)
        DesktopReadAloudHost.setSpeechRate(if (follow) 5 else speechRate)
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

private class DesktopReadMenuController(
    navigator: AppNavigator,
    screenModel: ReaderScreenModel,
) : ReadMenuController {
    override val state: ReadMenuState = DesktopReadMenuState(navigator, screenModel)
    override fun showMenu() = (state as DesktopReadMenuState).show()
    override fun hideMenu() = (state as DesktopReadMenuState).hide()
}

/**
 * desktop 阅读菜单状态: visibleState 可切 (非恒 false), 字段从 screenModel.viewModel 取实时值。
 *
 * 颜色用 AppTheme 默认 (非沉浸式); 菜单显隐时刷新动态项 (顶栏可见性/书源按钮/章节信息),
 * 行为对齐 app 端 AndroidReaderMenuState.show()。
 */
private class DesktopReadMenuState(
    navigator: AppNavigator,
    screenModel: ReaderScreenModel,
) : BaseReadMenuState(navigator, screenModel) {

    /** 朗读页面变化监听的协程作用域 (Main)。 */
    private val aloudWatchScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /** 章节链接开窗: 查询书源 + startBrowser 开窗在 IO 线程 (AnalyzeUrl 可能执行 header JS)。 */
    private val chapterLinkScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // 菜单栏配色 (对照原版 ReadMenu.upColorConfig, 逻辑见 shared createReadMenuColors)
    private val menuTheme: ReadMenuColors
        get() = createReadMenuColors(
            ReadBookConfigProviders.get().config,
            DesktopThemeStoreProvider().bottomBackground.toArgb(),
        )
    override val immersive: Boolean get() = menuTheme.immersive
    override val bgColor: Int get() = menuTheme.bgColor
    override val textColor: Int get() = menuTheme.textColor

    // 窗口背景图时顶栏透明让背景图透出; 与 LanghuanApp 壁纸层同一数据源
    override val hasBgImage: Boolean
        get() = hasBgImageByPath(DesktopThemeStoreProvider().bgImagePath)

    override var titleBarAdditionVisible by mutableStateOf(
        runCatching {
            PreferenceProviders.get().getBoolean(PreferKey.showReadTitleAddition, true)
        }.getOrDefault(true)
    )

    // 滚动模式朗读重定位: 暂停期间页面是否变化 (对照 app 端 AndroidReaderMenuState.aloudPageChanged)
    private var aloudPageChanged = false

    /**
     * 页面变化订阅: 构造时**不**起 (构造可能发生在被放弃的组合里), 由 provider.activateMenuController
     * 在组合提交后成对启停 (对照 app 端 AndroidReaderMenuState.init → startPageChangedWatch)。
     */
    private var aloudPageWatchJob: Job? = null

    fun startAloudPageWatch() {
        aloudPageWatchJob?.cancel()
        aloudPageWatchJob = aloudWatchScope.launch {
            ReadBookEvents.seekBarChange.collect { aloudPageChanged = true }
        }
    }

    fun stopAloudPageWatch() {
        aloudPageWatchJob?.cancel()
        aloudPageWatchJob = null
    }

    override fun onChapterViewClick() {
        val book = screenModel.viewModel.book.value ?: return
        if (book.isLocal) return
        val url = chapterUrl.orEmpty()
        // 长按可切换浏览器/应用内打开方式 (对照 app 端 ReadMenu.onChapterViewClick)
        if (PreferenceProviders.get().getBoolean(PreferKey.readUrlOpenInBrowser, false)) {
            DesktopPlatformCapabilities.openExternalUrl(url.substringBefore(",{"))
            return
        }
        // 直接开内置浏览器窗口
        chapterLinkScope.launch {
            val source = AppDbProviders.get().bookSourceDao.getBookSource(book.origin)
            if (source != null) {
                SourceVerificationHelpShared.startBrowser(
                    source, url, book.originName, saveResult = false, refetchAfterSuccess = false
                )
            } else {
                DesktopPlatformCapabilities.openExternalUrl(url.substringBefore(",{"))
            }
        }
    }

    override fun onChapterViewLongClick() {
        val book = screenModel.viewModel.book.value ?: return
        if (book.isLocal) return
        DesktopDialogs.show(
            DesktopDialogRequest.Confirm(
                title = "打开方式",
                message = "是否使用外部浏览器打开？",
                okText = "是",
                noText = "否",
                onOk = {
                    PreferenceProviders.get().putBoolean(PreferKey.readUrlOpenInBrowser, true)
                },
                onNo = {
                    PreferenceProviders.get().putBoolean(PreferKey.readUrlOpenInBrowser, false)
                },
            )
        )
    }

    /** 释放菜单状态与协程作用域 (阅读页退出时由 Provider 调用) */
    fun dispose() {
        aloudWatchScope.cancel()
        chapterLinkScope.cancel()
    }

    override fun clickReadAloud() {
        when {
            !DesktopReadAloudHost.isRun -> {
                if (screenModel.viewModel.isScrollPageAnim) {
                    screenModel.viewModel.readAloudFromVisibleStart()
                } else {
                    DesktopReadAloudHost.play()
                }
            }

            DesktopReadAloudHost.isPause -> {
                if (screenModel.viewModel.isScrollPageAnim && aloudPageChanged) {
                    aloudPageChanged = false
                    screenModel.viewModel.readAloudFromVisibleStart()
                } else {
                    DesktopReadAloudHost.resume()
                }
            }

            else -> DesktopReadAloudHost.pause()
        }
        screenModel.postDialogEvent(ReaderDialogEvent.ReadAloud)
    }

    /** 顶栏/底栏展示数据 (对照原版 upBookView: 书名/章节名/章节链接/上下章可用性) */
    override fun upMenuView() {
        super.upMenuView()
        titleBarAdditionVisible = runCatching {
            PreferenceProviders.get().getBoolean(PreferKey.showReadTitleAddition, true)
        }.getOrDefault(true)
    }

    override fun upSeekBar() {
        val pageBehavior = PreferenceProviders.get()
            .getString(PreferKey.progressBarBehavior, "page") == "page"
        seekMax = if (pageBehavior) {
            (screenModel.viewModel.curTextChapter.value?.pageSize?.minus(1) ?: -1)
                .coerceAtLeast(0)
        } else {
            (screenModel.viewModel.simulatedChapterSize - 1).coerceAtLeast(0)
        }
        seekValue = if (pageBehavior) {
            screenModel.viewModel.durPageIndex.value
        } else {
            screenModel.viewModel.durChapterIndex.value
        }
    }
}
