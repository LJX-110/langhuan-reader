package com.langhuan.reader.ui.route

import androidx.compose.animation.core.Easing
import androidx.compose.foundation.MutatePriority
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.FlingBehavior
import androidx.compose.foundation.gestures.ScrollScope
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.CircularProgressIndicator
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.constant.BottomNavTag
import com.langhuan.reader.constant.EventBus
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.BookGroup
import com.langhuan.reader.data.entities.BookSource
import com.langhuan.reader.data.entities.BookSourcePart
import com.langhuan.reader.data.entities.HomeSection
import com.langhuan.reader.data.entities.PinnedExplore
import com.langhuan.reader.data.entities.SearchBook
import com.langhuan.reader.data.entities.rule.ExploreKind
import com.langhuan.reader.help.config.AppConfigAccessor
import com.langhuan.reader.help.config.AppConfigProviders
import com.langhuan.reader.help.coroutine.IoDispatcher
import com.langhuan.reader.help.showSourceLogin
import com.langhuan.reader.help.storage.BackupFileOps
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.model.webBook.ExploreOptionUiState
import com.langhuan.reader.ui.about.AppLogDialog
import com.langhuan.reader.ui.book.group.GroupEditDialog
import com.langhuan.reader.ui.book.group.GroupManageDialog
import com.langhuan.reader.ui.book.group.GroupViewModelShared
import com.langhuan.reader.ui.book.search.SearchScope
import com.langhuan.reader.ui.bookshelf.BookshelfActionsCallbacks
import com.langhuan.reader.ui.bookshelf.BookshelfAddViewModelShared
import com.langhuan.reader.ui.bookshelf.BookshelfScreen
import com.langhuan.reader.ui.bookshelf.BookshelfViewModel
import com.langhuan.reader.ui.bookshelf.CoverRatioLayoutState
import com.langhuan.reader.ui.bookshelf.CoverSlotRatio
import com.langhuan.reader.ui.bookshelf.LocalCoverRatioLayout
import com.langhuan.reader.ui.bookshelf.LocalBookCoverSlot
import com.langhuan.reader.ui.bookshelf.ShelfScrollState
import com.langhuan.reader.ui.bookshelf.ShelfVideoItem
import com.langhuan.reader.ui.bookshelf.toCoverBook
import com.langhuan.reader.ui.compose.component.AlertButton
import com.langhuan.reader.ui.compose.component.AppAlertDialog
import com.langhuan.reader.ui.compose.component.AppSelectorDialog
import com.langhuan.reader.ui.compose.component.ExploreOptionsRow
import com.langhuan.reader.ui.compose.component.LanghuanPageHeader
import com.langhuan.reader.ui.compose.component.horizontalMouseWheel
import com.langhuan.reader.ui.compose.component.listItemFocus
import com.langhuan.reader.ui.compose.platform.AppBackHandler
import com.langhuan.reader.ui.compose.platform.LocalEventBusProvider
import com.langhuan.reader.ui.compose.platform.platformStatusBarPadding
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.compose.theme.LocalEInk
import com.langhuan.reader.ui.debug.DialogPreviewLaunchers
import com.langhuan.reader.ui.dialog.TextInputDialog
import com.langhuan.reader.ui.main.MainScreen
import com.langhuan.reader.ui.main.explore.ExploreScreen
import com.langhuan.reader.ui.main.explore.ExploreScreenModel
import com.langhuan.reader.ui.main.explore.ExploreUiActions
import com.langhuan.reader.ui.main.explore.ExploreUiEvent
import com.langhuan.reader.ui.main.explore.ExploreUiState
import com.langhuan.reader.ui.main.home.SectionCoverRow
import com.langhuan.reader.ui.main.home.SectionTitleRow
import com.langhuan.reader.ui.main.local.LocalBooksTab
import com.langhuan.reader.ui.main.my.MyConfigContent
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.FileFilter
import com.langhuan.reader.ui.root.LocalSharedCoverBinding
import com.langhuan.reader.ui.root.LocalPlatformCapabilities
import com.langhuan.reader.ui.root.MainTab
import com.langhuan.reader.ui.root.MainTabSwitcher
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.root.PlatformServiceProviders
import com.langhuan.reader.ui.root.RouteEntry
import com.langhuan.reader.ui.root.OnRouteLifecycle
import com.langhuan.reader.ui.root.RouteResultPayload
import com.langhuan.reader.ui.root.RouteResults
import com.langhuan.reader.ui.root.ScreenModel
import com.langhuan.reader.ui.root.ScreenModelStore
import com.langhuan.reader.ui.root.SharedCoverBinding
import com.langhuan.reader.ui.root.rememberSharedCoverSourceBinding
import com.langhuan.reader.ui.root.toReadRoute
import com.langhuan.reader.ui.root.toRouteRef
import com.langhuan.reader.ui.widget.dialog.HelpDialog
import com.langhuan.reader.ui.widget.dialog.TextDialog
import com.langhuan.reader.ui.widget.dialog.WaitDialog
import com.langhuan.reader.utils.FlowBus
import com.langhuan.reader.utils.systemCurrentTimeMillis
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.conflate
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.add_book_url
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.copy_url
import com.langhuan.reader.ui.generated.resources.draw
import com.langhuan.reader.ui.generated.resources.empty
import com.langhuan.reader.ui.generated.resources.error
import com.langhuan.reader.ui.generated.resources.explore_option_invalidated
import com.langhuan.reader.ui.generated.resources.import_bookshelf
import com.langhuan.reader.ui.generated.resources.my
import com.langhuan.reader.ui.generated.resources.ok
import com.langhuan.reader.ui.generated.resources.open_in_browser
import com.langhuan.reader.ui.generated.resources.select_file
import com.langhuan.reader.ui.generated.resources.sure_del
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringResource
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * 主界面 shared 路由入口。
 *
 * 装配 [MainScreen]: 根据 [AppRoute.Main.tab] 定位初始页, 注入 4 个 tab composable
 * (Home/Bookshelf/Explore/MyConfig)。
 *
 * 对照 MainActivity: visibleTags 顺序校验 + initialPage 落点 + pageSelections 跳转流 +
 * onReselect 300ms 双击 (bookshelf gotoTop / explore compress) 均与 Activity 等价。
 */
