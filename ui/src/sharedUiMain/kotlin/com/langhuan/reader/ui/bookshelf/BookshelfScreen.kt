package com.langhuan.reader.ui.bookshelf

import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.lifecycle.Lifecycle
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import com.langhuan.reader.constant.BookType
import com.langhuan.reader.constant.EventBus
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.BookGroup
import com.langhuan.reader.data.entities.SearchBook
import com.langhuan.reader.help.book.addType
import com.langhuan.reader.help.book.isNotShelf
import com.langhuan.reader.help.config.AppConfigProviders
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.help.config.resolveImagePath
import com.langhuan.reader.help.coroutine.IoDispatcher
import com.langhuan.reader.uimodel.BookItemUi
import com.langhuan.reader.uimodel.GroupUi
import com.langhuan.reader.ui.bookshelf.shelf.LanghuanShelf
import com.langhuan.reader.ui.bookshelf.shelf.LanghuanShelfState
import com.langhuan.reader.ui.compose.component.AppScrollTabRow
import com.langhuan.reader.ui.compose.component.LanghuanPageHeader
import com.langhuan.reader.ui.compose.component.LanghuanSearchEntry
import com.langhuan.reader.ui.compose.component.pagerPageFocus
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.root.OnRouteLifecycle
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.LocalEInk
import com.langhuan.reader.utils.FlowBus
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.bookshelf
import com.langhuan.reader.ui.generated.resources.bookshelf_empty
import com.langhuan.reader.ui.generated.resources.loading
import com.langhuan.reader.ui.generated.resources.search_book_key
import org.jetbrains.compose.resources.stringResource

/**
 * 书架 Screen (KMP 版, commonMain 共享)。
 *
 * 3D 书架单一形态：分组 tab + HorizontalPager，每页一整排 3D 书（[LanghuanShelf]），
 * 中心那本抽出、其余退回书脊。分组切换与滚顶都由 3D 书架自身状态承担。
 *
 * - **顶栏**: 分组切换 ([AppScrollTabRow]) + 搜索图标 + 溢出菜单槽 ([actions] slot)
 * - **内容区**: [HorizontalPager] 左右滑切换分组，pager 滑动同步 tab 高亮
 * - **空态**: 居中提示 [bookshelf_empty]
 *
 * # 简化项
 *
 * - 下拉刷新: 启用 (refreshEnabled=true), onRefresh 调 [BookshelfViewModel.upToc]
 * - refreshingUrls 由 [BookshelfViewModel] 订阅 UP_BOOKSHELF 事件维护
 *
 * # 路由跳转
 *
 * 全部用回调注入, 不依赖 Activity/Intent:
 * - [onBookClick] / [onBookLongClick]: 书籍点击/长按 (打开阅读 / 详情页)
 * - [onSearchClick]: 顶栏搜索图标点击
 * - [onGroupLongClick]: 分组长按 (编辑分组, 桌面端可省略)
 * - [actions]: 顶栏右侧溢出菜单槽 (添加书/书架管理/分组管理等, 由宿主端注入)
 *
 * @param viewModel 书架 VM (持有 groups/books/currentGroupId state)
 * @param onBookClick 书籍点击回调
 * @param onBookLongClick 书籍长按回调 (默认空)
 * @param onSearchClick 搜索图标点击回调 (默认空)
 * @param onGroupLongClick 分组长按回调 (默认空)
 * @param modifier 外部 Modifier
 * @param bookshelfActionsCallbacks 顶栏溢出菜单回调集合 (书架管理/添加本地/远程书籍/分组管理/日志等), 默认空实现; 宿主端注入后菜单项生效
 * @param actions 顶栏右侧溢出菜单槽, 默认 [DefaultBookshelfActions] (搜索图标 + 完整溢出菜单)
 * @param gotoTopTick 滚顶信号 (对照 BookshelfTabController.gotoTop), 宿主端每次 tab 双击 +1;
 *   作用于当前分组页的 3D 书架, 回到第一本
 */
