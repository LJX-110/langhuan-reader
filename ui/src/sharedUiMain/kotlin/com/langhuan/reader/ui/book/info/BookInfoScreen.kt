package com.langhuan.reader.ui.book.info

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsBottomHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.foundation.text.selection.DisableSelection
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.DropdownMenuItem
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.fleeksoft.ksoup.Ksoup
import com.fleeksoft.ksoup.nodes.Element
import com.fleeksoft.ksoup.nodes.TextNode
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.help.book.isVideo
import com.langhuan.reader.help.book.isWebFile
import com.langhuan.reader.ui.compose.component.AppDropdownMenu
import com.langhuan.reader.ui.compose.component.AppFilletTextButton
import com.langhuan.reader.ui.compose.component.AppMenuCheckbox
import com.langhuan.reader.ui.compose.component.AppOutlinedButton
import com.langhuan.reader.ui.compose.component.AppSolidButton
import com.langhuan.reader.ui.compose.component.listItemFocus
import com.langhuan.reader.ui.compose.component.PullToRefreshDefaults
import com.langhuan.reader.ui.compose.component.filletChipPaddingH
import com.langhuan.reader.ui.compose.component.filletChipPaddingV
import com.langhuan.reader.ui.compose.component.pullToRefresh
import com.langhuan.reader.ui.compose.component.rememberPullToRefreshState
import com.langhuan.reader.ui.compose.platform.rememberString
import com.langhuan.reader.ui.compose.platform.platformStatusBarHeight
import com.langhuan.reader.ui.compose.platform.platformStatusBarPadding
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.compose.theme.LanghuanType
import com.langhuan.reader.ui.compose.theme.LocalEInk
import com.langhuan.reader.utils.splitNotBlank
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.allow_update
import com.langhuan.reader.ui.generated.resources.author
import com.langhuan.reader.ui.generated.resources.book_info
import com.langhuan.reader.ui.generated.resources.book_intro
import com.langhuan.reader.ui.generated.resources.book_name
import com.langhuan.reader.ui.generated.resources.book_source
import com.langhuan.reader.ui.generated.resources.book_tags
import com.langhuan.reader.ui.generated.resources.chapter_list
import com.langhuan.reader.ui.generated.resources.group
import com.langhuan.reader.ui.generated.resources.clear_cache
import com.langhuan.reader.ui.generated.resources.collapse
import com.langhuan.reader.ui.generated.resources.copy_book_url
import com.langhuan.reader.ui.generated.resources.copy_toc_url
import com.langhuan.reader.ui.generated.resources.download_to_local
import com.langhuan.reader.ui.generated.resources.edit
import com.langhuan.reader.ui.generated.resources.empty
import com.langhuan.reader.ui.generated.resources.expand
import com.langhuan.reader.ui.generated.resources.ic_arrow_back
import com.langhuan.reader.ui.generated.resources.ic_arrow_right
import com.langhuan.reader.ui.generated.resources.ic_book_last
import com.langhuan.reader.ui.generated.resources.ic_edit
import com.langhuan.reader.ui.generated.resources.ic_more_vert
import com.langhuan.reader.ui.generated.resources.ic_share
import com.langhuan.reader.ui.generated.resources.loading
import com.langhuan.reader.ui.generated.resources.log
import com.langhuan.reader.ui.generated.resources.login
import com.langhuan.reader.ui.generated.resources.more_menu
import com.langhuan.reader.ui.generated.resources.other
import com.langhuan.reader.ui.generated.resources.read_dur_progress
import com.langhuan.reader.ui.generated.resources.reading
import com.langhuan.reader.ui.generated.resources.refresh
import com.langhuan.reader.ui.generated.resources.review
import com.langhuan.reader.ui.generated.resources.set_book_variable
import com.langhuan.reader.ui.generated.resources.set_source_variable
import com.langhuan.reader.ui.generated.resources.share
import com.langhuan.reader.ui.generated.resources.split_long_chapter
import com.langhuan.reader.ui.generated.resources.to_top
import com.langhuan.reader.ui.generated.resources.upload_to_remote
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringResource

/*
 * 下沉所需资源 key 清单 (供 ResourceProvider 各平台 actual 补全)
 *
 * Painter key (drawable):
 *   - ic_arrow_back     (返回箭头)
 *   - ic_edit           (编辑)
 *   - ic_share          (分享)
 *   - ic_more_vert      (更多菜单, 已存在)
 *   - ic_book_last      (最新章节图标, 已存在)
 *   - ic_web_outline    (来源图标)
 *   - ic_groups         (分组图标)
 *   - ic_folder_open    (目录图标)
 *   - ic_author         (作者图标, 已存在)
 *
 * String key (string):
 *   - book_info / edit / share / more_menu (已存在) / bg_image
 *   - upload_to_remote / download_to_local / to_top / login / review
 *   - set_source_variable / set_book_variable / copy_book_url / copy_toc_url
 *   - allow_update / split_long_chapter (已存在) / clear_cache / log (已存在)
 *   - book_name / author / loading / read_dur_progress / other / book_intro
 *   - remove_from_bookshelf / add_to_bookshelf / reading
 *
 * Color key (color):
 *   - primaryText (已存在) / secondaryText (已存在) / tv_text_summary (已存在)
 *   - btn_bg (已存在) / arco_fill_3 / bottomBackground
 *   (注: bottomBackground 已通过 AppTheme.colors.bottomBackground 暴露, 不需要 rememberColor)
 *
 * L3 不可下沉项 (保留 app 端, 通过 slot 注入):
 *   - BlurCoverBg: 位图管线模糊 (StackBlur), 压暗与渐变蒙版绘制期叠加, Compose Image 渲染
 *     → blurCoverBgSlot: @Composable (Modifier) -> Unit
 *   - InfoCover 中的封面渲染 (原 app 端 ShelfCover)
 *     → coverSlot: @Composable (Book?, Modifier) -> Unit (现默认 SharedBookCover)
 *   - IntroImage: Glide + asBitmap + CustomTarget<Bitmap>
 *     → introImageSlot: @Composable (src: String, onClick: () -> Unit) -> Unit
 */

