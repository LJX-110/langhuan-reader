package com.langhuan.reader

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.window.ComposeUIViewController
import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.help.config.NativeSystemTheme
import com.langhuan.reader.help.config.LocalReadConfigProviders
import com.langhuan.reader.help.config.ReadConfigProviders
import com.langhuan.reader.help.StartupMaintenanceShared
import com.langhuan.reader.help.AppVersionProvider
import com.langhuan.reader.help.AppVersionProviders
import com.langhuan.reader.help.versionNameToVersionCode
import com.langhuan.reader.help.AppWebDavShared
import com.langhuan.reader.ui.book.info.LocalBlurCoverBgSlot
import com.langhuan.reader.ui.root.ImportStageDialog
import com.langhuan.reader.ui.root.ImportStageOwner
import com.langhuan.reader.ui.root.rememberWindowVisibleState
import com.langhuan.reader.ui.book.info.SharedBlurCoverBg
import com.langhuan.reader.ui.browser.IosWebViewSlot
import com.langhuan.reader.ui.browser.LocalWebViewSlot
import com.langhuan.reader.ui.IosPlatformCapabilities
import com.langhuan.reader.ui.IosPlatformServices
import com.langhuan.reader.ui.IosNotificationPublisher
import com.langhuan.reader.ui.book.audio.AudioPlayPlatformProviders
import com.langhuan.reader.ui.book.audio.SharedAudioPlayPlatformProvider
import com.langhuan.reader.ui.book.read.IosReaderPlatformProvider
import com.langhuan.reader.ui.book.read.ReaderPlatformProviders
import com.langhuan.reader.ui.book.source.SourceUiEventBridgeHost
import com.langhuan.reader.ui.association.DeepLinkImportHost
import com.langhuan.reader.ui.about.notifyAppCrash
import com.langhuan.reader.ui.about.preferenceAppVersionStore
import com.langhuan.reader.ui.about.recordAppVersion
import com.langhuan.reader.ui.compose.platform.LocalAppConfigProvider
import com.langhuan.reader.ui.compose.platform.LocalEventBusProvider
import com.langhuan.reader.ui.compose.platform.LocalThemeStoreProvider
import com.langhuan.reader.ui.compose.platform.SharedAppConfigProvider
import com.langhuan.reader.ui.compose.platform.SharedEventBusProvider
import com.langhuan.reader.ui.compose.platform.SharedThemeStoreProvider
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.reader.ReaderDictWord
import com.langhuan.reader.ui.reader.ReaderImageActionMenu
import com.langhuan.reader.ui.root.AppFontScaleScope
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.LanghuanApp
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.root.PlatformServiceProviders
import com.langhuan.reader.ui.root.ScreenModelStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.IO
import kotlinx.coroutines.withContext
import platform.UIKit.UIViewController

/**
 * iOS 端 Compose 入口: 用 [ComposeUIViewController] 把 shared/sharedUiMain 下沉的
 * Composable 树包装为 [UIViewController], 由 SwiftUI / UIKit 宿主直接展示。
 *
 * 零薄壳: shared [LanghuanApp] 统一管理导航栈 + ScreenModel 生命周期,
 * 所有路由由 shared RouteContent 直接渲染, 不再维护并行状态字段。
 *
 * commonMain 业务 provider 由宿主在 didFinishLaunching 注册 (见 iosApp/iOSApp.swift 的
 * registerIosProviders), 本函数只补 UI 入口级平台 provider。
 */
