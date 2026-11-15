package com.langhuan.reader.ui.bookshelf

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.CircularProgressIndicator
import androidx.compose.material.Divider
import androidx.compose.material.DropdownMenuItem
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.help.config.AppConfigProviders
import com.langhuan.reader.uimodel.BookItemUi
import com.langhuan.reader.utils.pureKindText
import com.langhuan.reader.utils.splitNotBlank
import com.langhuan.reader.ui.compose.component.listItemFocus
import com.langhuan.reader.ui.compose.component.OverflowMenu
import com.langhuan.reader.ui.compose.platform.rememberPainter
import com.langhuan.reader.ui.compose.platform.rememberString
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.utils.toTimeAgo
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.ic_bookmark
import com.langhuan.reader.ui.generated.resources.ic_search
import com.langhuan.reader.ui.generated.resources.intro_show_null
import com.langhuan.reader.ui.generated.resources.search
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringResource

/**
 * 书架条目共享组件（KMP 版）：列表 / 网格 / 视频卡与搜索、发现页共用。
 *
 * - 封面统一走 `coverSlot` 注入：默认 [SharedBookCover]，各端行为一致
 * - 条目按 [ShelfCoverSlot] 档位决定容器约束与封面 modifier，避免宽高两维被钉死
 * - 书架首页本身只用 3D 书架（[com.langhuan.reader.ui.bookshelf.shelf.LanghuanShelf]），
 *   这里的条目组件服务搜索结果、发现展示、阅读记录等场景
 */

/** 16:9 视频封面按 3/4 高度收窄, 与 ItemBookshelfListBindingExt 的同名常量语义一致 */
private const val VIDEO_HEIGHT_SCALE = 0.75f


/**
 * 条目层给封面的尺寸约束档位。封面组件按 "哪个维度被约束" 反算另一个维度 (见
 * `SharedCoverContent` 内部 `coverSizeModifier`), 所以容器约束与传给封面的 modifier 必须
 * 成对出现: 列表档钉高、给 [androidx.compose.foundation.layout.fillMaxHeight]; 网格/视频档
 * 钉宽、给 [androidx.compose.foundation.layout.fillMaxWidth]。
 */
enum class ShelfCoverSlot { LIST, GRID, VIDEO }

/**
 * 封面容器: 同时决定容器自身约束与下发给封面的 modifier, 两者由同一处给出。
 *
 * 拆开写就会出现"容器钉高、封面却拿到 fillMaxWidth"的错配: 宽高两维都被钉死且比例与容器宽
 * 不一致时, 封面的 `aspectRatio` 会静默放弃比例按宽度测量, 封面撑满整行。
 *
 * @param coverHeightDp 列表档封面高度 (网格/视频档高度由宽度算出, 此值不用)
 * @param cover 封面渲染回调, 收到与 [slot] 配套的尺寸 modifier 与比例档位
 */
@Composable
internal fun ShelfCoverBox(
    slot: ShelfCoverSlot,
    coverHeightDp: Int = 0,
    listIsVideo: Boolean = false,
    contentAlignment: Alignment = Alignment.TopStart,
    cover: @Composable (Modifier, coverRatio: CoverSlotRatio) -> Unit,
) {
    val boxModifier: Modifier = when (slot) {
        // 列表档: 高度由 bookshelfCoverHeight 决定, 宽度按封面比例反算
        ShelfCoverSlot.LIST -> Modifier.height(coverHeightDp.dp)
        // 网格档: 宽度填满格子 (左右各 12dp 内边距, 对照原 XML iv_cover match_parent + 12dp margin)
        ShelfCoverSlot.GRID -> Modifier.fillMaxWidth().padding(start = DesignTokens.spacingMd, top = DesignTokens.spacingMd, end = DesignTokens.spacingMd)
        // 视频档: 宽度填满格子
        ShelfCoverSlot.VIDEO -> Modifier.fillMaxWidth()
    }
    val coverModifier: Modifier = when (slot) {
        ShelfCoverSlot.LIST -> Modifier.fillMaxHeight()
        ShelfCoverSlot.GRID, ShelfCoverSlot.VIDEO -> Modifier.fillMaxWidth()
    }
    // 比例档位对照原 bindExploreCard / bindGridCard / bindVideoCard 与各 GroupViewHolder:
    // 列表档书籍随 listIsVideo 固定 (分组列表档恒 NOVEL, 对照原版 GroupViewHolder 不设 coverRatio),
    // 网格档恒 NOVEL, 视频档按真实宽高自适应。列表档行高钉死、宽度按比例反算, 横竖封面混排
    // 会让同行条目的封面宽度参差, 故恒固定比例不自适应
    val coverRatio = when (slot) {
        ShelfCoverSlot.LIST -> if (listIsVideo) CoverSlotRatio.VIDEO else CoverSlotRatio.NOVEL
        ShelfCoverSlot.GRID -> CoverSlotRatio.NOVEL
        ShelfCoverSlot.VIDEO -> CoverSlotRatio.AUTO
    }
    Box(boxModifier, contentAlignment = contentAlignment) { cover(coverModifier, coverRatio) }
}