/**
 * 书籍详情页展示状态。
 *
 * app 端 [BookInfoActivity] 在 `Content()` 内将自己的 `var` 状态字段打包为本数据类传入;
 * 桌面端/iOS 端可同样构造本类复用 [BookInfoScreen]。
 *
 * 字段语义对照原 `BookInfoActivity` 同名字段:
 * - [book] / [bookTick] / [coverTick] / [inBookshelf] / [groupName] /
 *   [tocText] / [lastedTitle] / [wordCountText]: 与 Activity 同名字段一一对应
 * - [refreshing]: 刷新中标志, 只驱动下拉指示器。**非**原版 upLoading 的等价物 ——
 *   原版 `upLoading(true)` 只改 `tvToc` 文案 (archive BookInfoActivity:523-535),
 *   下拉指示器在 `setOnRefreshListener` 开头就 `isRefreshing = false` (:616-619), 从不表达刷新中
 * - [isLandscape] / [isDarkTheme] / [isEInkMode]: 由路由层计算后传入
 *   (isEInkMode 时模糊封面背景与取色均跳过, 回退主题文字色)
 * - [menuState]: 溢出菜单显隐控制状态 (对照原 onMenuOpened 内联求值)
 */
data class BookInfoUiState(
    val book: Book?,
    val bookTick: Int,
    val coverTick: Int,
    /** 正在刷新 (下拉/菜单/F5/事件触发): 只驱动指示器, 不清已有文案 (与"未加载完"分开) */
    val refreshing: Boolean,
    val inBookshelf: Boolean,
    val groupName: String,
    val tocText: String?,
    val lastedTitle: String,
    val wordCountText: String?,
    val isLandscape: Boolean,
    val isDarkTheme: Boolean,
    val isEInkMode: Boolean = false,
    val menuState: BookInfoMenuState,
)

/** 溢出菜单项显隐控制 (对照原 onMenuOpened 内联求值的可见性条件) */
data class BookInfoMenuState(
    val isLocal: Boolean,              // book?.origin == BookType.localTag
    val isWebDav: Boolean,             // book?.origin?.startsWith(BookType.webDavTag)
    val hasSource: Boolean,            // vm.curBookSource != null
    val sourceHasLogin: Boolean,       // vm.curBookSource?.hasLogin() == true
    val sourceHasReviewRule: Boolean,  // vm.curBookSource?.reviewRule?.reviewUrl 非空
    val canUpdate: Boolean,            // book?.canUpdate ?: true
    val isLocalTxt: Boolean,           // book?.isLocalTxt == true
    val splitLongChapter: Boolean,     // book?.config.splitLongChapter
    val bookUrl: String?,              // book?.bookUrl (用于复制)
    val tocUrl: String?,               // book?.tocUrl  (用于复制)
)

/**
 * 书籍详情页用户交互回调。
 *
 * app 端 [BookInfoActivity] 实现本接口 (已有同名方法直接 `override`);
 * 桌面端/iOS 端可自行实现本接口接入各自平台行为。
 *
 * 设计:返回式回调,无 Android Context 依赖。所有需要 Android 专属 API 的动作
 * (如 [onShowLog] 调 showDialogFragment、[onCopyBookUrl] 调 sendToClip)
 * 由 app 端实现内部桥接到 Activity。
 */
interface BookInfoUiActions {
    fun onBack()
    fun onEdit()
    fun onShare()
    fun onRefresh()
    fun onUploadBook()
    fun onDownloadToLocal()
    fun onTopBook()
    fun onLogin()
    fun onOpenCommentDialog()
    fun onSetSourceVariable()
    fun onSetBookVariable()
    fun onCopyBookUrl()
    fun onCopyTocUrl()
    fun onToggleCanUpdate()
    fun onToggleSplitLongChapter()
    fun onClearCache()
    fun onShowLog()
    fun onNameClick()
    fun onCoverClick()
    fun onCoverLongClick()
    fun onOriginClick()
    fun onOriginLongClick()
    fun onTocClick()
    fun onGroupClick()
    fun onShelfClick()
    fun onReadClick()
    /** 作者搜索 (submit=false 表示长按探索) */
    fun onSearchAuthor(author: String, submit: Boolean)
    /** 分类标签搜索 (submit=false 表示长按探索) */
    fun onSearchKind(kind: String, submit: Boolean)
    /** 简介内 <button onclick="..."> 动作派发 */
    fun onDispatchIntroAction(action: String)
    /** 简介内 <img src="..."> 点击查看大图 */
    fun onShowPhoto(src: String)
}

/**
 * [BookInfoUiActions] 的 CompositionLocal, 供深层 Composable (HeroNameText/InfoCover)
 * 直接取用, 避免层层透传 actions 参数。
 *
 * 由 [BookInfoScreen] 顶层 provides, 子树所有 Composable 可通过
 * [LocalBookInfoActions.current] 取到 actions 实例。
 */
val LocalBookInfoActions = compositionLocalOf<BookInfoUiActions> {
    error("BookInfoUiActions not provided, wrap content in BookInfoScreen")
}