fun MainViewController(): UIViewController {
    // 平台能力/服务 + 2 个媒体 Provider (对照 Android MainActivity.initializePlatform):
    // 均为 object 单例, 在组合之外注册, 系统深浅色切换重组时不重跑
    PlatformCapabilityProviders.register(IosPlatformCapabilities)
    PlatformServiceProviders.register(IosPlatformServices)
    ReaderPlatformProviders.register(IosReaderPlatformProvider)
    AudioPlayPlatformProviders.register(SharedAudioPlayPlatformProvider)
    // 通知点击处理 (解出 userInfo 里的路由 → LaunchRequestBus 导航)。
    // 须在 UI 首帧之前挂上: 冷启动时用户点通知, 系统可能在首帧前就派发 response。
    IosNotificationPublisher.installDelegate()
    // 当前版本号 provider (供启动期默认数据补齐按版本推进; iOS 无 PackageManager,
    // 取 CFBundleShortVersionString 经 versionNameToVersionCode 解析成单调版本号 —— 与下方
    // "更新日志" 弹窗用同一个值, 保证两边对"当前是哪个版本"的口径一致)。
    // 在这里 (组合之前, 非 @Composable 上下文) 注册: 下方 LaunchedEffect 内才注册会让"谁先读版本号"
    // 变成隐式约定, 而启动维护协程与弹窗协程是并发的。
    AppVersionProviders.register(object : AppVersionProvider {
        override val versionCode: Long
            get() = IosPlatformCapabilities.getAppVersionName()
                ?.let { versionNameToVersionCode(it) } ?: 0L
    })
    return ComposeUIViewController {
        // 注入 3 个 iOS Compose UI Provider (对照 desktop Main.kt 阶段2)
        val themeStoreProvider = remember { SharedThemeStoreProvider() }
        val appConfigProvider = remember { SharedAppConfigProvider() }
        val eventBusProvider = remember { SharedEventBusProvider() }

        // 阅读页注入点: 未注入时 LocalReadConfigProviders 取值即 error,
        // 阅读页与 EffectiveReplaces 路由会崩 (默认值为 error 而非兜底实现);
        // 实例来自全局注册 (iOSApp.swift didFinishLaunching 的 registerIosProviders),
        // 与设置弹窗读写同一份配置
        val readConfigProviders = remember { ReadConfigProviders() }

        // 零薄壳: AppNavigator + ScreenModelStore 是唯一状态源 (对照 desktop Main.kt line 346-347)
        val navigator = remember { AppNavigator(AppRoute.Main()) }
        val screenModelStore = remember { ScreenModelStore() }

        // 系统深浅色变化入口 (themeMode="0" 跟随系统): Compose 侧读到的系统深色值回写业务层,
        // 由业务层按新的日/夜重算并应用主题色 (初值走同一条链, 见注册期的 NativeSystemTheme.init)
        val isSystemDark = isSystemInDarkTheme()
        LaunchedEffect(isSystemDark) {
            NativeSystemTheme.update(isSystemDark)
        }

        CompositionLocalProvider(
            LocalThemeStoreProvider provides themeStoreProvider,
            LocalAppConfigProvider provides appConfigProvider,
            LocalEventBusProvider provides eventBusProvider,
            LocalReadConfigProviders provides readConfigProviders,
            LocalWebViewSlot provides { config, modifier, callbacks ->
                IosWebViewSlot(config, modifier, callbacks)
            },
            // 注入 Coil3 模糊封面背景到 shared 详情页路由, 覆盖 LocalBlurCoverBgSlot 兜底
            LocalBlurCoverBgSlot provides { book, coverTick, inBookshelf, isEInkMode, modifier, land ->
                SharedBlurCoverBg(book, coverTick, inBookshelf, isEInkMode, modifier, land)
            },
        ) {
            // 字体缩放: 把"界面设置→字体大小"档位接到 LocalDensity (安卓由 AppContextWrapper.wrap
            // 写进 Configuration.fontScale 生效, 不需要这一层)。未设档位时不覆写, 保留平台自身
            // fontScale (iOS 跟系统 Dynamic Type, 桌面/鸿蒙恒 1) —— 语义对照原版 getFontScale
            AppFontScaleScope {
                // 对话框尺寸锚点取宿主窗口可用区 (对话框层读到的是对话框自己的窗口, 会与内容互相反馈)
                AppTheme(anchor = LocalWindowInfo.current.containerSize) {
                    Column(modifier = Modifier.fillMaxSize()) {
                        // 零薄壳: shared LanghuanApp 统一管理导航栈 + ScreenModel 生命周期,
                        // 所有路由由 shared RouteContent 直接渲染; 根级键盘焦点由 shared 内部处理
                        // (handleBackKey 与焦点节点同链, 无控件持焦时键盘事件仍可达)
                        LanghuanApp(
                            navigator = navigator,
                            screenModelStore = screenModelStore,
                        )
                        // 启动期维护 (下沉件 StartupMaintenanceShared, 与 Android/桌面同一份):
                        // 默认数据补齐 + 缓存清理 + WebDav 进度同步。必须排在下方"记录版本号"之前
                        // —— 维护的"这一版要不要补默认数据"与记录读的是**同一份存储的同一个 key**
                        // (`appVersionCode`), 而写回它的是记录: 记录先跑就会把维护的门关死, 那一版
                        // 要补的预置分组/默认资源就再也补不上了 (与 app 端 App.onCreate 的
                        // DefaultData.upVersion() 先于 MainActivity 同一时序)。
                        // 异步、不阻塞首帧 (LaunchedEffect 自身就是后台协程)。
                        //
                        // 版本名取不到时不推进版本号, 下次启动再判。
                        LaunchedEffect(Unit) {
                            StartupMaintenanceShared.initDefaultData()
                            // cacheExtraMayHaveWork=false: iOS 的 clearCacheExtra 是空实现
                            StartupMaintenanceShared.clearInvalidCacheIfDue(cacheExtraMayHaveWork = false)
                            StartupMaintenanceShared.syncBookProgressOnStartup()
                            // 云端有新备份时弹本端确认框 (对照 app 端 MainActivity.backupSync):
                            // 标题 restore / 正文 webdav_after_local_restore_confirm, 用户确认后走共享恢复
                            // 入口 AppWebDavShared.restoreWebDav; 判定函数在"判定成立"时已回写"已提示过的
                            // 时间戳"(用户这次拒绝也不会重复弹), 故这里只在拿到 NewBackup 时弹。
                            // lastBackUp 会走网络, 下沉件自身不切线程, 故判定与认证都留在 IO。
                            val newBackup = withContext(Dispatchers.IO) {
                                // 认证先补一次: lastBackUp 首行是 authorization ?: return, app 端那份认证
                                // 来自 AppWebDav 的初始化块, 本端只有 syncBookProgress 开启时上一行才认证过
                                // (关闭时为 null → 判定恒 None, 提示永不出现), 故这里与
                                // syncBookProgressOnStartup 同款补认证 (已认证则跳过, 不重复建目录)
                                if (AppWebDavShared.authorization == null) {
                                    runCatching { AppWebDavShared.upConfig() }
                                        .onFailure {
                                            AppLog.put("启动期 WebDav 认证失败\n${it.message}", it)
                                        }
                                }
                                StartupMaintenanceShared.checkNewWebDavBackup()
                            }
                            if (newBackup is StartupMaintenanceShared.NewBackupCheckResult.NewBackup) {
                                IosPlatformCapabilities.presentWebDavNewBackupConfirm(newBackup.name)
                            }
                            IosPlatformCapabilities.getAppVersionName()?.let { versionName ->
                                recordAppVersion(
                                    versionNameToVersionCode(versionName),
                                    preferenceAppVersionStore(),
                                )
                            }
                            // 崩溃后重启提示 (对照原版 MainActivity.notifyAppCrash): 排在版本记录
                            // 之后, 与 app 端同一位置; 标记由 IosCrashHandler 落盘时置位。
                            // iOS 无构建类型感知, isDebug 恒 false (对齐 release 行为)
                            notifyAppCrash(isDebug = false)
                        }
                    }
                    // 书源 UI 事件桥: 订阅 SOURCE_UI_REQUEST, 承接 JS 的 showLoginDialog/
                    // showSourceVariableDialog 弹窗 (对照 desktop Main.kt line 391)
                    SourceUiEventBridgeHost()
                    // langhuan:// deep link 导入对话框宿主 (投递侧: iOSApp.swift onOpenURL → handleLanghuanDeepLink)
                    DeepLinkImportHost()
                    // 文件关联分发: 冷启动直投先排队, 首帧组合完成 (授权面/导航面就绪) 后按序消费;
                    // 本 effect 在主窗口组合内 —— 分发任务随窗口存亡 (窗口操作寿命), 队列元素只交付一次
                    // 本窗口持有的用户选择阶段: 队列任务用它等真回执 (不建全局 owner 表)
                    val associationStages = remember { ImportStageOwner() }
                    // 本窗口自身可见性: 取本窗口 Compose 生命周期的 STARTED 区间
                    // (iOS didEnterBackground/viewDidDisappear 会把 STARTED 降到 CREATED)。
                    // AppForegroundState 在 iOS 有置位点 (IosBackgroundTasks), 但那是进程前后台口径,
                    // 不等于"本窗口当前可见", 故这里不用它。
                    val windowVisible by rememberWindowVisibleState()
                    ImportStageDialog(associationStages, visible = windowVisible)
                    LaunchedEffect(associationStages) {
                        IosPlatformCapabilities.associationFileJobs.collect { job ->
                            job(associationStages)
                        }
                    }
                    // 阅读页长按文本的自绘浮动操作菜单 (四端同一份, 见 shared ReaderTextActionMenu)
                    IosReaderPlatformProvider.TextSelectionHost()
                    // 阅读页长按图片的自绘浮动操作菜单 (与文本菜单同款样式)
                    ReaderImageActionMenu.Host()
                    // 阅读页文本操作菜单查词宿主 (四端同一份, 见 shared ReaderDictWord)
                    ReaderDictWord.Host()
                }
            }
        }
    }
}