@Composable
fun BookshelfScreen(
    viewModel: BookshelfViewModel,
    onBookClick: (Book, String?) -> Unit,
    onBookLongClick: (Book, String?) -> Unit = { _, _ -> },
    onSearchClick: () -> Unit = {},
    onGroupLongClick: (BookGroup) -> Unit = {},
    modifier: Modifier = Modifier,
    bookshelfActionsCallbacks: BookshelfActionsCallbacks = BookshelfActionsCallbacks(),
    actions: @Composable RowScope.() -> Unit = {
        DefaultBookshelfActions(
            onSearchClick,
            bookshelfActionsCallbacks
        )
    },
    gotoTopTick: Int = 0,
    /**
     * 本页在当前 tab 内是否处于选中态 (书架 tab 被选中)。
     *
     * 只承担"tab"这一个维度: "前台 + 主界面栈顶"由本页 Lifecycle 提供 (RESUMED),
     * 两者相乘即"书架可见" —— 与 DB 订阅的启停判据同源, 不另立一套手写判定。
     */
    tabSelected: Boolean = true,
) {
    val colors = AppTheme.colors
    /** 各分组 3D 书架状态登记表 (供 tab 双击滚顶取当前分组实例) */
    // 普通 Map：分组页在组合里 getOrPut 取状态，不能是快照 Map（写快照会触发重组）
    val shelfStates: MutableMap<Long, LanghuanShelfState> = remember { mutableMapOf() }
    // 订阅启停 = 本页可见 (Lifecycle RESUMED) 且书架 tab 选中。
    // 对照原版: 书架 Fragment 被详情页盖住 / 退到后台 / 切到其它 tab 时 Lifecycle 降到 STARTED,
    // flowWithLifecycleAndDatabaseChangeFirst(RESUMED) 挂起收集 → 不查库; 回到 RESUMED 才重订并重查。
    // 缓存快照 (booksCache) 不随开关清空, 恢复时先用旧快照出帧再刷。
    OnRouteLifecycle(
        minState = Lifecycle.State.RESUMED,
        enabled = tabSelected,
        onEnter = { viewModel.setBookshelfActive(true) },
        onLeave = { viewModel.setBookshelfActive(false) },
    )
    val appConfig = remember { AppConfigProviders.get() }
    // 数量开关等配置变更走 BOOKSHELF_REFRESH, 顶栏计数与显示项据此重读
    var configTick by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        coroutineScope {
            launch { FlowBus.with(EventBus.NOTIFY_MAIN).collect { configTick++ } }
            launch { FlowBus.with(EventBus.BOOKSHELF_REFRESH).collect { configTick++ } }
        }
    }
    // 稳定化透传到条目层的回调: 上层 (MainRoute 等) 重组会新建 lambda 实例,
    // 直接透传时每次上层重组 → 本屏重组 → 各分组页参数变化。
    // rememberUpdatedState 桥接: 透传引用恒定, 调用时读最新实现, 行为语义不变。
    val state by viewModel.shelfState.collectAsState()
    // Ui 模型 → 实体回查表: 实体只在页面边界 (封面 / 点击长按) 使用, 不进条目组件
    val bookEntities by viewModel.bookEntities.collectAsState()
    val currentBookEntities = rememberUpdatedState(bookEntities)
    val currentOnBookClick = rememberUpdatedState(onBookClick)
    val stableOnBookClick: (BookItemUi, String?) -> Unit = remember {
        { item, token -> currentBookEntities.value[item.bookUrl]?.let { currentOnBookClick.value(it, token) } }
    }
    val currentOnBookLongClick = rememberUpdatedState(onBookLongClick)
    val stableOnBookLongClick: (BookItemUi, String?) -> Unit = remember {
        { item, token -> currentBookEntities.value[item.bookUrl]?.let { currentOnBookLongClick.value(it, token) } }
    }
    val currentOnGroupLongClick = rememberUpdatedState(onGroupLongClick)
    val stableOnGroupLongClick: (GroupUi) -> Unit = remember {
        { group ->
            viewModel.bookGroups.value.find { it.groupId == group.groupId }
                ?.let { currentOnGroupLongClick.value(it) }
        }
    }
    val currentOnRefresh = rememberUpdatedState<() -> Unit>({ viewModel.upToc() })
    val stableOnRefresh: () -> Unit = remember { { currentOnRefresh.value() } }
    val eInk = LocalEInk.current
    val groups = state.groups
    val currentGroupId = state.currentGroupId
    // 单一数据源: 页数据/顶栏计数均读 [ShelfStateUi] (未访问过的分组无条目, 顶栏显示 "..")
    val booksByGroup = state.booksByGroup
    // 封面比例收敛: 活跃集合 = 全部分组书籍 + 分组封面, 随书架数据增删清理;
    // 持有者由路由层下发, 书架子树重建 (导航栏方位切换) 不丢
    val coverRatioState = LocalCoverRatioLayout.current
    val activeCoverResources = remember(groups, booksByGroup) {
        shelfActiveCoverResources(groups, booksByGroup)
    }
    SideEffect { coverRatioState?.updateActiveResources(activeCoverResources) }
    val scope = rememberCoroutineScope()

    // 顶栏 tab 是否显示分组数量 (对照 app 端 AppConfig.bookshelfShowGroupCount)
    val showGroupCount = remember(configTick) { appConfig.bookshelfShowGroupCount }

    // HorizontalPager (对照 app 端 BookshelfScreen1, pageCount 动态跟随 groups)
    val pagerState = rememberPagerState(
        initialPage = if (groups.isNotEmpty()) {
            groups.indexOfFirst { it.groupId == currentGroupId }.coerceAtLeast(0)
        } else 0,
        pageCount = { groups.size },
    )
    // pager 滑动结束 (settledPage) → 同步 currentGroupId。
    // 不用 currentPage，避免手势过程中频繁改写全局选择状态。
    // 同时持久化 tab 位置 (对照 BookshelfFragment1.onTabSelected: AppConfig.saveTabPosition = position)
    val prefs = PreferenceProviders.get()
    LaunchedEffect(pagerState, groups) {
        if (groups.isEmpty()) return@LaunchedEffect
        snapshotFlow { pagerState.settledPage }.collect { page ->
            groups.getOrNull(page)?.let { group ->
                viewModel.selectGroup(group.groupId)
                prefs.putInt(PreferKey.saveTabPosition, page)
            }
        }
    }
    // 首次拿到分组后恢复上次 tab (对照 BookshelfFragment1.selectLastTab)。
    // 位置在组合期读一次, 避免被上面的 settledPage 持久化覆盖后读到 0;
    // 只改 currentGroupId, 实际滚动交给下面的同步 effect (单一滚动源, 无竞态)。
    val savedTabPosition = remember { appConfig.saveTabPosition }
    var tabRestored by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(groups.size) {
        if (tabRestored || groups.isEmpty()) return@LaunchedEffect
        tabRestored = true
        groups.getOrNull(savedTabPosition)?.let { viewModel.selectGroup(it.groupId) }
    }
    // 外部 currentGroupId 变化 → pager 同步 (仅初始化/外部切换, 用 scrollToPage 不触发动画避免循环)
    LaunchedEffect(currentGroupId, groups.size) {
        if (groups.isEmpty()) return@LaunchedEffect
        val targetIndex = groups.indexOfFirst { it.groupId == currentGroupId }
        if (targetIndex >= 0 && targetIndex != pagerState.currentPage) {
            pagerState.scrollToPage(targetIndex)
        }
    }
    // tab 选中位置直接跟随 pagerState.currentPage (无 selectGroup 一帧延迟)
    val displayGroupId = groups.getOrNull(pagerState.currentPage)?.groupId ?: currentGroupId

    // tab 双击滚顶 (对照 BookshelfFragment1.gotoTop → fragmentMap[groupId]?.gotoTop):
    // 3D 书架没有列表滚动状态, 由当前分组页的书架状态回到第一本
    LaunchedEffect(gotoTopTick) {
        if (gotoTopTick == 0) return@LaunchedEffect
        groups.getOrNull(pagerState.currentPage)?.let { shelfStates[it.groupId]?.gotoTop() }
    }

    Column(modifier.fillMaxSize().statusBarsPadding()) {
        LanghuanPageHeader(title = stringResource(Res.string.bookshelf)) {
            actions()
        }
        Spacer(Modifier.height(DesignTokens.spacingDefault))
        LanghuanSearchEntry(
            hint = stringResource(Res.string.search_book_key),
            onClick = onSearchClick,
            modifier = Modifier.padding(horizontal = DesignTokens.spacingMax),
        )
        BookshelfTopBar(
            groups = groups,
            currentGroupId = displayGroupId,
            showGroupCount = showGroupCount,
            onGroupClick = { groupId ->
                // tab 点击 → pager 滚动 → currentPage 变化 → selectGroup (见 LaunchedEffect)
                val targetIndex = groups.indexOfFirst { it.groupId == groupId }
                if (targetIndex >= 0) {
                    scope.launch {
                        if (eInk) pagerState.scrollToPage(targetIndex)
                        else pagerState.animateScrollToPage(targetIndex)
                    }
                }
            },
            onGroupLongClick = stableOnGroupLongClick,
        )
        if (groups.isEmpty()) {
            // 对照 BookshelfFragment1.upGroup: 无可见分组时自愈, 启用"全部"分组
            LaunchedEffect(Unit) {
                withContext(IoDispatcher) {
                    AppDbProviders.get().bookGroupDao.enableGroup(BookGroup.IdAll)
                }
            }
            // 无分组时显示空态 (懒加载自愈后会有"全部"分组, 这里只是过渡帧)
            BookshelfEmptyState()
        } else {
            HorizontalPager(
                state = pagerState,
                beyondViewportPageCount = 1, // 对齐原版 offscreenPageLimit=1，手势开始前相邻页已完成组合
                // (2026-09-15 实测过对照: 改成 0 对启动那 470ms 首绘无帮（429~468ms vs 448~470ms）,
                //  反而会让滑到相邻分组时才开始组合 → 保留 1)。
                key = { index -> groups[index].groupId },
            ) { page ->
                val group = groups.getOrNull(page) ?: return@HorizontalPager
                Box(Modifier.fillMaxSize().pagerPageFocus(pagerState, page)) {
                    GroupBooksPage(
                        group = group,
                        viewModel = viewModel,
                        shelfStates = shelfStates,
                        books = booksByGroup[group.groupId],
                        bookEntities = bookEntities,
                        refreshingUrls = state.refreshingBookUrls,
                        onBookClick = stableOnBookClick,
                        onBookLongClick = stableOnBookLongClick,
                        onRefresh = stableOnRefresh,
                    )
                }
            }
        }
    }
}