/**
 * 书籍详情页(对照 activity_book_info.xml / layout-land 变体)：
 * 竖屏=白底编辑式档案头 + 标题分节，横屏=左封面/右内容的左右分栏。
 *
 * 下沉自 app 端原 `BookInfoScreen(activity: BookInfoActivity)`，将 `BookInfoActivity`
 * 直接依赖拆为 [state] (展示状态) + [actions] (交互回调) + 三个 slot (Android 专属
 * Glide/AndroidView 注入)，去除 Android `Context` / `AppConfig` / `activity` 依赖。
 *
 * 视觉/布局/动画/手势/状态管理完全与 app 端原版一致 (宽高/边距/颜色/层级)。
 *
 * @param blurCoverBgSlot 模糊封面背景 (位图模糊 + 绘制期压暗/渐变蒙版, L3)
 *   - 调用方传入 modifier 已经包含尺寸约束 (fillMaxSize / fillMaxWidth+height(300.dp))
 *   - slot 内部自行从 state 读 coverTick/book/isEInkMode 等判断是否加载
 * @param coverSlot 书籍封面 (默认 SharedBookCover)
 *   - 调用方传入的 modifier 已包含 height(144.dp)/clip/background/clickable
 *   - slot 内部自行从 state 读 coverTick/inBookshelf 等
 * @param introImageSlot 简介内整宽图 (Glide + CustomTarget<Bitmap>, L3)
 *   - 调用方只传 src 和点击回调, slot 内部自行处理加载与渲染
 * @param onBlurCoverPaintedChange 模糊封面背景是否已绘制: 由本页面按 slot 的绘制事实上报,
 *   路由层据此定页顶状态栏图标明暗
 */
@Composable
fun BookInfoScreen(
    state: BookInfoUiState,
    actions: BookInfoUiActions,
    blurCoverBgSlot: @Composable (Modifier, Boolean) -> Unit,
    coverSlot: @Composable (Book?, Modifier) -> Unit,
    introImageSlot: @Composable (String, () -> Unit) -> Unit,
    /**
     * 模糊封面背景是否已绘制。页面按它定状态栏图标明暗 (原版该分支页顶是深色封面背景,
     * 图标必须用浅色), 故由路由层据本回调下发给窗口。
     */
    onBlurCoverPaintedChange: (Boolean) -> Unit,
) {
    // 注: 本层不读 tick —— 本函数是否重组由调用方对 [state] 参数的比较决定, 体内再读一次
    // tick 无法反向影响该比较 (旧实现的 `state.bookTick` 顶读是死代码, 已删);
    // book 原地可变时的强制重组靠 tick 进入 [BookInfoUiState] 使新旧不等

    // 取色来自平台 slot 上报的已加载封面位图 (共用同一次加载, 不另发请求, 见 [LocalCoverLoaded]):
    // 换书或切横竖时先清空采样, 避免沿用上一份结论。
    // E-Ink 与竖向分支下 slot 不加载封面, 回调不会触发, 采样自然为空
    val cover = state.book?.getDisplayCover()
    var coverRegions by remember(cover, state.isLandscape) { mutableStateOf<CoverRegions?>(null) }
    val onCoverLoaded: (ImageBitmap) -> Unit = remember(state.isLandscape) {
        { loaded -> coverRegions = sampleCoverRegions(loaded, state.isLandscape) }
    }
    // 模糊背景是否已绘制: 宿主与平台 slot 共用同一份可变状态, 由 slot 按自身绘制条件在组合期写回。
    // 键含“由哪个分支承载模糊背景”: 切竖/横屏与主题模式时模糊背景会重新测量重载, 重画出来之前
    // 不得沿用上一分支的结论。
    val blurPainted = remember(
        cover,
        state.isLandscape,
        state.isEInkMode,
    ) { mutableStateOf(false) }
    val blurredCoverPainted = blurPainted.value
    LaunchedEffect(blurredCoverPainted) { onBlurCoverPaintedChange(blurredCoverPainted) }
    // 取色产物只在模糊背景确实画出后才对外提供: 未画出时头部文字压的是页面底色, 封面取色不适用
    val palette = if (blurredCoverPainted) {
        deriveBookCoverPalette(coverRegions, AppTheme.colors.background, state.isLandscape)
    } else {
        null
    }
    // 对齐原版 applyDevFeatLayout: 模糊封面背景可见时顶栏取亮色文字 (取到色则按色), 否则随主题
    val titleColor = when {
        blurredCoverPainted -> palette?.topBarFg ?: Color.White
        else -> AppTheme.colors.primaryText
    }
    CompositionLocalProvider(
        LocalBookInfoActions provides actions,
        LocalBookCoverPalette provides palette,
        LocalBlurCoverPainted provides blurPainted,
        LocalCoverLoaded provides onCoverLoaded,
    ) {
        if (state.isLandscape) {
            LandscapeLayout(
                state, actions, titleColor,
                blurCoverBgSlot, coverSlot, introImageSlot,
            )
        } else {
            PortraitLayout(
                state, actions, titleColor,
                blurCoverBgSlot, coverSlot, introImageSlot,
            )
        }
    }
}

@Composable
private fun PortraitLayout(
    state: BookInfoUiState,
    actions: BookInfoUiActions,
    titleColor: Color,
    blurCoverBgSlot: @Composable (Modifier, Boolean) -> Unit,
    coverSlot: @Composable (Book?, Modifier) -> Unit,
    introImageSlot: @Composable (String, () -> Unit) -> Unit,
) {
    val pullState = rememberPullToRefreshState()
    val isRefreshing = state.refreshing
    val hasKinds = state.hasKinds()
    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier
                .fillMaxSize()
                .pullToRefresh(
                    isRefreshing = isRefreshing,
                    state = pullState,
                    onRefresh = { actions.onRefresh() },
                ),
        ) {
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
            ) {
                // 顶栏悬浮在内容之上: 内容顶部留出状态栏 + 标题栏高度
                Spacer(Modifier.height(platformStatusBarHeight() + DesignTokens.viewHeightMax))
                EditorialHero(state, coverSlot)
                SectionHeader(
                    label = stringResource(Res.string.book_intro),
                    modifier = Modifier.padding(horizontal = DesignTokens.spacingLg),
                )
                IntroSection(
                    state, actions, introImageSlot,
                    Modifier.padding(
                        start = DesignTokens.spacingLg,
                        end = DesignTokens.spacingLg,
                        bottom = DesignTokens.spacingDefault,
                    ),
                )
                if (hasKinds) {
                    SectionHeader(
                        label = stringResource(Res.string.book_tags),
                        modifier = Modifier.padding(horizontal = DesignTokens.spacingLg),
                    )
                    KindsSection(
                        state, actions,
                        Modifier.padding(horizontal = DesignTokens.spacingLg),
                    )
                }
                SectionHeader(
                    label = stringResource(Res.string.book_info),
                    modifier = Modifier.padding(horizontal = DesignTokens.spacingLg),
                )
                InfoTable(
                    state, actions,
                    Modifier.padding(horizontal = DesignTokens.spacingLg),
                )
                // 底部按钮悬浮，滚动内容留出等高空间
                Spacer(Modifier.height(88.dp))
                Spacer(Modifier.windowInsetsBottomHeight(WindowInsets.navigationBars))
            }
            PullToRefreshDefaults.Indicator(
                state = pullState,
                isRefreshing = isRefreshing,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = platformStatusBarHeight() + DesignTokens.viewHeightMax),
                color = AppTheme.colors.accent,
            )
        }
        InfoTitleBar(state, actions, titleColor, Modifier.align(Alignment.TopCenter), solid = true)
        BottomButtons(state, actions, Modifier.align(Alignment.BottomCenter))
    }
}