/**
 * 列表档封面高度: 读全局配置 `bookshelfCoverHeight`, 视频样式按 0.75 收窄。
 *
 * 收窄的理由 (对照原版 `applyCoverHeight` 注释): 16:9 视频封面横宽, 列表里容易挤到别的列,
 * 按 3/4 倍高度收一下, 视觉上宽度仍与 3:4 小说封面同量级。
 *
 * 本函数是列表档封面高度的唯一来源: 书架/发现页/搜索列表/阅读记录四处条目共用, 不得在
 * 条目层内联同一公式 (内联副本会随配置项或收窄系数变化而各自漂移)。
 */
internal fun shelfCoverHeightDp(isVideoStyle: Boolean): Int {
    val base = AppConfigProviders.get().bookshelfCoverHeight
    return if (isVideoStyle) (base * VIDEO_HEIGHT_SCALE).toInt() else base
}




/**
 * 顶栏动作区: 搜索图标(常显) + 溢出菜单(对照原 main_bookshelf.xml 项序)
 *
 * shared 版本: 不依赖 BaseBookshelfState, 改为接受 [BookshelfActionsCallbacks]
 * (app 端由 BookshelfState 实现 callbacks, 桌面端由调用方注入)
 */
@Composable
fun BookshelfActions(callbacks: BookshelfActionsCallbacks, showSearch: Boolean = true) {
    val colors = AppTheme.colors
    if (showSearch) {
        IconButton(onClick = callbacks.onOpenSearch) {
            Icon(
                painter = painterResource(Res.drawable.ic_search),
                contentDescription = stringResource(Res.string.search),
                tint = colors.primaryText,
            )
        }
    }
    OverflowMenu { dismiss ->
        // 刷新: 等价下拉刷新 (onRefresh), 无下拉手势的端 (如桌面) 走此入口
        ShelfMenuItem("refresh") { dismiss(); callbacks.onRefresh() }
        ShelfMenuItem("force_refresh_book") { dismiss(); callbacks.onRefreshShelf() }
        ShelfMenuItem("add_remote_book") { dismiss(); callbacks.onAddRemoteBook() }
        ShelfMenuItem("add_url") { dismiss(); callbacks.onShowAddBookByUrlAlert() }
        // 导入书 / 导入书单在「本地」页，不再占书架菜单
        Divider(
            color = AppTheme.colors.line,
            thickness = 0.5.dp,
            modifier = Modifier.padding(vertical = 4.dp),
        )
        ShelfMenuItem("bookshelf_management") { dismiss(); callbacks.onOpenBookshelfManage() }
        ShelfMenuItem("group_manage") { dismiss(); callbacks.onShowGroupManage() }
        ShelfMenuItem("log") { dismiss(); callbacks.onShowAppLog() }
    }
}

/** 书架顶栏动作回调集合 (替代 app 端 BaseBookshelfState 的菜单动作方法) */
data class BookshelfActionsCallbacks(
    val onOpenSearch: () -> Unit = {},
    /** 刷新 (等价下拉刷新 onRefresh, 无下拉手势的端走菜单入口) */
    val onRefresh: () -> Unit = {},
    val onRefreshShelf: () -> Unit = {},
    val onAddRemoteBook: () -> Unit = {},
    val onShowAddBookByUrlAlert: () -> Unit = {},
    val onOpenBookshelfManage: () -> Unit = {},
    val onShowGroupManage: () -> Unit = {},
    val onShowAppLog: () -> Unit = {},
)