/**
 * 单个分组页 (对照 app 端 BookshelfScreen1 的 GroupBooksPage)。
 *
 * 数据经 [ShelfStateUi.booksByGroup] 单一数据源切片 (pager 组合中的分组页
 * 各自持有 Room 流, 由 VM 按页组合/离开维护, 见 [BookshelfViewModel.onGroupPageComposed]),
 * 每页一个 [LanghuanShelfState] 并登记到 [shelfStates] 供宿主滚顶按当前页取用;
 * 3D 书架仍按实体绘制, 由 [bookEntities] 在页面边界回查。
 */
@Composable
private fun GroupBooksPage(
    group: GroupUi,
    viewModel: BookshelfViewModel,
    shelfStates: MutableMap<Long, LanghuanShelfState>,
    books: List<BookItemUi>?,
    bookEntities: Map<String, Book>,
    refreshingUrls: Set<String>,
    onBookClick: (BookItemUi, String?) -> Unit,
    onBookLongClick: (BookItemUi, String?) -> Unit,
    onRefresh: () -> Unit,
) {
    // 页组合即订阅该分组数据流 (对齐原版 fragment 各自订阅, 相邻页数据预加载),
    // 离开组合取消 → 活跃流 = 当前 + 相邻共 ≤3 个
    DisposableEffect(group.groupId) {
        viewModel.onGroupPageComposed(group.groupId)
        onDispose { viewModel.onGroupPageDisposed(group.groupId) }
    }
    // 同一分组复用同一个书架状态，pager 回收该页后再回来仍停在原书
    val shelfState = remember(group.groupId) {
        shelfStates.getOrPut(group.groupId) { LanghuanShelfState() }
    }
    // 琅嬛阁 3D 书架：整页一本排书，中心那本抽出。分组仍由顶栏 tab 切换，
    // 横向拖动交给书架本身，因此不再叠一层 HorizontalPager 手势。
    val list = books
    if (list == null) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                text = stringResource(Res.string.loading),
                color = AppTheme.colors.summaryText,
                fontSize = 13.sp,
            )
        }
    } else {
        // 3D 书架按 Ui 模型绘制, 封面解密 / cbz 取图所需实体只在页面边界按 bookUrl 回查
        // 下拉刷新沿用分组开关 (enableRefresh && 有书)
        val enableRefresh = group.enableRefresh
        val refreshEnabled = enableRefresh && list.isNotEmpty()
        val refreshing = remember(list, refreshingUrls) {
            refreshingUrls.isNotEmpty() && list.any { it.bookUrl in refreshingUrls }
        }
        LanghuanShelf(
            books = list,
            modifier = Modifier.fillMaxSize(),
            coverBook = { bookEntities[it.bookUrl] },
            initialBookUrl = remember(list) {
                list.maxByOrNull { it.durChapterTime }?.bookUrl
            },
            state = shelfState,
            refreshEnabled = refreshEnabled,
            refreshing = refreshing,
            onRefresh = onRefresh,
            onOpen = { book -> onBookClick(book, null) },
            onLongPress = { book -> onBookLongClick(book, null) },
        )
    }
}