@Composable
private fun LandscapeLayout(
    state: BookInfoUiState,
    actions: BookInfoUiActions,
    titleColor: Color,
    blurCoverBgSlot: @Composable (Modifier, Boolean) -> Unit,
    coverSlot: @Composable (Book?, Modifier) -> Unit,
    introImageSlot: @Composable (String, () -> Unit) -> Unit,
) {
    Row(Modifier.fillMaxSize()) {
        // 左半: 模糊封面 + 标题栏 + 居中书封/书名, 保留沉浸感
        Box(
            Modifier
                .weight(1f)
                .fillMaxHeight(),
        ) {
            blurCoverBgSlot(Modifier.matchParentSize(), true)
            Column(Modifier.fillMaxSize()) {
                InfoTitleBar(state, actions, titleColor, Modifier)
                Column(
                    Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.Center,
                ) {
                    LandscapeHero(state, coverSlot)
                }
            }
        }
        // 右半: 下拉刷新 + 简介/标签/信息 + 底部按钮
        val pullState = rememberPullToRefreshState()
        val isRefreshing = state.refreshing
        val hasKinds = state.hasKinds()
        Box(
            Modifier
                .weight(1f)
                .fillMaxHeight(),
        ) {
            Box(
                Modifier
                    .fillMaxSize()
                    .pullToRefresh(
                        isRefreshing = isRefreshing,
                        state = pullState,
                        onRefresh = { actions.onRefresh() },
                    ),
            ) {
                Column(
                    Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = DesignTokens.spacingLg),
                ) {
                    Spacer(Modifier.height(platformStatusBarHeight()))
                    SectionHeader(stringResource(Res.string.book_intro))
                    IntroSection(state, actions, introImageSlot, Modifier.padding(bottom = DesignTokens.spacingDefault))
                    if (hasKinds) {
                        SectionHeader(stringResource(Res.string.book_tags))
                        KindsSection(state, actions)
                    }
                    SectionHeader(stringResource(Res.string.book_info))
                    InfoTable(state, actions)
                    Spacer(Modifier.height(88.dp))
                    Spacer(Modifier.windowInsetsBottomHeight(WindowInsets.navigationBars))
                }
                PullToRefreshDefaults.Indicator(
                    state = pullState,
                    isRefreshing = isRefreshing,
                    modifier = Modifier.align(Alignment.TopCenter),
                    color = AppTheme.colors.accent,
                )
            }
            BottomButtons(state, actions, Modifier.align(Alignment.BottomCenter))
        }
    }
}

/** 细分隔线：编辑式排版的分层线，颜色走主题描边色。 */
@Composable
private fun HairlineDivider(modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxWidth()
            .height(DesignTokens.strokeHairline)
            .background(AppTheme.colors.line)
    )
}

/**
 * 编辑式分节头: 上方一道细线, 下方只留衬线标题。
 *
 * 不加编号、不加背景块, 层级靠留白、字重与细线。
 */
@Composable
private fun SectionHeader(
    label: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier
            .fillMaxWidth()
            .padding(top = DesignTokens.spacingMax),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(DesignTokens.strokeHairline)
                .background(AppTheme.colors.line)
        )
        Text(
            text = label,
            style = LanghuanType.sectionTitle,
            color = AppTheme.colors.primaryText,
            modifier = Modifier.padding(top = DesignTokens.spacingMd, bottom = DesignTokens.spacingXs),
        )
    }
}

// ---- 标题栏(透明背景悬浮，menu 对照 R.menu.book_info) ----

@Composable
private fun InfoTitleBar(
    state: BookInfoUiState,
    actions: BookInfoUiActions,
    contentColor: Color,
    modifier: Modifier,
    solid: Boolean = false,
) {
    Column(
        modifier
            .fillMaxWidth()
            .background(if (solid) AppTheme.colors.background else Color.Transparent)
            .platformStatusBarPadding(),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .height(DesignTokens.viewHeightMax),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = { actions.onBack() }) {
                Icon(painterResource(Res.drawable.ic_arrow_back), null, tint = contentColor)
            }
            Text(
                text = stringResource(Res.string.book_info),
                color = contentColor,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            if (state.inBookshelf) {
                IconButton(onClick = { actions.onEdit() }) {
                    Icon(
                        painterResource(Res.drawable.ic_edit),
                        stringResource(Res.string.edit),
                        tint = contentColor,
                    )
                }
            }
            IconButton(onClick = { actions.onShare() }) {
                Icon(
                    painterResource(Res.drawable.ic_share),
                    stringResource(Res.string.share),
                    tint = contentColor,
                )
            }
            InfoOverflowMenu(state, actions, contentColor)
        }
        if (solid) {
            HairlineDivider(Modifier.padding(horizontal = DesignTokens.spacingLg))
        }
    }
}

