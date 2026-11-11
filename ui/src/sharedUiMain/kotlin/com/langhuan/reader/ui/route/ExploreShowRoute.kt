package com.langhuan.reader.ui.route

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.langhuan.reader.constant.BookType
import com.langhuan.reader.data.entities.BookSource
import com.langhuan.reader.data.entities.SearchBook
import com.langhuan.reader.help.book.addType
import com.langhuan.reader.help.book.isAudio
import com.langhuan.reader.help.config.AppConfigProviders
import com.langhuan.reader.help.showSourceLogin
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.ui.book.explore.ExploreShowScreen
import com.langhuan.reader.ui.book.explore.ExploreShowScreenModel
import com.langhuan.reader.ui.book.explore.ExploreShowUiActions
import com.langhuan.reader.ui.book.explore.ExploreShowUiEvent
import com.langhuan.reader.ui.book.search.SearchScope
import com.langhuan.reader.ui.bookshelf.LocalBookCoverSlot
import com.langhuan.reader.ui.bookshelf.LocalCoverRatioLayout
import com.langhuan.reader.ui.bookshelf.ShelfVideoItem
import com.langhuan.reader.ui.book.search.toBookItemUi
import com.langhuan.reader.ui.bookshelf.toCoverBook
import com.langhuan.reader.ui.compose.component.ExploreOptionsRow
import com.langhuan.reader.ui.dialog.NumberPickerDialog
import com.langhuan.reader.ui.explore.ExploreShowViewModelShared
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppOverlay
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.RouteEntry
import com.langhuan.reader.ui.root.OnRouteLifecycle
import com.langhuan.reader.ui.root.ScreenModelStore
import com.langhuan.reader.ui.root.screenModelScope
import com.langhuan.reader.ui.root.toRouteRef
import com.langhuan.reader.ui.widget.dialog.TextDialog
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.bottom_line
import com.langhuan.reader.ui.generated.resources.empty
import com.langhuan.reader.ui.generated.resources.error
import com.langhuan.reader.ui.generated.resources.error_load_msg
import com.langhuan.reader.ui.generated.resources.explore_cols
import org.jetbrains.compose.resources.stringResource

/**
 * AppRoute.ExploreShow / AppRoute.ExploreShowByUrl shared 路由入口。
 *
 * 复用 shared [ExploreShowScreen] + [ExploreShowScreenModel] + [ExploreShowViewModelShared];
 * 路由参数取自 [entry]。三 slot 均用 shared 默认实现:
 * optionsRow 复用公共 [ExploreOptionsRow] (与主页展示项同一份 ExploreOptionView 复刻),
 * videoItem 复用 [ShelfVideoItem], cover 复用 [LocalBookCoverSlot] (宿主端可覆盖注入平台封面组件)。
 *
 * 双变体 (对照 master ExploreShowActivity):
 * - [AppRoute.ExploreShow]: 应用内跳转, 已有 [BookSource] 对象直传, 不查源
 *   (vm.initData(source, …) 重载, 用户要求: 发现→show 应用内跳转不做源查找)。
 * - [AppRoute.ExploreShowByUrl]: 外部入口 (SearchActivity alias 同款), 只带
 *   sourceUrl/exploreUrl/exploreName, 查源下沉到路由内
 *   (vm.initData(exploreName, exploreUrl, sourceUrl), 对照 master initData(intent):
 *   IntentData.source ?: DAO 查 sourceUrl), 查源期间页面直接渲染加载态, 书架不进导航栈。
 *
 * VM StateFlow → ScreenModel 事件桥接对照 app 端 Activity.observe(ViewModel LiveData)。
 */