/** 无分组时的空态：安静的一行提示，不加图标与装饰。 */
@Composable
private fun BookshelfEmptyState() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(
            text = stringResource(Res.string.bookshelf_empty),
            color = AppTheme.colors.secondaryText,
            fontSize = 14.sp,
            lineHeight = 22.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = DesignTokens.spacingXl),
        )
    }
}

/**
 * 顶栏: 分组 tab (左) + 操作区 (右)。
 *
 * 对照 app 端 BookshelfTopBar + BookshelfActions: 分组用 [AppScrollTabRow]
 * 横向滚动 tab, 选中色 accent, 指示条 2dp 贴底; 选中同 tab 再点不触发滚顶
 * (app 端 onTabReselect 调 gotoTop, 此处简化)。
 *
 * @param showGroupCount 是否在 tab 标题后显示 "(n)" 数量 (数量取自 [GroupUi.bookCount], null 显示 "..")
 */
@Composable
internal fun BookshelfTopBar(
    groups: List<GroupUi>,
    currentGroupId: Long,
    showGroupCount: Boolean,
    onGroupClick: (Long) -> Unit,
    onGroupLongClick: (GroupUi) -> Unit,
) {
    if (groups.isEmpty()) return
    val colors = AppTheme.colors
    val eInk = LocalEInk.current
    val selectedIndex = groups.indexOfFirst { it.groupId == currentGroupId }.coerceAtLeast(0)
    Box(Modifier.fillMaxWidth()) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = DesignTokens.viewHeightXl),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AppScrollTabRow(
                tabCount = groups.size,
                selectedIndex = selectedIndex,
                indicatorColor = colors.accent,
                modifier = Modifier.weight(1f).padding(start = DesignTokens.spacingLg),
            ) { index ->
                val group = groups[index]
                val title = if (showGroupCount) {
                    "${group.groupName}(${group.bookCount ?: ".."})"
                } else {
                    group.groupName
                }
                GroupTab(
                    title = title,
                    selected = index == selectedIndex,
                    eInk = eInk,
                    onClick = { onGroupClick(group.groupId) },
                    onLongClick = { onGroupLongClick(group) },
                )
            }
        }
        if (eInk) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(DesignTokens.strokeHairline)
                    .background(colors.line)
                    .align(Alignment.BottomStart)
            )
        }
    }
}