@Composable
private fun InfoOverflowMenu(
    state: BookInfoUiState,
    actions: BookInfoUiActions,
    tint: Color,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { expanded = true }) {
            Icon(
                painterResource(Res.drawable.ic_more_vert),
                stringResource(Res.string.more_menu),
                tint = tint,
            )
        }
        AppDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            // 展开时求值可见性,对照 onMenuOpened
            val menu = state.menuState
            val dismiss = { expanded = false }
            // 刷新: 等价下拉刷新 (onRefresh), 无下拉手势的端 (如桌面) 走此入口
            MenuItem(stringResource(Res.string.refresh)) { dismiss(); actions.onRefresh() }
            MenuItem(stringResource(Res.string.to_top)) { dismiss(); actions.onTopBook() }
            if (menu.isLocal || menu.isWebDav) {
                MenuDivider()
            }
            if (menu.isLocal) {
                MenuItem(stringResource(Res.string.upload_to_remote)) {
                    dismiss(); actions.onUploadBook()
                }
            }
            if (menu.isWebDav) {
                MenuItem(stringResource(Res.string.download_to_local)) {
                    dismiss(); actions.onDownloadToLocal()
                }
            }
            if (menu.sourceHasLogin || menu.sourceHasReviewRule || menu.hasSource) {
                MenuDivider()
            }
            if (menu.sourceHasLogin) {
                MenuItem(stringResource(Res.string.login)) { dismiss(); actions.onLogin() }
            }
            if (menu.sourceHasReviewRule) {
                MenuItem(stringResource(Res.string.review)) {
                    dismiss(); actions.onOpenCommentDialog()
                }
            }
            if (menu.hasSource) {
                MenuItem(stringResource(Res.string.set_source_variable)) {
                    dismiss(); actions.onSetSourceVariable()
                }
                MenuItem(stringResource(Res.string.set_book_variable)) {
                    dismiss(); actions.onSetBookVariable()
                }
            }
            if (menu.hasSource) {
                CheckMenuItem(stringResource(Res.string.allow_update), menu.canUpdate) {
                    dismiss(); actions.onToggleCanUpdate()
                }
            }
            MenuDivider()
            MenuItem(stringResource(Res.string.copy_book_url)) {
                dismiss(); menu.bookUrl?.let { actions.onCopyBookUrl() }
            }
            MenuItem(stringResource(Res.string.copy_toc_url)) {
                dismiss(); menu.tocUrl?.let { actions.onCopyTocUrl() }
            }
            if (menu.isLocalTxt) {
                MenuDivider()
                CheckMenuItem(
                    stringResource(Res.string.split_long_chapter),
                    menu.splitLongChapter,
                ) {
                    dismiss(); actions.onToggleSplitLongChapter()
                }
            }
            MenuDivider()
            MenuItem(stringResource(Res.string.clear_cache)) { dismiss(); actions.onClearCache() }
            MenuItem(stringResource(Res.string.log)) {
                dismiss(); actions.onShowLog()
            }
        }
    }
}

/** 菜单分组线：把同步 / 书源 / 复制 / 调试几类动作分开，避免 14 项连成一片。 */
@Composable
private fun MenuDivider() {
    Box(
        Modifier
            .fillMaxWidth()
            .padding(vertical = DesignTokens.spacingXs)
            .height(DesignTokens.strokeHairline)
            .background(AppTheme.colors.line)
    )
}

@Composable
private fun MenuItem(text: String, onClick: () -> Unit) {
    DropdownMenuItem(
        onClick = onClick,
    ) {
        Text(text, color = AppTheme.colors.primaryText)
    }
}

@Composable
private fun CheckMenuItem(text: String, checked: Boolean, onClick: () -> Unit) {
    val colors = AppTheme.colors
    DropdownMenuItem(
        onClick = onClick,
    ) {
        Text(text, color = colors.primaryText)
        Spacer(Modifier.width(DesignTokens.spacingMd))
        AppMenuCheckbox(checked = checked)
    }
}

/** 没有分类时不画「标签」空节。 */
private fun BookInfoUiState.hasKinds(): Boolean = !book?.kind.isNullOrBlank()

// ---- 头部(封面 + 书名 + 作者/字数/最新章) ----

/**
 * 编辑式头部: 封面在左、文字在右，标题用衬线大字，作者/字数/最近更新三行小字。
 *
 * 不再把封面居中放在 300dp 模糊图上: 白底留白让书名成为页面唯一重心，
 * 封面只作为档案卡的一枚缩略图。
 */
@Composable
private fun EditorialHero(
    state: BookInfoUiState,
    coverSlot: @Composable (Book?, Modifier) -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = DesignTokens.spacingLg, vertical = DesignTokens.spacingLg),
        verticalAlignment = Alignment.Top,
    ) {
        InfoCover(state, coverSlot, Modifier, width = 96.dp)
        Spacer(Modifier.width(DesignTokens.spacingLg))
        Column(Modifier.weight(1f)) {
            HeroNameText(state, TextAlign.Start, 3)
            Spacer(Modifier.height(4.dp))
            AuthorName(state)
            Spacer(Modifier.height(8.dp))
            WordCountText(state, TextAlign.Start)
            LastedRow(state, Modifier.padding(top = 4.dp))
        }
    }
}

/** 横屏左栏: 模糊封面上的居中档案卡，保留封面取色。 */
@Composable
private fun LandscapeHero(
    state: BookInfoUiState,
    coverSlot: @Composable (Book?, Modifier) -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = DesignTokens.spacingLg),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        InfoCover(state, coverSlot, Modifier, width = 124.dp)
        Spacer(Modifier.height(DesignTokens.spacingDefault))
        HeroNameText(state, TextAlign.Center, 3)
        Spacer(Modifier.height(4.dp))
        AuthorName(state)
        Spacer(Modifier.height(6.dp))
        WordCountText(state, TextAlign.Center)
        LastedRow(state, Modifier.padding(top = 4.dp))
    }
}