@Composable
fun MainRoute(
    entry: RouteEntry,
    navigator: AppNavigator,
    screenModelStore: ScreenModelStore,
) {
    val appConfig = remember { AppConfigProviders.get() }
    val eventBus = LocalEventBusProvider.current

    // 底栏配置变更即时生效 (修复: 调整底栏设置后需切 tab 才刷新):
    // 各端底栏设置对话框写入后 emitRecreate()/postEvent(EventBus.RECREATE), 本组合
    // 订阅 recreateEvent 递增 configTick 强制重组 (与 AppTheme 观察同一事件流同模式)。
    // 底栏配置 (bottomBarHeight/IconSize/LabelMode/showHome/showDiscovery/bottomNavItemOrder)
    // 均为直读配置的普通 getter (Android 直读 SharedPreferences, 桌面/iOS/鸿蒙经
    // CachedPrefValue 由 pref 变更监听同步刷新), 重组即读到新值, remember 键变化后
    // 底栏立即按新配置刷新, 无需切 tab。
    // 对照原版: BaseActivity 观察 EventBus.RECREATE → recreate() → upHomePage() 整页重建。
    var configTick by remember(eventBus) { mutableIntStateOf(0) }
    LaunchedEffect(eventBus) {
        eventBus.recreateEvent.collect { configTick++ }
    }
    configTick

    // 琅嬛阁固定四页签：书架 / 发现 / 本地 / 我。
    // HOME tag 在这里承载「本地」页；底栏顺序与显隐不再跟随上游配置，
    // 保证外观与琅嬛阁一致（配置项仍保留，只是不参与主界面装配）。
    val visibleTags = remember {
        listOf(
            BottomNavTag.BOOKSHELF,
            BottomNavTag.DISCOVERY,
            BottomNavTag.HOME,
            BottomNavTag.MY,
        )
    }

    // 首页固定书架: 不再读 defaultHomePage 偏好
    val homePageIndex = remember(configTick, visibleTags) {
        visibleTags.indexOf(BottomNavTag.BOOKSHELF).coerceAtLeast(0)
    }
    val initialPage = homePageIndex

    // 对照 MainActivity.pageSelections: 页面跳转指令流 (index to smooth)
    val pageSelections: MutableSharedFlow<Pair<Int, Boolean>> =
        remember { MutableSharedFlow(extraBufferCapacity = 4) }

    // 外部切 tab 请求 (桌面端控制栏菜单等): MainTab → 当前可见 tag 列表 index → 平滑滚动
    // (目标 tab 被隐藏时 indexOf 为 -1, 忽略请求; 与 reselect 语义一致)
    LaunchedEffect(visibleTags) {
        MainTabSwitcher.flow.collect { tab ->
            val tag = when (tab) {
                MainTab.HOME -> BottomNavTag.HOME
                MainTab.BOOKSHELF -> BottomNavTag.BOOKSHELF
                MainTab.DISCOVERY -> BottomNavTag.DISCOVERY
                MainTab.MY -> BottomNavTag.MY
            }
            val index = visibleTags.indexOf(tag)
            if (index >= 0) pageSelections.tryEmit(index to true)
        }
    }

    // 对照 MainActivity.currentPage: pager 当前页 (返回键/reselect 判定)
    // rememberSaveable: 配合 LanghuanApp 的 SaveableStateHolder, 返回主界面时恢复 tab 位置
    var currentPage by rememberSaveable { mutableStateOf(initialPage) }

    // 对照原版 BEHAVIOR_RESUME_ONLY_CURRENT_FRAGMENT: pager 停稳页 (拖拽回弹/动画中不变),
    // 仅用于门控 home tab 的 section 网络加载——预组合的 tab 不加载, 真正翻到才加载
    var settledPage by rememberSaveable { mutableIntStateOf(initialPage) }

    // tab 集合/顺序变化 (底栏配置变更): 按 tag 定位保持当前 tab (换序/纯外观变更不打断),
    // 仅当前 tab 被隐藏时回落首个可见 tab——不回默认首页 (用户确认回默认页行为多余)。
    var lastVisibleTags by remember { mutableStateOf(visibleTags) }
    LaunchedEffect(visibleTags) {
        if (visibleTags != lastVisibleTags) {
            val old = lastVisibleTags
            lastVisibleTags = visibleTags
            val curTag = old.getOrNull(currentPage)
            val newIndex = curTag?.let { tag -> visibleTags.indexOf(tag) }?.takeIf { it >= 0 } ?: 0
            if (newIndex != currentPage) pageSelections.tryEmit(newIndex to false)
        }
    }

    // 对照 MainActivity.bookshelfReselected/exploreReselected: 300ms 双击 reselect
    var bookshelfReselected by remember { mutableLongStateOf(0L) }
    var exploreReselected by remember { mutableLongStateOf(0L) }
    // 书架滚顶信号 (对照 BookshelfTabController.gotoTop): 具体滚哪个状态由 BookshelfScreen
    // 按"当前分组页 + 布局档位"决定, 此处只发信号
    var bookshelfGotoTopTick by remember { mutableIntStateOf(0) }
    // 书架 tab 是否选中: 书架 DB 订阅的另一个维度 (前台 + 栈顶由本页 Lifecycle 提供)
    val bookshelfTabSelected = visibleTags.getOrNull(currentPage) == BottomNavTag.BOOKSHELF
    // home tab 激活态: 用停稳页判定 (对照原版仅当前 Fragment 才 onResume→initTab),
    // 拖拽到一半又滑回不触发; 预组合的 home 页保持组合但不加载
    val homeActive = visibleTags.getOrNull(settledPage) == BottomNavTag.HOME

    // ScreenModelStore 持有 BookshelfViewModel + ExploreScreenModel, 生命周期随 entry
    val mainScreenModel = screenModelStore.getOrCreateTyped(entry) { MainScreenModel() }
    val exploreListState = rememberLazyListState()
    val bookshelfScrollState = rememberSaveable(saver = ShelfScrollState.Saver) {
        ShelfScrollState()
    }
    val scope = rememberCoroutineScope()

    // F5 刷新: 四个 tab 共享同一 entry, 故只在此处唯一注册, 按当前页分发到对应 tab 的刷新入口
    // (书架 upToc; 本地页直接读 Room 流, 发现/我的无刷新动作)。
    // 当前页用 rememberUpdatedState 透传, 保证 handler 只注册/注销一次。
    val refreshTag = rememberUpdatedState(visibleTags.getOrNull(currentPage))
    // 刷新处理器挂本页 Lifecycle 的"在栈期间" (STARTED), 不挂组合存亡:
    // 组合会因被压栈/转场期间移出渲染列表而生死, 与"本页是否还在栈里"不是同一件事
    OnRouteLifecycle(
        onEnter = {
            navigator.registerRefreshHandler(entry.id) {
                when (refreshTag.value) {
                    BottomNavTag.BOOKSHELF -> mainScreenModel.bookshelfViewModel.upToc()
                    else -> Unit
                }
            }
        },
        onLeave = { navigator.unregisterRefreshHandler(entry.id) },
    )

    // 主界面返回键/ESC: 对齐底栏起始页回退规范与 onBackPressedDispatcher 回调——
    // 非默认主页 tab → 先切回默认主页; 默认主页 tab → 双击退出 (2000ms 窗口, 对齐原版 EXIT_INTERVAL)。
    // 经 AppBackHandler 注册进统一返回链 (覆盖物→Overlay→页面拦截→出栈): 主界面是根页面,
    // 出栈无效, 故启用时恒消费。书架分组页 (BookshelfScreen2) 的返回拦截在本组合之后注册,
    // 栈序优先 (后注册先分发), 分组内返回键先回根分组, 与"书架内部 back() 优先"语义一致。
    // LanghuanApp 保持栈内页面同一 Composition (非顶层仅移出可见区), 故仅当主界面是栈顶
    // (backStack.last 为本 entry) 时才拦截——详情页等顶层页面无自身拦截器时返回键正常出栈。
    val backStack by navigator.backStack.collectAsState()
    val overlays by navigator.overlays.collectAsState()
    val isMainTop = backStack.lastOrNull()?.id == entry.id
    var exitTime by remember { mutableLongStateOf(0L) }
    val platformCapabilities = LocalPlatformCapabilities.current
    // enabled 条件: 主界面是栈顶 (详情页等打开时不拦截, 返回键正常出栈) 且无 Overlay
    // (Overlay 由 LanghuanApp 根部 BackHandler 先关, 对齐原版"对话框先吃返回键")
    AppBackHandler(enabled = backStack.lastOrNull()?.id == entry.id && overlays.isEmpty()) {
        if (homePageIndex >= 0 && currentPage != homePageIndex) {
            pageSelections.tryEmit(homePageIndex to true)
            return@AppBackHandler
        }
        // 对照原版 exitTime/EXIT_INTERVAL: 第一次提示, 2000ms 内第二次退出
        val now = systemCurrentTimeMillis()
        if (now - exitTime > 2000L) {
            Toasters.get().toast("再按一次退出程序")
            exitTime = now
        } else {
            platformCapabilities.exitApplication()
        }
    }

    MainScreen(
        visibleTags = visibleTags,
        initialPage = initialPage,
        pageSelections = pageSelections,
        currentPageSink = { currentPage = it },
        settledPageSink = { settledPage = it },
        onSelectPage = { index -> pageSelections.tryEmit(index to true) },
        onReselect = { tag ->
            // 对照 MainActivity.onTabReselect: 300ms 内双击触发
            when (tag) {
                BottomNavTag.BOOKSHELF -> {
                    val now = systemCurrentTimeMillis()
                    if (now - bookshelfReselected > 300) {
                        bookshelfReselected = now
                    } else {
                        // 对照 BookshelfFragment1.gotoTop: 滚顶作用于"当前分组页", 且档位判定
                        // 与布局 spec 同源, 故只发信号, 由 BookshelfScreen 决定滚哪个状态
                        bookshelfGotoTopTick++
                    }
                }

                BottomNavTag.DISCOVERY -> {
                    val now = systemCurrentTimeMillis()
                    if (now - exploreReselected > 300) {
                        exploreReselected = now
                    } else {
                        // 对照 ExploreTabState.compressExplore: 先收起已展开项, 未展开则滚顶
                        if (!mainScreenModel.exploreScreenModel.collapseExpanded()) {
                            scope.launch {
                                if (appConfig.isEInkMode) {
                                    exploreListState.scrollToItem(0)
                                } else {
                                    exploreListState.animateScrollToItem(0)
                                }
                            }
                        }
                    }
                }
            }
        },
        homeTab = { LocalBooksTab(navigator, homeActive) },
        bookshelfTab = {
            // 封面比例布局状态: 只在书架内容处下发, 其余 tab 封面保持无持有者的原路径
            CompositionLocalProvider(
                LocalCoverRatioLayout provides mainScreenModel.coverRatioLayout,
            ) {
                BookshelfTabContent(
                    mainScreenModel.bookshelfViewModel,
                    navigator,
                    bookshelfScrollState,
                    bookshelfGotoTopTick,
                    bookshelfTabSelected,
                    isRootTop = isMainTop,
                )
            }
        },
        exploreTab = {
            ExploreTabContent(
                entry = entry,
                screenModel = mainScreenModel.exploreScreenModel,
                listState = exploreListState,
                navigator = navigator,
            )
        },
        myTab = { MyTabContent(navigator) },
        bottomBarIconSize = appConfig.bottomBarIconSize,
        bottomBarHeight = appConfig.bottomBarHeight,
        bottomBarLabelMode = appConfig.bottomBarLabelMode,
    )
}