/** 单个分组 tab 项 (对照 app 端 style1.GroupTab) */
@Composable
internal fun GroupTab(
    title: String,
    selected: Boolean,
    eInk: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
) {
    val colors = AppTheme.colors
    Box(
        Modifier
            .heightIn(min = DesignTokens.viewHeightXl)
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(horizontal = DesignTokens.spacingDefault),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = title,
            color = if (selected) colors.accent else colors.primaryText,
            fontSize = 14.sp,
            maxLines = 1,
        )
    }
}

// ---- 默认实现 (供宿主端未注入 slot 时使用) ----

/**
 * 默认顶栏右侧动作: 搜索图标 + 完整溢出菜单。
 *
 * 复用 shared [BookshelfActions] (对照 app 端 main_bookshelf.xml 项序):
 * 搜索图标 + 强制刷新/添加本地/远程书籍/添加网址/书架管理/分组管理/导入书架/日志。
 * 宿主端通过 [BookshelfScreen] 的 `bookshelfActionsCallbacks` 参数注入回调,
 * 或用 `actions` slot 完全覆盖。
 */
@Composable
internal fun DefaultBookshelfActions(
    onSearchClick: () -> Unit,
    callbacks: BookshelfActionsCallbacks = BookshelfActionsCallbacks(),
) {
    BookshelfActions(callbacks.copy(onOpenSearch = onSearchClick), showSearch = false)
}