@Composable
private fun HeroNameText(state: BookInfoUiState, align: TextAlign, maxLines: Int) {
    val actions = LocalBookInfoActions.current
    Text(
        text = state.book?.name ?: stringResource(Res.string.book_name),
        // 横屏封面取色生效时按共享亮暗判定映射 primaryText 昼夜对, 竖屏白底直接走主题
        color = LocalBookCoverPalette.current?.nameFg ?: AppTheme.colors.primaryText,
        style = LanghuanType.pageTitle.copy(
            fontSize = 26.sp,
            lineHeight = 33.sp,
            letterSpacing = 0.5.sp,
        ),
        textAlign = align,
        maxLines = maxLines,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { actions.onNameClick() },
    )
}

/**
 * 作者行: 单人点按直接搜索，多作者弹选择菜单，长按进入探索。
 *
 * 原四列动作格被信息表取代后，作者搜索仍需保留入口，所以收在这里。
 */
@Composable
private fun AuthorName(state: BookInfoUiState) {
    val actions = LocalBookInfoActions.current
    var authorMenu by remember { mutableStateOf<List<String>>(emptyList()) }
    val author = state.book?.getRealAuthor()?.takeIf { it.isNotBlank() }
    Box {
        Text(
            text = author?.lines()?.joinToString(" / ") ?: stringResource(Res.string.author),
            color = LocalBookCoverPalette.current?.nameFg ?: AppTheme.colors.secondaryText,
            fontSize = 13.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .clip(DesignTokens.shapeSm)
                .combinedClickable(
                    onClick = {
                        val authors = state.book?.author?.splitNotBlank("\n") ?: return@combinedClickable
                        when {
                            authors.isEmpty() -> Unit
                            authors.size == 1 -> actions.onSearchAuthor(authors[0], true)
                            else -> authorMenu = authors.toList()
                        }
                    },
                    onLongClick = {
                        state.book?.getRealAuthor()?.let { actions.onSearchAuthor(it, false) }
                    },
                )
                .padding(vertical = 2.dp),
        )
        AppDropdownMenu(
            expanded = authorMenu.isNotEmpty(),
            onDismissRequest = { authorMenu = emptyList() },
        ) {
            authorMenu.forEach { author ->
                MenuItem(author.split("::")[0]) {
                    authorMenu = emptyList()
                    actions.onSearchAuthor(author, true)
                }
            }
        }
    }
}