@Composable
fun ExploreShowRoute(
    entry: RouteEntry,
    navigator: AppNavigator,
    screenModelStore: ScreenModelStore,
) {
    val route = entry.route
    val screenModel = screenModelStore.getOrCreateTyped(entry) { ExploreShowScreenModel() }

    // VM 创建 (组合委托, 对照 app 端 ExploreShowViewModel)
    val vmScope = remember { screenModelScope("发现列表") }
    val vm = remember(vmScope) { ExploreShowViewModelShared(vmScope) }
    // VM 作用域挂"在栈期间" (STARTED): 对照原版 Activity 存活期, 出栈才取消。
    // 筛选实例挂 VM (页面会话) 随页面销毁自然丢弃, 无需退出清理。
    OnRouteLifecycle(onLeave = { vmScope.cancel() })

    // footer 文案 (对照 Activity getString(R.string.empty / bottom_line / error_load_msg))
    val emptyText = stringResource(Res.string.empty)
    val bottomLineText = stringResource(Res.string.bottom_line)
    val errorLoadText = stringResource(Res.string.error_load_msg, "点击查看详情")
    val errorTitle = stringResource(Res.string.error)

    // 标题初始化 (对照原 Activity intent exploreName / discovery; ByUrl 变体 extra 可为空;
    // SourceSearchShow 用源名)
    // route 由 RouteContent 保证只分派三变体, else 分支不可达 (穷尽性占位)
    val title = when (route) {
        is AppRoute.ExploreShow -> route.title
        is AppRoute.ExploreShowByUrl -> route.title.orEmpty()
        is AppRoute.SourceSearchShow -> route.source.bookSourceName
        else -> ""
    }
    LaunchedEffect(title) {
        screenModel.dispatch(ExploreShowUiEvent.TitleChanged(title))
    }

    // 首次加载 + 初始化数据 (对照 Activity.onActivityCreated: startLoad + initData)
    LaunchedEffect(vm, route) {
        when (route) {
            // 应用内跳转: 已有 BookSource 直传, 不查源 (用户要求)
            is AppRoute.ExploreShow -> vm.initData(route.source, route.title, route.exploreUrl)
            // 外部入口: 查源下沉到路由内 (IntentData.source ?: DAO 查 sourceUrl)
            is AppRoute.ExploreShowByUrl -> vm.initData(
                route.title,
                route.exploreUrl,
                route.sourceUrl
            )
            // 搜索模式: 数据走书源 searchUrl 搜索规则
            is AppRoute.SourceSearchShow -> vm.initDataSearch(route.source, route.keyword)
            // 不可达 (RouteContent 仅分派三变体); 占位保证 when 穷尽
            else -> Unit
        }
    }

    // VM 当前请求状态 → ScreenModel: 只消费同一份 books/hasNext/loading/error/notice。
    LaunchedEffect(vm) {
        vm.pageState.collect { page ->
            if (page.loading) {
                screenModel.dispatch(
                    if (page.books.isEmpty()) {
                        ExploreShowUiEvent.StartLoad
                    } else {
                        ExploreShowUiEvent.LoadMore
                    }
                )
            } else if (page.error != null) {
                if (page.books.isEmpty()) {
                    screenModel.dispatch(ExploreShowUiEvent.ClearBooks)
                }
                screenModel.dispatch(ExploreShowUiEvent.ErrorLoaded(page.error, errorLoadText))
                page.notice?.let { Toasters.get().toast(it) }
            } else {
                screenModel.dispatch(
                    ExploreShowUiEvent.BooksLoaded(
                        books = page.books,
                        hasNextPage = page.hasNextPage,
                        emptyText = emptyText,
                        bottomLineText = bottomLineText,
                    )
                )
                page.notice?.let { Toasters.get().toast(it) }
            }
        }
    }
    LaunchedEffect(vm) {
        vm.upAdapterFlow.collect {
            screenModel.dispatch(ExploreShowUiEvent.BookshelfVersionBump)
        }
    }
    LaunchedEffect(vm) {
        vm.upStarFlow.collect { isFavorite ->
            if (isFavorite != null) screenModel.dispatch(
                ExploreShowUiEvent.IsFavoriteChanged(
                    isFavorite
                )
            )
        }
    }
    LaunchedEffect(vm) {
        vm.sourceReadyFlow.collect {
            screenModel.dispatch(ExploreShowUiEvent.ExploreStyleChanged(vm.exploreStyle))
            // 菜单"书源登录"显隐: 书源带登录入口 (loginUrl/loginUi 非空, 对照原 hasLoginUrl)
            screenModel.dispatch(
                ExploreShowUiEvent.LoginAvailabilityChanged(vm.bookSource?.hasLogin() == true)
            )
        }
    }
    val state by screenModel.state.collectAsState()

    // 错误详情对话框状态 (对照 Activity.onFooterClickImpl 的 alert)
    var showErrorDialog by remember { mutableStateOf(false) }
    // 列数选择器 (原走 PlatformCapabilities.showColumnPicker, 仅 Android 有实现; 改用 shared 对话框)
    var showColumnPicker by remember { mutableStateOf(false) }

    // 刷新当前列表: 清空 books + 重拉第一页 (对照注册的 refreshHandler / onExploreOptionChanged)
    val refresh = {
        screenModel.dispatch(ExploreShowUiEvent.ClearBooks)
        vm.explore(true)
    }

    val actions = remember(navigator, screenModel, vm) {
        object : ExploreShowUiActions {
            override fun onBack() {
                navigator.pop()
            }

            // 对照 Activity.scrollToTop: scrollTopEpoch++
            override fun onTitleClick() {
                screenModel.dispatch(ExploreShowUiEvent.ScrollTopBump)
            }

            // 对照 Activity.onToggleFavorite: viewModel.toggleFavorite()
            override fun onToggleFavorite() {
                vm.toggleFavorite()
            }

            // 菜单 - 刷新: 重拉第一页 (对齐注册的 refreshHandler 语义)
            override fun onRefresh() {
                refresh()
            }

            // 菜单 - 书源登录: 统一登录入口, URL 登录桌面端直开登录窗口 (2026-08-07)
            override fun onLogin() {
                val source = vm.bookSource ?: return
                showSourceLogin(source.bookSourceUrl, source)
            }

            // 对照 Activity.switchLayout: viewModel.switchLayout() + exploreStyle 更新
            override fun onSwitchLayout() {
                vm.switchLayout()
                screenModel.dispatch(ExploreShowUiEvent.ExploreStyleChanged(vm.exploreStyle))
            }

            // 对照 Activity.showColumnPicker: showNumberPicker + setColumnCount
            override fun onShowColumnPicker() {
                showColumnPicker = true
            }

            // 对照 Activity.showSourceFilterRule: 弹 scoped 列表对话框 (非跳转管理页)
            override fun onShowSourceFilterRule() {
                val scope = vm.bookSource?.let { SearchScope(it).toString() }
                navigator.showOverlay(
                    AppOverlay.Dialog(
                        key = "sourceFilterRuleList",
                        payload = scope
                    )
                )
            }

            // 对照 Activity.onFooterClickImpl: errorMsg 非空弹详情与复制, 否则触发加载
            override fun onFooterClick() {
                if (screenModel.errorMsg.isNotBlank()) {
                    showErrorDialog = true
                    return
                }
                if (!screenModel.state.value.footerLoading) {
                    screenModel.dispatch(ExploreShowUiEvent.LoadMore)
                    vm.explore()
                }
            }

            // 对照 Activity.scrollToBottom: guard + hasMoreLoad + viewModel.explore()
            override fun onScrollToBottom() {
                if (screenModel.footerHasMore && !screenModel.state.value.footerLoading) {
                    screenModel.dispatch(ExploreShowUiEvent.LoadMore)
                    vm.explore()
                }
            }

            // 对照 Activity.onBookClickImpl + showBookInfo
            override fun onBookClick(book: SearchBook, longClick: Boolean, sharedToken: String?) {
                // 补 notShelf type (对齐原 registerListener)
                if (!vm.isInBookShelf(book)) {
                    book.addType(BookType.notShelf)
                }
                // bookUrl 含 "::" 自跳转 ExploreShow (对照 showBookInfo 的 urlParts 分支)
                val urlParts = book.bookUrl.split("::", limit = 2)
                if (urlParts.size == 2) {
                    val source = vm.bookSource ?: return
                    navigator.push(AppRoute.ExploreShow(source, urlParts[0], urlParts[1]))
                    return
                }
                // longClick || !devFeat → BookInfo; 否则按类型分流
                if (longClick || !AppConfigProviders.get().devFeat) {
                    navigator.push(AppRoute.BookInfo(book.toRouteRef()), sharedToken = sharedToken)
                    return
                }
                when {
                    // 音频书直达播放页 (与书架 startActivityForBook 分流一致)
                    book.isAudio -> navigator.push(
                        AppRoute.AudioPlay(book.toRouteRef()),
                        sharedToken = sharedToken,
                    )
                    else -> navigator.push(
                        AppRoute.BookInfo(book.toRouteRef()),
                        sharedToken = sharedToken,
                    )
                }
            }

            // 对照 Activity.isInBookshelf: viewModel.isInBookShelf(book)
            override fun isInBookshelf(book: SearchBook): Boolean {
                return vm.isInBookShelf(book)
            }

            // 对照 Activity.onExploreOptionChangedImpl: 清空 books + hasMoreLoad + explore(true)
            override fun onExploreOptionChanged() {
                screenModel.dispatch(ExploreShowUiEvent.ClearBooks)
                vm.explore(true)
            }

        }
    }

    // 刷新处理器挂本页 Lifecycle 的"在栈期间" (STARTED), 不挂组合存亡
    OnRouteLifecycle(
        onEnter = { navigator.registerRefreshHandler(entry.id) { refresh() } },
        onLeave = { navigator.unregisterRefreshHandler(entry.id) },
    )

    // 列数选择器 (对照 Activity.showColumnPicker → showNumberPicker(min=0, max=6))
    if (showColumnPicker) {
        NumberPickerDialog(
            title = stringResource(Res.string.explore_cols),
            value = BookSource.exploreStyleCols(vm.exploreStyle).coerceIn(0, 6),
            range = 0..6,
            onConfirm = { cols ->
                vm.setColumnCount(cols)
                screenModel.dispatch(ExploreShowUiEvent.ExploreStyleChanged(vm.exploreStyle))
                showColumnPicker = false
            },
            onDismiss = { showColumnPicker = false },
        )
    }

    // 错误详情对话框 (支持查看详情与一键复制); 对照原版 LoadMoreView.showErrorDialog:
    // 发现页不挂重试监听, 故弹窗无重试按钮
    if (showErrorDialog) {
        TextDialog(
            title = errorTitle,
            content = screenModel.errorMsg,
            onDismiss = { showErrorDialog = false },
        )
    }

    // 封面比例布局状态: 与本页结果集同寿命 (由 ScreenModel 持有), 页面组合重建经此处取回
    CompositionLocalProvider(
        LocalCoverRatioLayout provides screenModel.coverRatioLayout,
    ) {
        ExploreShowScreen(
            state = state,
            actions = actions,
            optionsRowSlot = {
                val options by vm.optionsFlow.collectAsState()
                ExploreOptionsRow(
                    options = options,
                    ownerKey = vm.optionsOwnerKey,
                    onSelect = { name, value ->
                        if (vm.selectOption(name, value)) actions.onExploreOptionChanged()
                    },
                    onMultiSelect = { name, values ->
                        if (vm.selectOptions(name, values)) actions.onExploreOptionChanged()
                    },
                    onReset = { name ->
                        if (vm.resetOption(name)) actions.onExploreOptionChanged()
                    },
                )
            },
            // 视频卡: 复用 ShelfVideoItem (item_explore_video 的 shared Compose 版), 封面走 LocalBookCoverSlot
            videoItemSlot = { book, inBookshelf, onClick, onLongClick ->
                val coverBook = remember(book, inBookshelf) { book.toCoverBook(inBookshelf) }
                ShelfVideoItem(
                    book = book.toBookItemUi(),
                    coverReloadTick = state.bookshelfVersion,
                    onClick = onClick,
                    onLongClick = onLongClick,
                    inBookshelf = inBookshelf,
                    coverSlot = { _, modifier, coverRatio, coverReloadTick ->
                        LocalBookCoverSlot.current(coverBook, modifier, coverRatio, coverReloadTick)
                    },
                )
            },
            // 封面: 复用 LocalBookCoverSlot (默认 SharedBookCover, 各端统一)
            coverSlot = { book, inBookshelf, coverRatio, modifier ->
                // toCoverBook 结果缓存一次, 避免每次重组新建 Book (对照 SearchScreen coverSlot 写法)
                LocalBookCoverSlot.current(
                    remember(book, inBookshelf) { book.toCoverBook(inBookshelf) },
                    modifier,
                    coverRatio,
                    0,
                )
            },
        )
    }
}