/**
 * 书籍封面 (加载与渲染管线见 [SharedCoverContent])。
 *
 * 书籍特有的输入: 默认封面选图 seed = 书名 (无书名回落封面路径), 与详情/搜索/发现共用
 * [DecodedBitmapCache] 的已登记封面复用, 默认封面上叠竖排书名/作者, 挂共享元素转场端点。
 *
 * 尺寸按 [coverRatio] 选 16:9 / 3:4, 由调用方给出的那一个维度反算另一个维度 (对齐原 View 版
 * `CoverImageView.onMeasure` 按 coverRatio 自适应)。
 *
 * @param book 当前书籍
 * @param modifier 外部尺寸约束 (调用方给宽/高/内边距等); 本组件只追加比例与圆角
 * @param coverRatio 封面比例档位 (对照原版 `CoverImageView.coverRatio`)
 * @param reloadTick 封面重载信号 (configTick): 变化时重启加载, 不变不额外触发
 *
 * ohos 未注册 BookImageLoader, 恒走内置图 + overlay (与替换前占位语义一致)。
 */
@Composable
fun SharedBookCover(
    book: Book,
    modifier: Modifier = Modifier,
    coverRatio: CoverSlotRatio = CoverSlotRatio.NOVEL,
    reloadTick: Int = 0,
) {
    val cover = book.getDisplayCover()
    SharedCoverContent(
        source = CoverSource(
            coverUrl = cover,
            origin = book.origin,
            // 同 URL 不同来源是不同资源, origin 必须进 key (对照原版 ImageLoader 的 sourceOrigin)
            cacheKey = book.origin,
            defaultCoverSeed = book.name.takeIf { it.isNotBlank() } ?: cover,
            shareDecodedCover = true,
            // 非书架书 (搜索/发现/主页结果) 的封面只落临时缓存区, 不占书架持久区
            persistentCover = !book.isNotShelf,
            sharedTransition = true,
            contentDescription = book.name,
            title = book.name,
            author = book.author,
        ),
        modifier = modifier,
        coverRatio = coverRatio,
        reloadTick = reloadTick,
        nameAuthorOverlay = true,
    )
}


/**
 * 分组封面 (对照分组管理对话框与书架分组的封面渲染)。
 *
 * 加载与渲染管线与书籍封面同源 ([SharedCoverContent]); 数据差异: 封面取 [BookGroup.cover]
 * (图集内部相对引用, 经 [resolveImagePath] 解析为展示路径), 默认封面选图 seed = 组名,
 * 无书源来源 (origin 恒 null), 无共享元素转场端点。
 *
 * 原版分组封面不传 name/author, 故默认封面上无竖排书名/作者可画。
 *
 * @param reloadTick 封面重载信号 (configTick): 变化时重启加载, 不变不额外触发
 */