/**
 * 主界面 ScreenModel: 持有 BookshelfViewModel + ExploreScreenModel,
 * 生命周期随 MainRoute entry (ScreenModelStore 管理 onCleared)。
 */
private class MainScreenModel : ScreenModel {
    val bookshelfViewModel = BookshelfViewModel()
    val exploreScreenModel = ExploreScreenModel()

    /** 已确定封面比例的布局状态: 与书架结果同寿命 (ScreenModelStore 保留, 配置重建不丢) */
    val coverRatioLayout = CoverRatioLayoutState()

    override fun onCleared() {
        bookshelfViewModel.onCleared()
        exploreScreenModel.onCleared()
    }
}

/** 对照 MainActivity.computeVisibleTags: 顺序配置校验 + showHome/showDiscovery 过滤 */
private fun computeVisibleTags(appConfig: AppConfigAccessor): List<String> {
    val defaultTagOrder = listOf(
        BottomNavTag.HOME,
        BottomNavTag.BOOKSHELF,
        BottomNavTag.DISCOVERY,
        BottomNavTag.MY,
    )
    val savedTagOrder = appConfig.bottomNavItemOrder.split(",").filter { it.isNotEmpty() }
    val orderedTags = savedTagOrder
        .takeIf { it.size == 4 && it.toSet() == defaultTagOrder.toSet() }
        ?: defaultTagOrder
    val tags = orderedTags.filter { tag ->
        when (tag) {
            BottomNavTag.HOME -> appConfig.showHome
            BottomNavTag.DISCOVERY -> appConfig.showDiscovery
            else -> true
        }
    }
    return tags.ifEmpty { listOf(BottomNavTag.BOOKSHELF) }
}