@Composable
private fun ShelfMenuItem(textKey: String, onClick: () -> Unit) {
    DropdownMenuItem(
        onClick = onClick,
    ) {
        Text(rememberString(textKey), color = AppTheme.colors.primaryText)
    }
}

// ---- 条目 ----

/** 复刻 BadgeView: 11sp/最小 16dp/8dp 圆角, 高亮 accent 否则 darker_gray(#AAAAAA), 0 隐藏.
 * 文字色按底色亮度判黑白 (对齐原版 BadgeView.setTextColor(isColorLight(badgeColor))). */
@Composable
fun UnreadBadge(count: Int, highlight: Boolean, modifier: Modifier = Modifier) {
    if (count <= 0) return
    val colors = AppTheme.colors
    val bg = if (highlight) colors.accent else Color(0xAAAAAAAA)
    Box(
        modifier
            .defaultMinSize(minWidth = 16.dp, minHeight = 16.dp)
            .background(bg, DesignTokens.shapeDefault)
            .padding(horizontal = 5.dp, vertical = 1.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            "$count",
            color = if (bg.luminance() >= 0.5f) Color.Black else Color.White,
            fontSize = 11.sp,
        )
    }
}

/** 复刻 LabelsBar/AccentBgTextView: accent 底 2dp 圆角标签, 文字按底色亮度判黑白
 * (对齐原版 setTextColor(isColorLight(accentColor))) */
@Composable
fun KindLabels(kinds: List<String>) {
    val colors = AppTheme.colors
    val textColor = if (colors.accent.luminance() >= 0.5f) Color.Black else Color.White
    Row {
        kinds.forEach { kind ->
            Text(
                text = kind,
                color = textColor,
                fontSize = 12.sp,
                maxLines = 1,
                modifier = Modifier
                    .padding(end = 2.dp)
                    .background(colors.accent, KindLabelShape)
                    .padding(horizontal = 3.dp),
            )
        }
    }
}

/** 标签圆角: 预建一份, 免得每个标签每次重组都 new 一个 shape */
private val KindLabelShape = RoundedCornerShape(2.dp)

@Composable
fun ShelfRowIcon(painterKey: String) {
    Icon(
        painter = rememberPainter(painterKey),
        contentDescription = null,
        tint = AppTheme.colors.secondaryText,
        modifier = Modifier.size(18.dp).padding(horizontal = 2.dp),
    )
}

// ---- 展示模型上的条目派生值 (同 Book 实体方法口径, 只取展示模型已有字段) ----

/** 展示用作者 (同 `BaseBook.getRealAuthor`: 多作者按换行拆分, 去掉 `::` 之后的别名) */
private fun BookItemUi.shelfRealAuthor(): String =
    author.splitNotBlank("\n").joinToString("\n") { it.split("::")[0] }

/** 分类标签 (同 `BaseBook.getKindList`: 字数在前, 分类净化在后) */
private fun BookItemUi.shelfKindList(): List<String> = buildList {
    wordCount?.splitNotBlank(",", "\n")?.forEach { raw ->
        if (raw.isNotBlank()) add(raw)
    }
    kind?.splitNotBlank(",", "\n")?.forEach { raw ->
        val pure = raw.pureKindText()
        if (pure.isNotBlank()) add(pure)
    }
}

/** 展示用简介 (同 `Book.getDisplayIntro`: 自定义简介优先) */
private fun BookItemUi.shelfDisplayIntro(): String? =
    customIntro.takeUnless { it.isNullOrEmpty() } ?: intro

/** 展示用封面 (同 `Book.getDisplayCoverRef`: 自定义封面优先; 仅用于有无封面判断) */
private fun BookItemUi.shelfDisplayCover(): String? =
    customCoverUrl.takeUnless { it.isNullOrEmpty() } ?: coverUrl

/**
 * 列表条目, 对照 item_bookshelf_list: 书名行(徽标/转圈)+作者行(更新时间)+分类+进度+最新+简介
 *
 * shared 版本: 封面改为 [coverSlot] 注入 (默认 SharedBookCover);
 * 封面尺寸由 [coverSlot] 接收的 Modifier 决定 (列表档传 fillMaxHeight 触发封面组件
 * 按高度+比例反算宽度, 对照原 XML iv_cover height=120dp + wrap_content width)
 *
 * 封面比例: 对照原 [ItemBookshelfListBinding.bindExploreCard] 的 `ivCover.coverRatio =
 * if (isVideoStyle) VIDEO else NOVEL`, 此处按 [isVideoStyle] 映射档位透传给 [coverSlot].
 */