@Composable
fun SharedGroupCover(
    group: BookGroup,
    modifier: Modifier = Modifier,
    coverRatio: CoverSlotRatio = CoverSlotRatio.NOVEL,
    reloadTick: Int = 0,
) {
    SharedCoverContent(
        source = CoverSource(
            coverUrl = resolveImagePath(group.cover),
            origin = null,
            cacheKey = null,
            defaultCoverSeed = group.groupName,
            shareDecodedCover = false,
            persistentCover = true,
            sharedTransition = false,
            contentDescription = group.groupName,
            title = null,
            author = null,
        ),
        modifier = modifier,
        coverRatio = coverRatio,
        reloadTick = reloadTick,
        nameAuthorOverlay = false,
    )
}

/**
 * 分组封面渲染 slot 的 CompositionLocal: 默认兜底 [SharedGroupCover]。
 *
 * 与 [LocalBookCoverSlot] 对称, 宿主端可用 `CompositionLocalProvider` 覆盖注入平台实现。
 */
val LocalGroupCoverSlot =
    staticCompositionLocalOf<@Composable (BookGroup, Modifier, CoverSlotRatio, Int) -> Unit> {
        @Composable { group, modifier, coverRatio, tick ->
            SharedGroupCover(group, modifier, coverRatio, tick)
        }
    }

/**
 * 封面渲染 slot 的 CompositionLocal: 默认兜底 [SharedBookCover]。
 *
 * 宿主端可用 [CompositionLocalProvider] 覆盖注入, 替换 shared 路由
 * ([BookshelfScreen] / `BookInfoRoute`) 的封面实现; 各端默认统一走 [SharedBookCover]。
 *
 * 签名 `(Book, Modifier, CoverSlotRatio, Int) -> Unit` 对齐条目层的 `coverSlot`
 * (book / modifier / 比例档位 / 重载信号), modifier 与比例档位不被丢弃。
 */
val LocalBookCoverSlot =
    staticCompositionLocalOf<@Composable (Book, Modifier, CoverSlotRatio, Int) -> Unit> {
        @Composable { book, modifier, coverRatio, tick ->
            SharedBookCover(book, modifier, coverRatio, tick)
        }
}

/**
 * SearchBook → Book 适配 [LocalBookCoverSlot]: 非书架书补 notShelf 标记, 宿主端据此把封面
 * 落临时缓存区而非书架持久区 (对照原版 `BaseExploreShowAdapter.registerListener` 在 bind 时
 * `addType(notShelf)` + `ImageLoader.load(.., inBookshelf)` 的分流)。
 */
fun SearchBook.toCoverBook(inBookshelf: Boolean = false): Book = toBook().apply {
    if (!inBookshelf) addType(BookType.notShelf)
}

/**
 * 书架活跃封面资源集合：全部分组书籍 + 分组封面（3D 书架各分组页与分组管理共用）。
 * 持有者清理由此收敛: 书架数据增删即清理对应资源比例, 下钻/翻页等未减结果集的变化全保留。
 */
internal fun shelfActiveCoverResources(
    groups: List<GroupUi>,
    booksByGroup: Map<Long, List<BookItemUi>>,
): Set<CoverResourceKey> = buildSet {
    groups.forEach { add(it.coverResourceKey()) }
    booksByGroup.values.forEach { books ->
        books.forEach { add(it.coverResourceKey()) }
    }
}

/** 展示封面 (同 Book.getDisplayCover 语义: 自定义封面优先, 图集相对引用解析为绝对路径) */
private fun BookItemUi.displayCover(): String? =
    resolveImagePath(customCoverUrl.takeUnless { it.isNullOrEmpty() } ?: coverUrl)

/** 条目 → 资源身份, 与封面渲染收到的字段同口径 ([SharedBookCover] / [SharedGroupCover]) */
private fun BookItemUi.coverResourceKey(): CoverResourceKey =
    CoverResourceKey(displayCover(), origin, persistentCover = type and BookType.notShelf == 0)

private fun GroupUi.coverResourceKey(): CoverResourceKey =
    CoverResourceKey(resolveImagePath(cover), null, true)