/** 书架页：3D 书架 + 分组页签 + 下拉刷新（交互细节在 LanghuanShelf） */
@Composable
private fun BookshelfTabContent(
    viewModel: BookshelfViewModel,
    navigator: AppNavigator,
    scrollState: ShelfScrollState,
    gotoTopTick: Int,
    // 书架 tab 是否选中 (书架 DB 订阅的 tab 维度; 前台 + 栈顶由本页 Lifecycle 提供)
    tabSelected: Boolean,
    // 主界面是栈顶时分组返回拦截才生效 (否则压栈页面的返回键会被不可见书架页吞掉)
    isRootTop: Boolean,
) {
    var showAppLog by remember { mutableStateOf(false) }
    // 分组长按或管理列表编辑 → GroupEditDialog。
    var editingGroup by remember { mutableStateOf<BookGroup?>(null) }
    var addingGroup by remember { mutableStateOf(false) }
    // 溢出菜单 "group_manage" → GroupManageDialog (分组列表管理)
    var showGroupManage by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val groups by viewModel.bookGroups.collectAsState()
    var manageableGroups by remember { mutableStateOf<List<BookGroup>>(emptyList()) }
    // 分组管理对话框数据流, 随 tab 激活启停 (不可见时零订阅)
    LaunchedEffect(tabSelected) {
        if (!tabSelected) return@LaunchedEffect
        AppDbProviders.get().bookGroupDao.flowAll()
            .distinctUntilChanged()
            .conflate()
            .collect { manageableGroups = it }
    }
    // 对照 BookshelfManageRoute: GroupViewModelShared 持久化分组增删改
    val groupVm = remember(scope) { GroupViewModelShared(scope) }
    // 溢出菜单 "add_url" / "import_bookshelf" → 输入框对话框 (对照 BaseBookshelfFragment
    // showAddBookByUrlAlert / importBookshelfAlert)
    var showAddByUrl by remember { mutableStateOf(false) }
    var showImportShelf by remember { mutableStateOf(false) }
    val addVm = remember(scope) { BookshelfAddViewModelShared(scope) }
    val currentGroupId by viewModel.currentGroupId.collectAsState()

    val callbacks = remember(navigator, currentGroupId) {
        BookshelfActionsCallbacks(
            onRefresh = { viewModel.upToc() },
            onAddLocalBook = { navigator.push(AppRoute.ImportBook) },
            onAddRemoteBook = { navigator.push(AppRoute.RemoteBook) },
            onShowAddBookByUrlAlert = { showAddByUrl = true },
            // 对照原版 BaseBookshelfFragment: startActivity<BookshelfManageActivity> {
            //   putExtra("groupId", groupId) } — 管理页只显示书架当前选中分组的书
            onOpenBookshelfManage = { navigator.push(AppRoute.BookshelfManage(currentGroupId)) },
            onShowGroupManage = { showGroupManage = true },
            onImportBookshelf = { showImportShelf = true },
            onShowAppLog = { showAppLog = true },
            onRefreshShelf = { viewModel.refresh() },
        )
    }
    BookshelfScreen(
        viewModel = viewModel,
        // 书架条目是 bookDao.observeAll() flow 实体: 进入路由前拷贝隔离
        // (toRouteRef 不再内部 copy, DB-flow 边界显式 copy 防别名串扰)
        // sharedToken: 被点封面自签的页转场配对 token。只有目标页上有封面端点时才交出去
        // (阅读/漫画/视频页没有封面端点, 交出去只会让出发端白等); 音频页封面就是端点, 照传
        onBookClick = { book, sharedToken ->
            val route = book.copy().toReadRoute()
            navigator.push(route, sharedToken = sharedToken.takeIf { route is AppRoute.AudioPlay })
        },
        onBookLongClick = { book, sharedToken ->
            navigator.push(AppRoute.BookInfo(book.copy().toRouteRef()), sharedToken = sharedToken)
        },
        onSearchClick = { navigator.push(AppRoute.Search()) },
        onGroupLongClick = { group -> editingGroup = group },
        bookshelfActionsCallbacks = callbacks,
        scrollState = scrollState,
        gotoTopTick = gotoTopTick,
        isRootTop = isRootTop,
        tabSelected = tabSelected,
    )
    // 添加网址 / 导入书架进度 (对照 BaseBookshelfFragment.observeLiveBus + ensureWaitDialog:
    // count<0 关闭, 否则 "添加中... (n)"; 取消时 cancel addBookJob)
    val addBookProgress by addVm.addBookProgress.collectAsState(initial = -1)
    if (addBookProgress >= 0) {
        WaitDialog(
            visible = true,
            message = "添加中... ($addBookProgress)",
            onDismissRequest = { addVm.cancelAddBook() },
        )
    }
    // 应用日志对话框 (对照 SearchRoute 同名状态)
    if (showAppLog) {
        AppLogDialog(onDismiss = { showAppLog = false })
    }
    // "添加网址" (对照 BaseBookshelfFragment.showAddBookByUrlAlert: 单行输入 hint=url)
    if (showAddByUrl) {
        TextInputDialog(
            title = stringResource(Res.string.add_book_url),
            hint = "url",
            onConfirm = {
                showAddByUrl = false
                if (it.isNotBlank()) addVm.addBookByUrl(it)
            },
            onDismiss = { showAddByUrl = false },
        )
    }
    // "导入书架" (对照 BaseBookshelfFragment.importBookshelfAlert: 输入 url/json;
    // neutralButton 选文件走平台文件选择器 txt/json, 读文本后走同一 importBookshelf 入口;
    // 取消选择不动作, 对话框保持打开, 与原版 HandleFileContract 取消行为一致)
    if (showImportShelf) {
        TextInputDialog(
            title = stringResource(Res.string.import_bookshelf),
            hint = "url/json",
            neutralButton = AlertButton(
                text = stringResource(Res.string.select_file),
                dismissOnClick = false,
                onClick = {
                    scope.launch {
                        val path = withContext(IoDispatcher) {
                            PlatformServiceProviders.get().files
                                .pickFile(FileFilter(extensions = listOf("txt", "json")))
                        }
                        if (path != null) {
                            val text = withContext(IoDispatcher) { BackupFileOps.readText(path) }
                            showImportShelf = false
                            addVm.importBookshelf(text, currentGroupId)
                        }
                    }
                },
            ),
            onConfirm = {
                showImportShelf = false
                if (it.isNotBlank()) addVm.importBookshelf(it, currentGroupId)
            },
            onDismiss = { showImportShelf = false },
        )
    }
    // 分组管理对话框与原版一致，编辑和新增使用完整 GroupEditDialog。
    if (showGroupManage) {
        GroupManageDialog(
            groups = manageableGroups,
            onAddGroup = { addingGroup = true },
            onEditGroup = { editingGroup = it },
            onUpdateGroup = { groupVm.upGroup(it) },
            onPersistOrder = { ordered -> groupVm.upGroup(*ordered.toTypedArray()) },
            onDismiss = { showGroupManage = false },
            canAddGroup = { AppDbProviders.get().bookGroupDao.canAddGroup() },
        )
    }
    if (addingGroup || editingGroup != null) {
        GroupEditDialog(
            group = editingGroup,
            onConfirm = { updated ->
                if (addingGroup) {
                    groupVm.addGroup(
                        updated.groupName,
                        updated.bookSort,
                        updated.enableRefresh,
                        updated.cover,
                    ) { addingGroup = false }
                } else {
                    groupVm.upGroup(updated) { editingGroup = null }
                }
            },
            onDismiss = {
                addingGroup = false
                editingGroup = null
            },
            onDelete = { del ->
                groupVm.delGroup(del) { editingGroup = null }
            },
        )
    }
}