@Composable
fun ShelfListItem(
    book: BookItemUi,
    isVideoStyle: Boolean,
    coverReloadTick: Int,
    refreshingUrls: Set<String>,
    showLastUpdateTime: Boolean,
    showKindIntro: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
    // 搜索页书架命中区复用本条目时按原版 BookAdapter 覆盖书架配置门:
    // kind/intro/更新时间恒显, flHasNew.gone() 不画未读徽标
    forceShowKind: Boolean = false,
    forceShowIntro: Boolean = false,
    forceShowUpdateTime: Boolean = false,
    hideUnread: Boolean = false,
    coverSlot: @Composable (BookItemUi, Modifier, CoverSlotRatio, Int) -> Unit,
    // 更新时间 Text 注入: 父项不感知 timeTick 心跳
    lastUpdateTextSlot: @Composable () -> Unit,
) {
    val colors = AppTheme.colors
    val appConfig = remember { AppConfigProviders.get() }
    val coverHeight = remember(coverReloadTick, isVideoStyle) { shelfCoverHeightDp(isVideoStyle) }
    val refreshing = book.bookUrl in refreshingUrls
    Row(
        modifier
            .listItemFocus()
            .fillMaxWidth()
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(DesignTokens.spacingDefault),
    ) {
        ShelfCoverBox(ShelfCoverSlot.LIST, coverHeightDp = coverHeight, listIsVideo = isVideoStyle) { m, coverRatio ->
            coverSlot(book, m, coverRatio, coverReloadTick)
        }
        Column(
            Modifier
                .weight(1f)
                .padding(start = DesignTokens.spacingDefault)
                .heightIn(min = coverHeight.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = book.name,
                    color = colors.primaryText,
                    fontSize = 16.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f).padding(start = DesignTokens.spacingXs),
                )
                if (refreshing && !book.isLocal) {
                    CircularProgressIndicator(
                        color = colors.accent,
                        modifier = Modifier.size(26.dp),
                    )
                } else if (!hideUnread && appConfig.showUnread) {
                    UnreadBadge(book.unreadCount, highlight = book.lastCheckCount > 0)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                ShelfRowIcon("ic_author")
                Text(
                    text = remember(book.author) { book.shelfRealAuthor() },
                    color = colors.secondaryText,
                    fontSize = 13.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f).padding(end = DesignTokens.spacingDefault),
                )
                if (forceShowUpdateTime ||
                    (showLastUpdateTime && appConfig.showLastUpdateTime && !book.isLocal)
                ) {
                    lastUpdateTextSlot()
                }
            }
            if (forceShowKind || (showKindIntro && appConfig.bookshelfListShowKind)) {
                // 正则切分 + 净化, 别每次重组重算
                val kinds = remember(book.kind, book.wordCount) { book.shelfKindList() }
                if (kinds.isNotEmpty()) KindLabels(kinds)
            }
            if (!book.durChapterTitle.isNullOrEmpty()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ShelfRowIcon("ic_history")
                    Text(
                        text = book.durChapterTitle.toString(),
                        color = colors.secondaryText,
                        fontSize = 13.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            if (!book.latestChapterTitle.isNullOrEmpty()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ShelfRowIcon("ic_book_last")
                    Text(
                        text = book.latestChapterTitle.toString(),
                        color = colors.secondaryText,
                        fontSize = 13.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            if (forceShowIntro || (showKindIntro && appConfig.bookshelfListShowIntro)) {
                val intro = remember(book.intro, book.customIntro) { book.shelfDisplayIntro() }
                if (!intro.isNullOrBlank()) {
                    Text(
                        text = intro,
                        color = colors.secondaryText,
                        fontSize = 13.sp,
                        maxLines = appConfig.bookshelfListIntroLines,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(start = 2.dp),
                    )
                }
            }
        }
    }
}

/**
 * [ShelfListItem] 的实体重载: 书架之外 (搜索结果等) 仍持有 [Book] 的调用方直接传实体,
 * 在边界转成展示模型渲染, 避免这些页面为一次类型迁移各自加一层适配。
 */
@Composable
fun ShelfListItem(
    book: Book,
    isVideoStyle: Boolean,
    coverReloadTick: Int,
    refreshingUrls: Set<String>,
    showLastUpdateTime: Boolean,
    showKindIntro: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
    forceShowKind: Boolean = false,
    forceShowIntro: Boolean = false,
    forceShowUpdateTime: Boolean = false,
    hideUnread: Boolean = false,
    coverSlot: @Composable (Book, Modifier, CoverSlotRatio, Int) -> Unit,
    lastUpdateTextSlot: @Composable () -> Unit,
) = ShelfListItem(
    book = book.toBookItemUi(),
    isVideoStyle = isVideoStyle,
    coverReloadTick = coverReloadTick,
    refreshingUrls = refreshingUrls,
    showLastUpdateTime = showLastUpdateTime,
    showKindIntro = showKindIntro,
    onClick = onClick,
    onLongClick = onLongClick,
    modifier = modifier,
    forceShowKind = forceShowKind,
    forceShowIntro = forceShowIntro,
    forceShowUpdateTime = forceShowUpdateTime,
    hideUnread = hideUnread,
    coverSlot = { _, m, coverRatio, tick -> coverSlot(book, m, coverRatio, tick) },
    lastUpdateTextSlot = lastUpdateTextSlot,
)

/** 更新时间 Text: derivedStateOf 订阅心跳, 仅本 Composable 在 timeTick 变化时重组 */
@Composable
fun ShelfLastUpdateText(time: Long, timeTick: State<Int>) {
    val colors = AppTheme.colors
    val timeAgo by remember(time) {
        derivedStateOf {
            timeTick.value
            time.toTimeAgo()
        }
    }
    Text(timeAgo, color = colors.secondaryText, fontSize = 13.sp, maxLines = 1)
}

/**
 * 书架标记 (ic_bookmark): 标记该书已加入书架。
 *
 * 对照原版 `iv_in_bookshelf` (item_bookshelf_grid / item_explore_video): 尺寸由调用方给
 * (网格档随封面宽度等比 0.22, 视频档固定 30dp), 由调用方贴在封面左上角。
 */
@Composable
fun BookshelfBadge(modifier: Modifier = Modifier) {
    Image(
        painter = painterResource(Res.drawable.ic_bookmark),
        contentDescription = null,
        modifier = modifier,
    )
}

/**
 * 网格条目, 对照 item_bookshelf_grid: 封面(12dp 边距)+两行书名, 书架标记叠加封面左上, 未读/转圈叠加右上。
 *
 * @param inBookshelf 书架标记: null = 不显示 (书架内每条都已入库, 逐条亮是噪音, 对照原版
 *   showBookshelfBadge=false); 非书架界面 (搜索结果) 传该书真实书架态, 对照原版 bindGridCard 的
 *   showBookshelfBadge && isInBookshelf。
 */
@Composable
fun ShelfGridItem(
    book: BookItemUi,
    coverReloadTick: Int,
    refreshingUrls: Set<String>,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
    inBookshelf: Boolean? = null,
    coverSlot: @Composable (BookItemUi, Modifier, CoverSlotRatio, Int) -> Unit,
) {
    val colors = AppTheme.colors
    val appConfig = remember { AppConfigProviders.get() }
    val refreshing = book.bookUrl in refreshingUrls
    Box(modifier.listItemFocus().combinedClickable(onClick = onClick, onLongClick = onLongClick)) {
        Column(Modifier.fillMaxWidth()) {
            // 封面 Box: 宽度填满 (减 12dp 左右内边距), 对照原 XML iv_cover match_parent + 12dp margin
            // 无 cover URL 时仍渲染封面 Box (走占位), 对齐原 View 版无 path 也显示默认封面
            ShelfCoverBox(ShelfCoverSlot.GRID, contentAlignment = Alignment.TopCenter) { m, coverRatio ->
                coverSlot(book, m, coverRatio, coverReloadTick)
            }
            Text(
                text = book.name,
                color = colors.primaryText,
                fontSize = 12.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(top = DesignTokens.spacingDefault),
            )
        }
        // 书架标记对照原 XML: 约束到 iv_cover 的 start/top (iv_cover 带 12dp margin), 宽度 0.22 比例
        if (inBookshelf == true) {
            BookshelfBadge(
                Modifier
                    .align(Alignment.TopStart)
                    .padding(start = DesignTokens.spacingMd, top = DesignTokens.spacingMd)
                    .fillMaxWidth(0.22f)
                    .aspectRatio(1f),
            )
        }
        // 徽标/转圈对照原 XML: 约束到 parent 右上角 (bv_unread/rl_loading 均 layout_constraintRight_toRightOf=parent + Top_toTopOf=parent),
        // 不放进封面 Box (那有 12dp padding 会把徽标推到 16dp 处); bv_unread marginTop/End=4dp, rl_loading 无 margin
        if (refreshing && !book.isLocal) {
            CircularProgressIndicator(
                color = colors.accent,
                modifier = Modifier.align(Alignment.TopEnd).size(22.dp),
            )
        } else if (appConfig.showUnread) {
            UnreadBadge(
                count = book.unreadCount,
                highlight = book.lastCheckCount > 0,
                modifier = Modifier.align(Alignment.TopEnd).padding(top = DesignTokens.spacingXs, end = DesignTokens.spacingXs),
            )
        }
    }
}

/**
 * [ShelfGridItem] 的实体重载: 书架之外 (搜索结果/发现展示) 仍持有 [Book] 的调用方直接传实体。
 */
@Composable
fun ShelfGridItem(
    book: Book,
    coverReloadTick: Int,
    refreshingUrls: Set<String>,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
    inBookshelf: Boolean? = null,
    coverSlot: @Composable (Book, Modifier, CoverSlotRatio, Int) -> Unit,
) = ShelfGridItem(
    book = book.toBookItemUi(),
    coverReloadTick = coverReloadTick,
    refreshingUrls = refreshingUrls,
    onClick = onClick,
    onLongClick = onLongClick,
    modifier = modifier,
    inBookshelf = inBookshelf,
    coverSlot = { _, m, coverRatio, tick -> coverSlot(book, m, coverRatio, tick) },
)

/**
 * 视频卡片, 对照 item_explore_video/bindVideoCard: 16:9 封面+粗体标题+分类+作者, 书架标记叠加封面左上。
 *
 * @param inBookshelf 书架标记: null = 不显示 (书架内每条都已入库, 逐条亮是噪音, 对照原版
 *   showBookshelfBadge=false); 非书架界面 (探索展示/搜索结果) 传该书真实书架态, 对照原版
 *   bindVideoCard 的 showBookshelfBadge && isInBookshelf。
 */
private val ShelfInBookshelfDotColor = Color(0xFF43A047)

/**
 * 视频卡片 (对照 item_explore_video.xml / bindVideoCard):
 * 上封面 (16:9 / 3:4 自适应) + 下两行标题 + 标签 + 作者。
 *
 * 对齐原版 bindVideoCard:
 * - 无封面 URL 时隐藏封面 (ivCover.gone), 连占位图都不显示
 * - 有封面 URL 时渲染视频封面槽 (支持按真实图片宽高在 16:9 与 3:4 间自适应)
 * - 书架标记: 有封面时贴左上角徽标; 无封面时在书名左侧显示书架绿点
 */
@Composable
fun ShelfVideoItem(
    book: BookItemUi,
    coverReloadTick: Int,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
    inBookshelf: Boolean? = null,
    coverSlot: @Composable (BookItemUi, Modifier, CoverSlotRatio, Int) -> Unit,
) {
    val colors = AppTheme.colors
    val hasCover = !book.shelfDisplayCover().isNullOrBlank()
    Column(
        modifier
            .listItemFocus()
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(DesignTokens.spacingDefault),
    ) {
        if (hasCover) {
            Box {
                // 有封面时按视频槽渲染，由底层封面组件按实际宽高自适应 16:9 / 3:4
                ShelfCoverBox(ShelfCoverSlot.VIDEO) { m, coverRatio ->
                    coverSlot(book, m, coverRatio, coverReloadTick)
                }
                // 书架标记对照原 XML: 固定 30dp, 贴封面左上角 (无 margin)
                if (inBookshelf == true) {
                    BookshelfBadge(Modifier.align(Alignment.TopStart).size(30.dp))
                }
            }
        }
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(top = if (hasCover) DesignTokens.spacingDefault else 0.dp),
        ) {
            if (!hasCover && inBookshelf == true) {
                Box(
                    Modifier
                        .padding(end = DesignTokens.spacingXs)
                        .size(8.dp)
                        .background(ShelfInBookshelfDotColor, CircleShape),
                )
            }
            Text(
                text = book.name,
                color = colors.primaryText,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
        }
        // 正则切分 + 净化 / 作者拆分, 别每次重组重算
        val kinds = remember(book.kind, book.wordCount) { book.shelfKindList() }
        if (kinds.isNotEmpty()) {
            Box(Modifier.padding(top = 2.dp)) { KindLabels(kinds) }
        }
        val author = remember(book.author) { book.shelfRealAuthor() }
        if (author.isNotBlank()) {
            Text(
                text = author,
                color = colors.secondaryText,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
    }
}

/**
 * [ShelfVideoItem] 的实体重载: 书架之外 (主页区块/发现展示/搜索结果) 仍持有 [Book] 的调用方直接传实体。
 */
@Composable
fun ShelfVideoItem(
    book: Book,
    coverReloadTick: Int,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
    inBookshelf: Boolean? = null,
    coverSlot: @Composable (Book, Modifier, CoverSlotRatio, Int) -> Unit,
) = ShelfVideoItem(
    book = book.toBookItemUi(),
    coverReloadTick = coverReloadTick,
    onClick = onClick,
    onLongClick = onLongClick,
    modifier = modifier,
    inBookshelf = inBookshelf,
    coverSlot = { _, m, coverRatio, tick -> coverSlot(book, m, coverRatio, tick) },
)


/**
 * 发现页与搜索结果共用的图文列表条目 (List tier, 对照 item_bookshelf_list / ExploreShowAdapter.bind):
 * 左封面 (带视频收窄与无图自适应) + 右书名 (带书架绿点与可选多源角标) + 作者 + 分类 + 最新章节 + 简介。
 */
@Composable
fun ShelfExploreListItem(
    book: BookItemUi,
    isVideoStyle: Boolean,
    inBookshelf: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    modifier: Modifier = Modifier,
    originCount: Int = 0,
    showShelfDot: Boolean = true,
    intro: String? = null,
    coverSlot: @Composable (Modifier) -> Unit,
) {
    val colors = AppTheme.colors
    val hasCover = !book.coverUrl.isNullOrBlank()
    val showCover = !isVideoStyle || hasCover
    Row(
        modifier
            .listItemFocus()
            .fillMaxWidth()
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(DesignTokens.spacingDefault),
    ) {
        val coverHeight = remember(isVideoStyle) { shelfCoverHeightDp(isVideoStyle) }
        if (showCover) {
            Box(Modifier.height(coverHeight.dp)) {
                coverSlot(Modifier.fillMaxHeight())
            }
        }
        Column(
            Modifier
                .weight(1f)
                .padding(start = if (showCover) DesignTokens.spacingDefault else 0.dp)
                .heightIn(min = if (showCover) coverHeight.dp else 0.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (showShelfDot && inBookshelf) {
                    Box(
                        Modifier
                            .size(8.dp)
                            .background(ShelfInBookshelfDotColor, CircleShape),
                    )
                }
                Text(
                    text = book.name,
                    color = colors.primaryText,
                    fontSize = 16.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = DesignTokens.spacingXs),
                )
                if (originCount > 0) {
                    UnreadBadge(originCount, highlight = false)
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                ShelfRowIcon("ic_author")
                Text(
                    text = remember(book.author) { book.shelfRealAuthor() },
                    color = colors.secondaryText,
                    fontSize = 13.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            val kinds = remember(book.kind, book.wordCount) { book.shelfKindList() }
            if (kinds.isNotEmpty()) KindLabels(kinds)
            if (!book.latestChapterTitle.isNullOrEmpty()) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    ShelfRowIcon("ic_book_last")
                    Text(
                        text = book.latestChapterTitle.toString(),
                        color = colors.secondaryText,
                        fontSize = 13.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            val introText = remember(intro, book.intro) {
                (intro ?: book.intro)?.trim()?.takeIf { it.isNotEmpty() }
            } ?: stringResource(Res.string.intro_show_null)
            Text(
                text = introText,
                color = colors.secondaryText,
                fontSize = 13.sp,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(start = 2.dp),
            )
        }
    }
}