@Composable
private fun WordCountText(state: BookInfoUiState, align: TextAlign) {
    val text = state.wordCountText ?: return
    Text(
        text = text,
        color = LocalBookCoverPalette.current?.wordCountFg ?: AppTheme.colors.secondaryText,
        style = LanghuanType.meta,
        textAlign = align,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun LastedRow(state: BookInfoUiState, modifier: Modifier) {
    val iconSize = with(LocalDensity.current) { 16.sp.toDp() }
    // summaryText 跟随主题语义色, 不再写死固定灰
    val summaryColor = LocalBookCoverPalette.current?.lastedFg
        ?: AppTheme.colors.summaryText
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Icon(
            painterResource(Res.drawable.ic_book_last),
            stringResource(Res.string.read_dur_progress),
            tint = summaryColor,
            modifier = Modifier
                .size(iconSize)
                .padding(end = 3.dp),
        )
        Text(
            text = state.lastedTitle,
            color = summaryColor,
            fontSize = 12.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun InfoCover(
    state: BookInfoUiState,
    coverSlot: @Composable (Book?, Modifier) -> Unit,
    modifier: Modifier,
    width: Dp = 96.dp,
) {
    val actions = LocalBookInfoActions.current
    val book = state.book
    // 固定宽、按比例反推高 (视频 16:9, 小说 3:4); 档案卡不随屏宽膨胀
    val coverRatio = if (book?.isVideo == true) 16f / 9f else 3f / 4f
    // 封面按压: 轻微回缩替代水波纹, 与实色按钮的按压语义一致
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val pressScale by animateFloatAsState(
        targetValue = if (!LocalEInk.current && pressed) 0.97f else 1f,
        animationSpec = tween(durationMillis = 120),
        label = "bookInfoCoverPress",
    )
    // align/padding 留在父节点: 共享端点由 SharedBookCover 统一挂在它收到的链首,
    // 与封面同一 LayoutNode 的 padding 会被算进共享元素的起止盒
    Box(modifier) {
        coverSlot(
            book,
            Modifier
                .width(width)
                .aspectRatio(coverRatio)
                .graphicsLayer {
                    scaleX = pressScale
                    scaleY = pressScale
                }
                .clip(DesignTokens.shapeSm)
                .border(DesignTokens.strokeHairline, AppTheme.colors.line, DesignTokens.shapeSm)
                .listItemFocus()
                .combinedClickable(
                    interactionSource = interaction,
                    indication = null,
                    onClick = { actions.onCoverClick() },
                    onLongClick = { actions.onCoverLongClick() },
                )
        )
    }
}

// ---- 书籍信息表(书源/分组/目录) ----

@Composable
private fun InfoTable(
    state: BookInfoUiState,
    actions: BookInfoUiActions,
    modifier: Modifier = Modifier,
) {
    val book = state.book
    val emptyText = stringResource(Res.string.empty)
    Column(modifier.fillMaxWidth()) {
        InfoRow(
            label = stringResource(Res.string.book_source),
            value = book?.originName?.takeIf { it.isNotBlank() } ?: emptyText,
            onClick = { actions.onOriginClick() },
            onLongClick = { actions.onOriginLongClick() },
        )
        HairlineDivider()
        InfoRow(
            label = stringResource(Res.string.group),
            value = state.groupName.takeIf { it.isNotBlank() } ?: emptyText,
            onClick = { actions.onGroupClick() },
        )
        if (book?.isWebFile != true) {
            HairlineDivider()
            InfoRow(
                label = stringResource(Res.string.chapter_list),
                value = state.tocText ?: stringResource(Res.string.loading),
                onClick = { actions.onTocClick() },
            )
        }
    }
}

/** 信息行: 标签定宽、值占满剩余宽度，右侧小箭头提示可点。 */
@Composable
private fun InfoRow(
    label: String,
    value: String,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
) {
    val colors = AppTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = colors.summaryText,
            style = LanghuanType.meta,
            modifier = Modifier.width(56.dp),
        )
        Text(
            text = value,
            color = colors.primaryText,
            fontSize = 13.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Icon(
            painter = painterResource(Res.drawable.ic_arrow_right),
            contentDescription = null,
            tint = colors.summaryText,
            modifier = Modifier.size(14.dp),
        )
    }
}

// ---- 分类标签(对照 bindKinds: 组名前缀 + FlexboxLayout 换行) ----

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun KindsSection(
    state: BookInfoUiState,
    actions: BookInfoUiActions,
    modifier: Modifier = Modifier,
) {
    val otherLabel = stringResource(Res.string.other)
    val groups = remember(state.bookTick) {
        buildKindGroups(state.book?.kind, otherLabel)
    }
    if (groups.isEmpty()) return
    Column(modifier.padding(bottom = DesignTokens.spacingDefault)) {
        groups.forEach { (groupName, items) ->
            FlowRow(Modifier.fillMaxWidth()) {
                if (groups.size > 1 || groupName != otherLabel) {
                    // 组名 label: 小字淡灰, 不参与点击; 标签用 # 前缀承担可点语义
                    Text(
                        text = groupName,
                        color = AppTheme.colors.summaryText,
                        fontSize = 11.sp,
                        modifier = Modifier.padding(end = 8.dp, top = 7.dp),
                    )
                }
                items.forEach { (value, fullKind) ->
                    if (value.isNotEmpty()) {
                        Text(
                            text = "#$value",
                            color = AppTheme.colors.accent,
                            fontSize = 13.sp,
                            maxLines = 1,
                            modifier = Modifier
                                .clip(DesignTokens.shapeSm)
                                .combinedClickable(
                                    onClick = { actions.onSearchKind(fullKind, true) },
                                    onLongClick = { actions.onSearchKind(value, false) },
                                )
                                .padding(horizontal = 8.dp, vertical = 6.dp),
                        )
                    }
                }
            }
        }
    }
}

/** kind 解析: `组:值` 归组，其余入"其它"; fullKind 保留原串供 :: 探索跳转 */
private fun buildKindGroups(
    kind: String?,
    otherLabel: String,
): List<Pair<String, List<Pair<String, String>>>> {
    val kinds = kind?.splitNotBlank(",", "\n") ?: return emptyList()
    val groups = linkedMapOf<String, MutableList<Pair<String, String>>>()
    kinds.forEach { k ->
        val tagContent = k.substringBefore("::").trim()
        val groupSplit = tagContent.split(":", limit = 2)
        if (groupSplit.size > 1 && groupSplit.all { it.isNotBlank() }) {
            groups.getOrPut(groupSplit[0].trim()) { mutableListOf() }
                .add(groupSplit[1].trim() to k)
        } else if (tagContent.isNotBlank()) {
            groups.getOrPut(otherLabel) { mutableListOf() }.add(tagContent to k)
        }
    }
    return groups.map { (k, v) -> k to v.toList() }
}

// ---- 简介(可选中; <button>=胶囊动作、<img>=整宽图, 对照 setIntroWithActions) ----

private sealed interface IntroChunk
private class PlainChunk(val text: String) : IntroChunk
private class ButtonChunk(val label: String, val action: String) : IntroChunk

private sealed interface IntroPart
private class IntroTextPart(val chunks: List<IntroChunk>) : IntroPart
private class IntroImagePart(val src: String, val onclick: String? = null) : IntroPart

@Composable
private fun IntroSection(
    state: BookInfoUiState,
    actions: BookInfoUiActions,
    introImageSlot: @Composable (String, () -> Unit) -> Unit,
    modifier: Modifier,
) {
    val intro = state.book?.getDisplayIntro()
    val eInk = LocalEInk.current
    // 简介默认折叠，避免长简介把整页撑满并压到下方操作栏
    var expanded by remember(intro) { mutableStateOf(false) }
    val plainPreview = remember(intro) {
        intro?.let { Ksoup.parseBodyFragment(it).text().trim() }.orEmpty()
    }
    val foldable = plainPreview.length > INTRO_PREVIEW_LENGTH

    if (intro.isNullOrBlank() || !intro.contains('<')) {
        SelectionContainer(modifier.fillMaxWidth()) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .then(if (eInk) Modifier else Modifier.animateContentSize(tween(220))),
            ) {
                Text(
                    text = intro ?: stringResource(Res.string.book_intro),
                    color = AppTheme.colors.secondaryText,
                    fontSize = 15.sp,
                    lineHeight = 26.sp,
                    maxLines = if (expanded) Int.MAX_VALUE else INTRO_COLLAPSED_LINES,
                    overflow = TextOverflow.Ellipsis,
                )
                if (foldable) {
                    IntroExpandToggle(expanded) { expanded = !expanded }
                }
            }
        }
        return
    }
    val parts = remember(intro) { parseIntro(intro) }
    SelectionContainer(modifier.fillMaxWidth()) {
        Column(
            Modifier
                .fillMaxWidth()
                .then(if (eInk) Modifier else Modifier.animateContentSize(tween(220))),
        ) {
            if (expanded) {
                parts.forEach { part ->
                    when (part) {
                        is IntroTextPart -> IntroRichText(part) { actions.onDispatchIntroAction(it) }
                        is IntroImagePart -> {
                            // 源站自定义 onclick: 与 button 同通道执行 evalJS; 无则查看大图
                            if (!part.onclick.isNullOrBlank()) {
                                introImageSlot(part.src) { actions.onDispatchIntroAction(part.onclick) }
                            } else {
                                introImageSlot(part.src) { actions.onShowPhoto(part.src) }
                            }
                        }
                    }
                }
            } else {
                Text(
                    text = plainPreview,
                    color = AppTheme.colors.secondaryText,
                    fontSize = 15.sp,
                    lineHeight = 26.sp,
                    maxLines = INTRO_COLLAPSED_LINES,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (foldable) {
                IntroExpandToggle(expanded) { expanded = !expanded }
            }
        }
    }
}

private const val INTRO_PREVIEW_LENGTH = 140
private const val INTRO_COLLAPSED_LINES = 6

/** 简介展开/收起按钮 */
@Composable
private fun IntroExpandToggle(expanded: Boolean, onToggle: () -> Unit) {
    Text(
        text = stringResource(
            if (expanded) Res.string.collapse else Res.string.expand
        ),
        color = AppTheme.colors.accent,
        fontSize = 13.sp,
        modifier = Modifier
            .padding(top = 6.dp)
            .clip(RoundedCornerShape(6.dp))
            .clickable(onClick = onToggle)
            .padding(horizontal = 4.dp, vertical = 2.dp),
    )
}

private fun parseIntro(intro: String): List<IntroPart> {
    val parts = mutableListOf<IntroPart>()
    val chunks = mutableListOf<IntroChunk>()
    fun flush() {
        if (chunks.isNotEmpty()) {
            parts.add(IntroTextPart(chunks.toList()))
            chunks.clear()
        }
    }

    fun walk(parent: Element) {
        for (node in parent.childNodes()) {
            when (node) {
                is TextNode -> chunks.add(PlainChunk(node.getWholeText()))
                is Element -> when (node.tagName().lowercase()) {
                    "button" -> {
                        val label = node.text()
                        if (label.isNotBlank()) {
                            chunks.add(ButtonChunk(label, node.attr("onclick")))
                        }
                    }

                    "img" -> {
                        val src = node.absUrl("src").ifEmpty { node.attr("src") }
                        if (src.isNotBlank()) {
                            flush()
                            // 提取源站自定义 onclick (intro 经 formatKeepRichTags 处理, 属性原样保留),
                            // 点击时优先执行 (与 button 同通道), 否则查看大图
                            val onclick = node.attr("onclick").takeIf { it.isNotBlank() }
                            parts.add(IntroImagePart(src, onclick))
                        }
                    }

                    else -> walk(node)
                }
            }
        }
    }
    walk(Ksoup.parseBodyFragment(intro).body())
    flush()
    return parts
}

@Composable
private fun IntroRichText(part: IntroTextPart, onAction: (String) -> Unit) {
    val secondary = AppTheme.colors.secondaryText
    val textMeasurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val text = buildAnnotatedString {
        part.chunks.forEachIndexed { i, chunk ->
            when (chunk) {
                is PlainChunk -> append(chunk.text)
                is ButtonChunk -> appendInlineContent("btn$i", chunk.label)
            }
        }
    }
    // 行内胶囊: 有意偏离原版 IntroButtonSpan(14×10), 与分类标签 item_fillet_text 视觉统一;
    // 占位尺寸 = 文本 + 胶囊内边距×2 (取组件里的基础值), 背景/按压/文字统一走 AppFilletTextButton
    val inline = mutableMapOf<String, InlineTextContent>()
    part.chunks.forEachIndexed { i, chunk ->
        if (chunk !is ButtonChunk) return@forEachIndexed
        val layout = textMeasurer.measure(AnnotatedString(chunk.label), TextStyle(fontSize = 14.sp))
        val w = with(density) { (layout.size.width + (filletChipPaddingH * 2).toPx()).toSp() }
        val h = with(density) { (layout.size.height + (filletChipPaddingV * 2).toPx()).toSp() }
        inline["btn$i"] = InlineTextContent(
            Placeholder(w, h, PlaceholderVerticalAlign.TextCenter),
        ) {
            DisableSelection {
                AppFilletTextButton(
                    text = chunk.label,
                    modifier = Modifier.fillMaxSize(),
                    onClick = { onAction(chunk.action) },
                )
            }
        }
    }
    Text(
        text = text,
        color = secondary,
        fontSize = 15.sp,
        lineHeight = 26.sp,
        inlineContent = inline,
        modifier = Modifier.fillMaxWidth(),
    )
}

// ---- 底部按钮(对照 ArcoButton tintBottom / Primary.Large) ----

@Composable
private fun BottomButtons(
    state: BookInfoUiState,
    actions: BookInfoUiActions,
    modifier: Modifier,
) {
    val colors = AppTheme.colors
    Column(
        modifier
            .fillMaxWidth()
            .background(colors.bottomBackground)
            .navigationBarsPadding(),
    ) {
        HairlineDivider()
        Row(
            Modifier
                .fillMaxWidth()
                .padding(
                    start = DesignTokens.spacingLg,
                    end = DesignTokens.spacingLg,
                    top = DesignTokens.spacingMd,
                    bottom = DesignTokens.spacingMd,
                ),
            horizontalArrangement = Arrangement.spacedBy(DesignTokens.spacingDefault),
        ) {
            AppOutlinedButton(
                text = rememberString(
                    if (state.inBookshelf) "remove_from_bookshelf"
                    else "add_to_bookshelf"
                ),
                modifier = Modifier
                    .weight(1f)
                    .height(DesignTokens.viewHeightXl),
            ) { actions.onShelfClick() }
            AppSolidButton(
                text = stringResource(Res.string.reading),
                modifier = Modifier.weight(1f),
            ) { actions.onReadClick() }
        }
    }
}