/**
 * 发现 tab: 通过 [ExploreScreenModel] 接入 sources/pinned/groups/kinds 数据流,
 * 导航类 actions 走 [AppNavigator], 平台对话框 (删除确认/收藏删除/分类错误) 本 Route 持有。
 *
 * 对照 ExploreRoute (独立发现页): 共用同一 ScreenModel + actions 模式, 差异仅无 onBack。
 */
@Composable
private fun ExploreTabContent(
    entry: RouteEntry,
    screenModel: ExploreScreenModel,
    listState: LazyListState,
    navigator: AppNavigator,
) {
    val screenState by screenModel.state.collectAsState()
    val scope = rememberCoroutineScope()

    val uiState = remember(screenState, listState) {
        ExploreUiState(
            sources = screenState.sources,
            pinned = screenState.pinned,
            groups = screenState.groups,
            searchKey = screenState.searchKey,
            expandedUrl = screenState.expandedUrl,
            expandedSource = screenState.expandedSource,
            expandedKinds = screenState.expandedKinds,
            loadingUrl = screenState.loadingUrl,
            listState = listState,
        )
    }

    // 平台对话框状态 (对照 ExploreRoute 同名状态)
    var pendingDeleteSource by remember { mutableStateOf<BookSourcePart?>(null) }
    var pendingRemovePin by remember { mutableStateOf<PinnedExplore?>(null) }
    var kindError by remember { mutableStateOf<ExploreKind?>(null) }

    val actions = remember(navigator, screenModel, scope) {
        object : ExploreUiActions {
            override fun onSearch(query: String) {
                screenModel.dispatch(ExploreUiEvent.SetSearch(query))
            }

            override fun onGroup(group: String) {
                screenModel.dispatch(ExploreUiEvent.SetGroup(group))
            }

            override fun onToggleExpand(item: BookSourcePart) {
                screenModel.dispatch(ExploreUiEvent.ToggleExpand(item))
            }

            // 对照 ExploreTabState.openPinned: 查 DB 取 source 后跳 ExploreShow; 失败 toast
            // 搜索类收藏 (searchKey 非空) 跳单源搜索结果页 (固定词)
            override fun onOpenPinned(pin: PinnedExplore) {
                scope.launch {
                    val source = withContext(IoDispatcher) {
                        AppDbProviders.get().bookSourceDao.getBookSource(pin.sourceUrl)
                    }
                    if (source != null) {
                        val searchKey = pin.searchKey
                        if (searchKey != null) {
                            navigator.push(AppRoute.SourceSearchShow(source, searchKey))
                        } else {
                            navigator.push(
                                AppRoute.ExploreShow(
                                    source,
                                    pin.categoryName,
                                    pin.categoryUrl
                                )
                            )
                        }
                    } else {
                        Toasters.get().toast("Source not found")
                    }
                }
            }

            override fun onRemovePinned(pin: PinnedExplore) {
                pendingRemovePin = pin
            }

            override fun onOpenExplore(source: BookSource, title: String, exploreUrl: String?) {
                navigator.push(AppRoute.ExploreShow(source, title, exploreUrl))
            }

            override fun onShowKindError(kind: ExploreKind) {
                kindError = kind
            }

            override fun onRunKindJs(source: BookSource, js: String) {
                screenModel.dispatch(ExploreUiEvent.RunKindJs(source, js))
            }

            override fun onEditSource(sourceUrl: String) {
                navigator.push(AppRoute.BookSourceEdit(sourceUrl), RouteResults.BOOK_SOURCE_EDIT)
            }

            override fun onToTop(source: BookSourcePart) {
                screenModel.dispatch(ExploreUiEvent.ToTop(source))
            }

            override fun onLogin(source: BookSourcePart) {
                // 统一登录入口 (对照原 ExploreAdapter: getBookSource()?.showLoginDialog()):
                // 源对象由 showSourceLogin 内部按 url 查库, URL 登录直开全屏 WebView
                showSourceLogin(source.bookSourceUrl)
            }

            override fun onSearchBook(source: BookSourcePart) {
                navigator.push(AppRoute.Search(searchScope = SearchScope(source).toString()))
            }

            override fun onRefreshSource(source: BookSourcePart) {
                screenModel.dispatch(ExploreUiEvent.RefreshSource(source))
            }

            override fun onDeleteSource(source: BookSourcePart) {
                pendingDeleteSource = source
            }
        }
    }

    // 书源编辑返回: 重取当前展开项分类。原版的"编辑返回不发任何事件"在 Compose 下不成立
    // (行留在 composition 不会重新绑数据), 故保留此通知, 语义为"展开中也能立即看到新分类" (优于原版);
    // 未展开的行本来就不持有数据, 下次展开靠 loadKinds 现取天然新鲜。
    // 原版"按旧 url 在 sources 里 find 不到就静默不刷"的分支仍保留
    // (refreshCurrentExpanded: expandedUrl 命中不了 sources.find 即 return, 语义同原版 getItem(pos) ?: return)。
    LaunchedEffect(Unit) {
        navigator.resultsFor(entry.id).filter { it.key == RouteResults.BOOK_SOURCE_EDIT }.collect { result ->
            val saved = (result.payload as? RouteResultPayload.BookSourceEdit)?.source
            if (saved != null) {
                screenModel.dispatch(ExploreUiEvent.OnBookSourceSaved(saved))
            } else {
                FlowBus.with(EventBus.REFRESH_EXPLORE).tryEmit("")
            }
        }
    }

    // 删除书源确认 (对照 ExploreTabState.deleteSource 的 alert)
    pendingDeleteSource?.let { src ->
        AppAlertDialog(
            onDismissRequest = { pendingDeleteSource = null },
            title = stringResource(Res.string.draw),
            message = stringResource(Res.string.sure_del) + "\n" + src.bookSourceName,
            okButton = AlertButton(stringResource(Res.string.ok)) {
                screenModel.dispatch(ExploreUiEvent.DeleteSource(src))
            },
            cancelButton = AlertButton(stringResource(Res.string.cancel)),
        )
    }

    // 移除收藏确认 (对照 ExploreTabState.removePinned 的 alert)
    pendingRemovePin?.let { pin ->
        AppAlertDialog(
            onDismissRequest = { pendingRemovePin = null },
            title = stringResource(Res.string.draw),
            message = stringResource(Res.string.sure_del) + "\n${pin.sourceName}-${pin.categoryName}",
            okButton = AlertButton(stringResource(Res.string.ok)) {
                screenModel.dispatch(ExploreUiEvent.RemovePinned(pin))
            },
            cancelButton = AlertButton(stringResource(Res.string.cancel)),
        )
    }

    // 分类错误详情 (对照 ExploreTabState.showKindError 的 TextDialog)
    kindError?.let { kind ->
        TextDialog(
            title = "ERROR",
            content = kind.url.orEmpty(),
            onDismiss = { kindError = null },
        )
    }

    ExploreScreen(state = uiState, actions = actions)
}

/**
 * 我的 tab: 四组设置面板，与 push 路由共用 [MyConfigContent]。
 */
@Composable
private fun MyTabContent(navigator: AppNavigator) {
    Column(Modifier.fillMaxSize()) {
        MyTabTitleBar()
        MyConfigContent(navigator = navigator)
    }
}

/**
 * "我的" tab 顶栏：页眉与书架 / 发现 / 本地同源，tab 页无返回键。
 */
@Composable
private fun MyTabTitleBar() {
    val eInk = LocalEInk.current
    Box(Modifier.fillMaxWidth().then(if (eInk) Modifier else Modifier.platformStatusBarPadding())) {
        LanghuanPageHeader(title = stringResource(Res.string.my))
        if (eInk) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(AppTheme.colors.secondaryText.copy(alpha = 0.4f))
                    .align(Alignment.BottomStart),
            )
        }
    }
}
