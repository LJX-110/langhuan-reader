package com.langhuan.reader.ui.book.read

/*
 * 阅读菜单：顶栏 + 底栏（操作坞 / 排版 / 更多）。
 *
 * 四端共用本文件的 Composable 与 [ReadMenuState]；平台端只实现状态与平台动作
 * （Activity 生命周期、TTS、对话框路由），界面一律在这里。
 *
 * # 资源访问
 *
 * - 字符串：`rememberString("key")`（Compose Resources 按 key 查表）
 * - 图标：`rememberPainter("key")`；色值：`rememberColor("key")`
 */

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.tween
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.DropdownMenuItem
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.constant.PageAnim
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.Bookmark
import com.langhuan.reader.help.AppWebDavShared
import com.langhuan.reader.help.book.isEpub
import com.langhuan.reader.help.book.isLocal
import com.langhuan.reader.help.book.isLocalTxt
import com.langhuan.reader.help.book.isNotShelf
import com.langhuan.reader.help.config.ReadBookConfigProviders
import com.langhuan.reader.help.config.ThemeConfigProviders
import com.langhuan.reader.help.config.currentEInkMode
import com.langhuan.reader.help.config.currentNightTheme
import com.langhuan.reader.help.showSourceLogin
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.ui.compose.component.AppDetailSeekBar
import com.langhuan.reader.ui.compose.component.AppDropdownMenu
import com.langhuan.reader.ui.compose.component.AppSelectorDialog
import com.langhuan.reader.ui.compose.component.AppSlider
import com.langhuan.reader.ui.compose.component.AppSwitch
import com.langhuan.reader.ui.compose.component.blockInputWhile
import com.langhuan.reader.ui.compose.component.listItemFocus
import com.langhuan.reader.ui.compose.platform.BackLayerHandler
import com.langhuan.reader.ui.compose.platform.platformNavigationBarPadding
import com.langhuan.reader.ui.compose.platform.platformStatusBarPadding
import com.langhuan.reader.ui.compose.platform.rememberColor
import com.langhuan.reader.ui.compose.platform.rememberPainter
import com.langhuan.reader.ui.compose.platform.rememberString
import com.langhuan.reader.ui.compose.platform.syncGetString
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.compose.theme.LanghuanType
import com.langhuan.reader.ui.compose.theme.LocalEInk
import com.langhuan.reader.ui.compose.theme.langhuanReadable
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.root.RouteResults
import com.langhuan.reader.ui.root.toRouteRef
import com.langhuan.reader.ui.route.BgTextConfigDialogHost
import com.langhuan.reader.ui.route.ChineseConverterDialogHost
import com.langhuan.reader.ui.route.FontSelectDialogHost
import com.langhuan.reader.ui.route.ReadLayoutConfigDialogHost
import com.langhuan.reader.utils.ColorUtils
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.ic_arrow_back
import com.langhuan.reader.ui.generated.resources.indent
import com.langhuan.reader.ui.generated.resources.next_chapter
import com.langhuan.reader.ui.generated.resources.previous_chapter
import com.langhuan.reader.ui.generated.resources.search_content
import com.langhuan.reader.ui.generated.resources.text_font_weight
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringArrayResource
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.roundToInt

/** 全书进度条刻度数（0.1% 精度足够，避免拖动抖动） */
private const val PROGRESS_STEPS = 1000

/** 复刻 View 动画默认 AccelerateDecelerateInterpolator */
val AccelerateDecelerateEasing = Easing { x ->
    (cos((x + 1) * PI) / 2.0 + 0.5).toFloat()
}

/** 阅读页顶栏菜单动作(原 R.menu.book_read 及两个长按子菜单) */
enum class ReadMenuAction {
    CHANGE_SOURCE, CHAPTER_CHANGE_SOURCE, BOOK_CHANGE_SOURCE,
    REFRESH, REFRESH_DUR, REFRESH_AFTER, REFRESH_ALL,
    DOWNLOAD, TOC_REGEX, SET_CHARSET,
    ADD_BOOKMARK, EDIT_CONTENT, SYNC_PROGRESS,
    ENABLE_REPLACE, KEYWORD_HIGHLIGHT, SAME_TITLE_REMOVED, RE_SEGMENT, REVIEW,
    DEL_RUBY_TAG, DEL_H_TAG, IMAGE_STYLE, UPDATE_TOC, LOG,
}

/** 书源操作动作(原 book_read_source PopupMenu) */
enum class SourceAction {
    LOGIN, CHAPTER_PAY, SET_SOURCE_VARIABLE, SET_BOOK_VARIABLE, EDIT_SOURCE, DISABLE_SOURCE,
}

/** 原 R.menu.book_read 的可见/勾选状态 */
class TopMenuState {
    var onLine by mutableStateOf(false)
    var isLocalTxt by mutableStateOf(false)
    var isEpub by mutableStateOf(false)
    var enableReplaceChecked by mutableStateOf(false)
    var reSegmentChecked by mutableStateOf(false)
    var delRubyChecked by mutableStateOf(false)
    var delHChecked by mutableStateOf(false)
    var syncProgressVisible by mutableStateOf(false)
    var sameTitleRemovedChecked by mutableStateOf(false)
    var reviewVisible by mutableStateOf(false)
}

/**
 * ReadMenu 状态接口：暴露 shared Composable 所需的状态属性 + 动作回调。
 *
 * app 端 [ReadMenu] 类实现此接口，保留 Android 专属逻辑（lifecycleScope / alert /
 * Intent / AppConfig / ReadBookConfig / ThemeConfig / ReadBook / AppWebDav 等深度依赖）。
 * shared 端 [ReadMenuOverlay] 等 Composable 仅依赖本接口，达成 KMP 解耦。
 *
 * # 设计说明
 *
 * - 所有 `val` 属性均为只读视图（app 端用 `mutableStateOf` + `private set` 实现）
 * - `fun` 为动作回调，由 app 端 [ReadMenu] 内部桥接到 [ReadBookActivity]（如
 *   `clickSearch()` → `runMenuOut { callBack.openSearchActivity(null) }`）
 * - `openBookInfoActivity` / `supportFinishAfterTransition` / `onTopMenuAction` 三个
 *   方法原本是 Composable 直接访问 `state.activity.xxx`，下沉后改为接口方法桥接
 */
interface ReadMenuState {
    // ---- 显隐与动画 ----
    val visibleState: MutableTransitionState<Boolean>
    val animate: Boolean
    val isVisible: Boolean
    val canShowMenu: Boolean

    /**
     * 收起菜单, [onMenuOutEnd] 在收起动画结束后执行 (对照原版 `ReadMenu.runMenuOut`)。
     * 已收起状态立即执行: 收起态触发的菜单动作等不到动画结束回调。
     */
    fun runMenuOut(onMenuOutEnd: (() -> Unit)? = null)

    // ---- 沉浸式菜单色彩 ----
    val immersive: Boolean
    val bgColor: Int
    val textColor: Int

    /** 是否设置了背景图（原 ThemeConfig.curBgImagePath 非空），背景图时顶栏透明 */
    val hasBgImage: Boolean

    // ---- 顶栏 ----
    val title: String?
    val chapterName: String?
    val chapterUrl: String?
    val chapterNameVisible: Boolean
    val chapterUrlVisible: Boolean
    val sourceActionText: String
    val sourceActionVisible: Boolean
    val titleBarAdditionVisible: Boolean
    val topMenu: TopMenuState

    // ---- 底栏 ----
    val seekMax: Int
    val seekValue: Int
    val prevEnabled: Boolean
    val nextEnabled: Boolean
    val isNightTheme: Boolean

    /** 全书进度（0f..1f），底栏进度条显示用 */
    val bookProgress: Float

    /** 拖动全书进度条落位：按比例跳到对应章节 */
    fun seekBookProgress(fraction: Float) = Unit

    // ---- 动画生命周期回调 ----
    fun onTransitionIdle(shown: Boolean)
    fun onBgClick()

    // ---- 顶栏动作回调 ----
    fun onChapterViewClick()
    fun onChapterViewLongClick()
    fun onOverflowOpened()
    fun sourceLoginVisible(): Boolean
    fun sourcePayVisible(): Boolean
    fun onSourceAction(action: SourceAction)

    // ---- 宿主桥接（原 state.activity.xxx）----
    fun openBookInfoActivity()
    fun supportFinishAfterTransition()
    fun onTopMenuAction(action: ReadMenuAction)

    // ---- 底栏动作回调 ----
    fun onSeekDragStart()
    fun onSeekStop(progress: Int)
    fun clickSearch()
    fun clickReplaceRule()
    fun clickNightTheme()
    fun clickPre()
    fun clickNext()
    fun clickCatalog()
    fun clickReadAloud()
    fun longClickReadAloud()
    fun clickSetting()

    /** 底栏「换源」：整书换源 */
    fun clickChangeSource() = onTopMenuAction(ReadMenuAction.CHANGE_SOURCE)

    /** 长按底栏「换源」：本章换源 */
    fun longClickChangeSource() = onTopMenuAction(ReadMenuAction.CHAPTER_CHANGE_SOURCE)

    // ---- 阅读面板（书签 / 章节定位 / 进度文案）----

    /** 本章进度文案（如「42%」），随翻页与开章刷新 */
    val chapterProgressText: String

    /** 目录位置文案（如「12 / 348」），随翻页与开章刷新 */
    val chapterIndexText: String

    /** 在当前阅读位置添加书签（书签对话框由 Route 层渲染） */
    fun addBookmarkHere() {
        onTopMenuAction(ReadMenuAction.ADD_BOOKMARK)
    }

    /** 本书书签流；null 表示书籍未就绪，面板按空态处理 */
    fun bookmarkFlow(): Flow<List<Bookmark>>? = null

    fun deleteBookmark(bookmark: Bookmark) = Unit

    /** 跳转到书签位置 */
    fun jumpToBookmark(bookmark: Bookmark) = Unit

    /** 回到本章开头 */
    fun clickChapterStart() = Unit

    /** 跳到本章末尾 */
    fun clickChapterEnd() = Unit

    /** 刷新当前章节 (顶栏刷新图标短按) */
    fun onRefresh()

    // region ReadBookEvents 订阅回调 (对照 app 端 readMenu.reset/upSeekBar + upMenuView)

    /** 重建菜单/顶栏 (对照 app 端 actionBarChange → `readMenu.reset()`)。待平台 actual 覆盖。 */
    fun reset() {
        // 待实现：平台 actual 重建菜单视图
    }

    /** 更新进度条 (对照 app 端 seekBarChange → `readMenu.upSeekBar()`)。待平台 actual 覆盖。 */
    fun upSeekBar() {
        // 待实现：平台 actual 刷新进度条 seekMax/seekValue
    }

    /** 刷新菜单数据 (对照 app 端 menuRefresh → `upMenuView()`)。待平台 actual 覆盖。 */
    fun refresh() {
        // 待实现：平台 actual 刷新顶栏/底栏展示数据
    }

    /**
     * 同步日/夜模式 (对照 app 端 RECREATE → Activity 重启后重读 `AppConfig.isNightTheme`)。
     * 菜单其余状态与主题无关，故 RECREATE 只需本方法，不必整套 [reset]。
     */
    fun upNightTheme() {
        // 待实现：平台 actual 重读日/夜模式
    }
    // endregion
}

/**
 * 阅读/搜索菜单色彩配置。
 * 在 E-Ink 模式下成对设置 surface（白底）与 onSurface（深色高对比前景），避免浅色背景与浅色文字组合（白底浅色字）。
 */
data class ReadMenuPalette(
    val surface: Color,
    val onSurface: Color,
    val topSurface: Color = surface,
    val secondaryText: Color = onSurface,
)

@Composable
fun rememberReadMenuPalette(
    immersive: Boolean,
    bgColor: Int,
    textColor: Int,
    hasBgImage: Boolean = false,
): ReadMenuPalette {
    val eInk = LocalEInk.current
    val colors = AppTheme.colors
    return remember(eInk, immersive, bgColor, textColor, hasBgImage, colors) {
        if (eInk) {
            ReadMenuPalette(
                surface = Color.White,
                onSurface = Color(0xDE000000),
                topSurface = Color.White,
                secondaryText = Color(0x99000000),
            )
        } else {
            val surface = if (immersive) Color(bgColor) else colors.bottomBackground
            val onSurface = if (immersive) Color(textColor) else colors.primaryText
            val topSurface = if (hasBgImage) Color.Transparent else surface
            val secondaryText = if (immersive) {
                Color(ColorUtils.withAlpha(ColorUtils.lightenColor(textColor), 0.75f))
            } else {
                onSurface
            }
            ReadMenuPalette(
                surface = surface,
                onSurface = onSurface,
                topSurface = topSurface,
                secondaryText = secondaryText,
            )
        }
    }
}

/**
 * 阅读菜单状态基类：包含各端通用的状态快照（标题/章节/进度条/顶栏勾选/夜间态）与动作分发
 * （onTopMenuAction 的 20+ 项菜单动作、onSourceAction 的 6 项书源动作、基础跳转导航）。
 *
 * 各平台子类仅需覆盖平台特异性逻辑（如沉浸色计算 menuTheme、自绘背景图判定 hasBgImage、
 * 朗读重定位监听与自动翻页控制器）。
 */
open class BaseReadMenuState(
    val navigator: AppNavigator,
    val screenModel: ReaderScreenModel,
) : ReadMenuState {

    override val visibleState = MutableTransitionState(false)
    override var animate: Boolean = true
        protected set
    override val isVisible: Boolean get() = visibleState.currentState || visibleState.targetState
    override val canShowMenu: Boolean get() = true

    override val immersive: Boolean get() = false
    override val bgColor: Int get() = 0
    override val textColor: Int get() = 0
    override val hasBgImage: Boolean get() = false

    override var title: String? by mutableStateOf(null)
        protected set
    override var chapterName: String? by mutableStateOf(null)
        protected set
    override var chapterUrl: String? by mutableStateOf(null)
        protected set
    override var chapterNameVisible: Boolean by mutableStateOf(false)
        protected set
    override var chapterUrlVisible: Boolean by mutableStateOf(false)
        protected set
    override var sourceActionText: String by mutableStateOf("")
        protected set
    override var sourceActionVisible: Boolean by mutableStateOf(false)
        protected set
    override var titleBarAdditionVisible: Boolean by mutableStateOf(true)
        protected set
    override val topMenu: TopMenuState = TopMenuState()

    override var seekMax: Int by mutableStateOf(0)
        protected set
    override var seekValue: Int by mutableStateOf(0)
        protected set
    override var prevEnabled: Boolean by mutableStateOf(false)
        protected set
    override var nextEnabled: Boolean by mutableStateOf(false)
        protected set
    override var isNightTheme: Boolean by mutableStateOf(currentNightTheme())
        protected set
    override var bookProgress: Float by mutableStateOf(0f)
        protected set

    override var chapterProgressText: String by mutableStateOf("—")
        protected set
    override var chapterIndexText: String by mutableStateOf("—")
        protected set

    /** 待执行的收起完成回调 (对照原版 ReadMenu.onMenuOutEnd) */
    private var onMenuOutEnd: (() -> Unit)? = null

    open fun show() {
        animate = !currentEInkMode()
        refresh()
        visibleState.targetState = true
    }

    open fun hide() {
        visibleState.targetState = false
    }

    /**
     * 收起菜单, [onMenuOutEnd] 在收起动画结束后执行 (对照原版 ReadMenu.runMenuOut)。
     *
     * 已收起状态立即执行: MutableTransitionState 在 targetState 已为 false 时重复置值
     * 不触发 onTransitionIdle, 收起态触发的菜单动作拿不到回调。
     * 收起动画进行中早退, 不覆盖先前待执行的回调 (对照原版 isMenuOutAnimating 守卫)。
     */
    override fun runMenuOut(onMenuOutEnd: (() -> Unit)?) {
        if (!visibleState.isIdle && !visibleState.targetState) return
        this.onMenuOutEnd = onMenuOutEnd
        if (!visibleState.isIdle || visibleState.targetState) {
            // 入场中被打断/展开中: 反向滑出, 回调在 onTransitionIdle(false) 执行
            hide()
        } else {
            this.onMenuOutEnd = null
            onMenuOutEnd?.invoke()
        }
    }

    override fun onTransitionIdle(shown: Boolean) {
        if (shown) {
            return
        }
        val onEnd = onMenuOutEnd
        onMenuOutEnd = null
        onEnd?.invoke()
    }

    override fun onBgClick() = runMenuOut()

    override fun onChapterViewClick() {
        val book = screenModel.viewModel.book.value ?: return
        if (book.isLocal) return
        val url = chapterUrl.orEmpty()
        navigator.push(
            AppRoute.WebView(
                url = url,
                sourceKey = book.origin,
                sourceName = book.originName,
            )
        )
    }

    override fun onChapterViewLongClick() = Unit

    override fun onOverflowOpened() {
        screenModel.updateSourceMenu()
    }

    override fun sourceLoginVisible(): Boolean = screenModel.sourceLoginVisible()
    override fun sourcePayVisible(): Boolean = screenModel.sourcePayVisible()

    override fun onSourceAction(action: SourceAction) {
        when (action) {
            SourceAction.LOGIN -> {
                val source = screenModel.viewModel.bookSource.value ?: return
                showSourceLogin(
                    source.getKey(),
                    source,
                    screenModel.currentBook,
                    screenModel.currentChapter,
                )
            }

            SourceAction.EDIT_SOURCE -> {
                val origin = screenModel.viewModel.book.value?.origin ?: return
                navigator.push(AppRoute.BookSourceEdit(origin), RouteResults.BOOK_SOURCE_EDIT)
            }

            SourceAction.DISABLE_SOURCE -> screenModel.viewModel.disableSource()
            SourceAction.CHAPTER_PAY -> screenModel.postDialogEvent(ReaderDialogEvent.ChapterPay)
            SourceAction.SET_SOURCE_VARIABLE -> screenModel.showSourceVariableDialog()
            SourceAction.SET_BOOK_VARIABLE -> screenModel.showBookVariableDialog()
        }
    }

    override fun openBookInfoActivity() {
        screenModel.currentBook?.let {
            navigator.push(AppRoute.BookInfo(it.toRouteRef()), RouteResults.BOOK_INFO)
        }
    }

    override fun supportFinishAfterTransition() {
        navigator.pop()
    }

    override fun onTopMenuAction(action: ReadMenuAction) {
        when (action) {
            // 弹对话框/翻配置前先收菜单, 收起动画播完后再弹 (对照原版各菜单项的 runMenuOut 语义)
            ReadMenuAction.CHANGE_SOURCE,
            ReadMenuAction.BOOK_CHANGE_SOURCE -> {
                runMenuOut {
                    screenModel.postDialogEvent(ReaderDialogEvent.ChangeSource)
                }
            }

            ReadMenuAction.CHAPTER_CHANGE_SOURCE -> {
                runMenuOut {
                    screenModel.postDialogEvent(ReaderDialogEvent.ChangeChapterSource)
                }
            }

            ReadMenuAction.REFRESH_DUR -> screenModel.viewModel.refreshCurrentChapter()
            // 对照原版 addBookmark: 弹书签对话框, 不收菜单 (对话框盖在菜单上)
            ReadMenuAction.ADD_BOOKMARK -> {
                val book = screenModel.viewModel.book.value ?: return
                val page = screenModel.viewModel.curTextPage.value
                val bookmark = Bookmark(bookName = book.name, bookAuthor = book.author).apply {
                    chapterIndex = screenModel.viewModel.durChapterIndex.value
                    chapterPos = screenModel.viewModel.durChapterPos.value
                    chapterName = page?.title ?: screenModel.currentChapter?.title ?: ""
                    bookText = page?.text?.trim() ?: ""
                }
                screenModel.postDialogEvent(ReaderDialogEvent.AddBookmark(bookmark))
            }

            ReadMenuAction.EDIT_CONTENT -> screenModel.postDialogEvent(ReaderDialogEvent.EditContent)
            ReadMenuAction.LOG -> screenModel.postDialogEvent(ReaderDialogEvent.Log)

            ReadMenuAction.REFRESH_AFTER -> {
                val book = screenModel.viewModel.book.value ?: return
                screenModel.viewModel.refreshContentAfter(book)
            }

            ReadMenuAction.REFRESH_ALL -> screenModel.viewModel.refreshContentAll()
            ReadMenuAction.DOWNLOAD -> screenModel.postDialogEvent(ReaderDialogEvent.Download)
            ReadMenuAction.TOC_REGEX -> navigator.push(AppRoute.TxtTocRule)
            ReadMenuAction.SET_CHARSET -> screenModel.postDialogEvent(ReaderDialogEvent.SetCharset)

            ReadMenuAction.ENABLE_REPLACE -> {
                screenModel.viewModel.toggleUseReplaceRule()
                upTopMenu()
            }
            ReadMenuAction.KEYWORD_HIGHLIGHT -> navigator.push(
                AppRoute.KeywordHighlight(book = screenModel.viewModel.book.value?.toRouteRef())
            )
            ReadMenuAction.SAME_TITLE_REMOVED -> screenModel.viewModel.reverseRemoveSameTitle()
            ReadMenuAction.RE_SEGMENT -> {
                screenModel.viewModel.toggleReSegment()
                upTopMenu()
            }
            ReadMenuAction.IMAGE_STYLE -> screenModel.postDialogEvent(ReaderDialogEvent.ImageStyle)
            ReadMenuAction.UPDATE_TOC -> screenModel.viewModel.updateToc()
            ReadMenuAction.SYNC_PROGRESS -> screenModel.viewModel.syncProgressManual(
                uploadSuccessAction = { Toasters.get().toast(syncGetString("upload_book_success")) },
                syncSuccessAction = { Toasters.get().toast(syncGetString("sync_book_progress_success")) },
            )

            ReadMenuAction.REVIEW -> screenModel.currentBook?.let { book ->
                val chapter = screenModel.currentChapter
                if (!PlatformCapabilityProviders.get().showReviewListDialog(book, chapter, 0)) {
                    Toasters.get().toast("暂不支持段评")
                }
            }

            ReadMenuAction.DEL_RUBY_TAG -> {
                screenModel.viewModel.toggleDelTag(Book.rubyTag)
                upTopMenu()
            }

            ReadMenuAction.DEL_H_TAG -> {
                screenModel.viewModel.toggleDelTag(Book.hTag)
                upTopMenu()
            }
            else -> Unit
        }
    }

    override fun onSeekDragStart() = Unit

    override fun onSeekStop(progress: Int) {
        // page 直接跳页 / chapter 首次拖动弹确认 (确认框由 ReaderRoute 渲染 ChapterJumpConfirm,
        // 确认标志/进度快照在 ReaderScreenModel.onSeekStop 内, 对照原版 onStopTrackingTouch)
        screenModel.onSeekStop(progress)
    }

    override fun clickSearch() {
        // 对照原版 fabSearch 的 `runMenuOut { callBack.openSearchActivity(null) }`：收起动画播完
        // 再开搜索页。漏收时 menuState.isVisible 恒为 true，搜索页回传后搜索菜单与仍展开的
        // 阅读菜单同屏叠加，且方向键/音量键翻页被 isVisible 判定禁掉
        runMenuOut {
            val initialResults = screenModel.searchResultList
                ?.takeIf { results -> results.firstOrNull()?.query == screenModel.searchContentQuery }
            navigator.push(
                AppRoute.SearchContent(
                    index = screenModel.searchResultIndex,
                    word = screenModel.searchContentQuery.takeIf { it.isNotEmpty() },
                    initialResults = initialResults,
                    book = screenModel.viewModel.book.value?.toRouteRef(),
                ),
                resultKey = RouteResults.SEARCH_CONTENT,
            )
        }
    }

    override fun clickReplaceRule() {
        runMenuOut {
            screenModel.postDialogEvent(ReaderDialogEvent.EffectiveReplaces)
        }
    }

    override fun clickNightTheme() {
        val newNight = !isNightTheme
        ThemeConfigProviders.get().applyDayNight(newNight)
        // 以参数为准立即置位（applyDayNight 内部发的 RECREATE 会驱动画布/页眉页脚重建，
        // 不额外发 ReadConfigChange —— 切日/夜只换颜色分支，排版参数没变）
        isNightTheme = newNight
    }

    override fun clickPre() {
        screenModel.viewModel.moveToPrevChapter()
    }

    override fun clickNext() {
        screenModel.viewModel.moveToNextChapter()
    }

    override fun clickCatalog() {
        runMenuOut {
            screenModel.postDialogEvent(ReaderDialogEvent.Toc)
        }
    }

    override fun clickReadAloud() = Unit

    override fun longClickReadAloud() {
        screenModel.postDialogEvent(ReaderDialogEvent.ReadAloud)
    }

    override fun clickSetting() {
        runMenuOut {
            screenModel.postDialogEvent(ReaderDialogEvent.MoreConfig)
        }
    }

    override fun onRefresh() {
        screenModel.viewModel.refreshCurrentChapter()
    }

    protected open fun upSourceAction() {
        val book = screenModel.viewModel.book.value
        val source = screenModel.viewModel.bookSource.value
        sourceActionText = source?.bookSourceName ?: syncGetString("book_source")
        sourceActionVisible = book?.let { !it.isLocal } ?: false
    }

    protected open fun upTopMenu() {
        val book = screenModel.viewModel.book.value ?: return
        topMenu.onLine = !book.isLocal
        topMenu.isLocalTxt = book.isLocalTxt
        topMenu.isEpub = book.isEpub
        topMenu.enableReplaceChecked = book.getUseReplaceRule()
        topMenu.reSegmentChecked = book.config.reSegment
        topMenu.delRubyChecked = book.config.delTag and Book.rubyTag == Book.rubyTag
        topMenu.delHChecked = book.config.delTag and Book.hTag == Book.hTag
        topMenu.sameTitleRemovedChecked =
            screenModel.viewModel.curTextChapter.value?.sameTitleRemoved == true
        topMenu.syncProgressVisible = !book.isNotShelf && AppWebDavShared.isOk
    }

    protected open fun upMenuView() {
        val book = screenModel.viewModel.book.value
        title = book?.name
        val curChapter = screenModel.currentChapter
        chapterName = curChapter?.title
        chapterUrl = book?.let { curChapter?.getAbsoluteURL(it) }
        chapterNameVisible = !chapterName.isNullOrEmpty()
        chapterUrlVisible = !chapterUrl.isNullOrEmpty() && book?.isLocal == false
        prevEnabled = screenModel.viewModel.canMoveToPrevChapter()
        nextEnabled = screenModel.viewModel.canMoveToNextChapter()
        upProgressText()
    }

    override fun refresh() {
        upNightTheme()
        upTopMenu()
        upMenuView()
        upSourceAction()
    }

    override fun upSeekBar() {
        seekMax = (screenModel.viewModel.simulatedChapterSize - 1).coerceAtLeast(0)
        seekValue = screenModel.viewModel.durChapterIndex.value
        upProgressText()
    }

    /** 同步底栏/进度页的位置与百分比文案（翻页、开章、拖动进度条后调用） */
    protected fun upProgressText() {
        chapterIndexText = "${seekValue + 1} / ${seekMax + 1}"
        val page = screenModel.viewModel.curTextPage.value
        chapterProgressText = if (page != null && page.pageSize > 0) {
            "${((page.index + 1) * 100 / page.pageSize).coerceIn(0, 100)}%"
        } else {
            "—"
        }
        bookProgress = if (page != null && page.chapterSize > 0) {
            val within = if (page.pageSize > 0) (page.index + 1f) / page.pageSize else 0f
            ((page.chapterIndex + within) / page.chapterSize).coerceIn(0f, 1f)
        } else {
            0f
        }
    }

    /** 全书进度条落位：按章节比例折算目标章，落到章首 */
    override fun seekBookProgress(fraction: Float) {
        val page = screenModel.viewModel.curTextPage.value ?: return
        val total = page.chapterSize
        if (total <= 0) return
        val target = (fraction.coerceIn(0f, 1f) * total).toInt().coerceIn(0, total - 1)
        if (target == page.chapterIndex) return
        screenModel.openChapter(target, 0)
    }

    override fun bookmarkFlow(): Flow<List<Bookmark>>? = screenModel.bookmarkFlow()

    override fun deleteBookmark(bookmark: Bookmark) = screenModel.deleteBookmark(bookmark)

    override fun jumpToBookmark(bookmark: Bookmark) {
        screenModel.jumpToBookmark(bookmark)
        hide()
    }

    override fun clickChapterStart() = screenModel.jumpToChapterStart()

    override fun clickChapterEnd() = screenModel.jumpToChapterEnd()

    override fun reset() {
        upNightTheme()
        upTopMenu()
        upMenuView()
    }

    override fun upNightTheme() {
        isNightTheme = currentNightTheme()
    }
}

/**
 * 阅读菜单 Overlay：出入场动画语义对齐原 anim_readbook_top_in/out(200ms)、bottom_in(150ms)/out(200ms)，
 * 无动画(E-Ink)时 snap。菜单完全隐藏时除过渡簿记外零组合。
 */
@Composable
fun ReadMenuOverlay(state: ReadMenuState) {
    val vs = state.visibleState
    LaunchedEffect(vs.isIdle, vs.currentState) {
        if (vs.isIdle) state.onTransitionIdle(vs.currentState)
    }
    // 底栏当前面板：0 操作坞 / 1 排版 / 2 进度 / 3 书签；菜单收起后复位到操作坞
    var panel by remember { mutableStateOf(ReaderPanel.DOCK) }
    LaunchedEffect(vs.currentState) {
        if (!vs.currentState) panel = ReaderPanel.DOCK
    }
    if (!vs.currentState && !vs.targetState) {
        return
    }
    // 顶层覆盖物返回拦截: 阅读菜单可见期间 (含出入场动画期) 返回键 (桌面端 ESC /
    // 统一链) 优先收起菜单, 不落到页面/出栈。对齐原版语义: 菜单是自绘覆盖层,
    // 原版靠点击背景收起; 桌面端 ESC 等价返回键, 用户拍板"无对话框时 ESC 关阅读菜单".
    // 用 onBgClick (菜单背景点击同款收起路径, 含 bgClickEnabled 判断)。
    BackLayerHandler(enabled = true) { state.onBgClick() }
    fun spec(duration: Int): FiniteAnimationSpec<IntOffset> =
        if (state.animate) tween(duration, easing = AccelerateDecelerateEasing) else snap()
    // 出入场动画期间整层不派生输入 (原版 menuOutListener.onAnimationStart 先置
    // isMenuOutAnimating 并摘掉 vwMenuBg 点击监听, 动画结束才装回)
    Box(Modifier.fillMaxSize().blockInputWhile(!vs.isIdle)) {
        // 原 vw_menu_bg：菜单期间全屏拦截触摸，点击(在允许时)收起菜单
        Box(
            Modifier
                .fillMaxSize()
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ) { state.onBgClick() }
        )
        AnimatedVisibility(
            visibleState = vs,
            modifier = Modifier.align(Alignment.TopCenter),
            enter = slideInVertically(spec(200)) { -it },
            exit = slideOutVertically(spec(200)) { -it },
        ) {
            ReadMenuTopBar(
                state = state,
                onOpenPanel = { panel = ReaderPanel.STYLE },
            )
        }
        AnimatedVisibility(
            visibleState = vs,
            modifier = Modifier.align(Alignment.BottomCenter),
            enter = slideInVertically(spec(150)) { it },
            exit = slideOutVertically(spec(200)) { it },
        ) {
            ReadMenuBottom(
                state = state,
                panel = panel,
                onPanelChange = { panel = it },
            )
        }
    }
}

@Composable
private fun ReadMenuTopBar(
    state: ReadMenuState,
    onOpenPanel: () -> Unit,
) {
    val eInk = LocalEInk.current
    // hasBgImage 四端经 ReadMenuState 桥接同源判定 (shared hasBgImageByPath)。
    // 窗口背景图语义 (原版顶栏透明) 优先于阅读背景取色, 保护原版行为;
    // 配色经 [rememberReadMenuPalette] 成对解析, E-Ink 下成对固定白底与深色前景, 避免白底浅色字。
    val palette = rememberReadMenuPalette(
        immersive = state.immersive,
        bgColor = state.bgColor,
        textColor = state.textColor,
        hasBgImage = state.hasBgImage,
    )
    val topBg = palette.topSurface
    val topText = palette.onSurface
    val chapterText = palette.secondaryText
    Column(
        Modifier
            .fillMaxWidth()
            .background(topBg)
            // 浮层顶栏逐帧跟随状态栏 insets (对齐原版 TitleBar insets listener 语义):
            // 菜单滑入与系统栏显隐动画并行时 padding 平滑增长, 无离散跳变。
            .platformStatusBarPadding()
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .heightIn(min = DesignTokens.viewHeightXl),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = { state.supportFinishAfterTransition() }) {
                Icon(
                    painter = painterResource(Res.drawable.ic_arrow_back),
                    contentDescription = null,
                    tint = topText,
                )
            }
            // 章节名为顶栏主标题；点按进目录。书名退为副标题，避免正文页顶部再出现入口堆叠。
            Column(
                Modifier
                    .weight(1f)
                    .clickable { state.clickCatalog() }
                    .padding(horizontal = DesignTokens.spacingMd),
            ) {
                Text(
                    text = state.chapterName?.takeIf { it.isNotBlank() }
                        ?: state.title.orEmpty(),
                    color = topText,
                    style = LanghuanType.sectionTitle.copy(fontSize = 18.sp),
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (!state.title.isNullOrBlank() && state.title != state.chapterName) {
                    Text(
                        text = state.title.orEmpty(),
                        color = chapterText,
                        fontSize = 12.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            TopBarActionIcon(
                iconKey = "ic_exchange",
                descKey = "change_source",
                tint = topText,
                onClick = { state.clickChangeSource() },
                onLongClick = { state.longClickChangeSource() },
            )
            TopBarActionIcon(
                iconKey = "ic_read_aloud",
                descKey = "read_aloud",
                tint = topText,
                onClick = { state.runMenuOut { state.clickReadAloud() } },
                onLongClick = { state.longClickReadAloud() },
            )
            if (state.topMenu.isLocalTxt) {
                TopBarActionIcon(
                    iconKey = "ic_translate",
                    descKey = "set_charset",
                    tint = topText,
                    onClick = { state.onTopMenuAction(ReadMenuAction.SET_CHARSET) },
                )
            }
            // Aa：展开底栏的排版/更多面板
            Box(
                Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .clickable(onClick = onOpenPanel),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Aa",
                    color = topText,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
        if (eInk) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(rememberColor("divider"))
            )
        }
    }
}

/** 顶栏图标动作，长按弹出子菜单(原 iconItemOnLongClick + PopupMenu) */
@Composable
private fun TopBarActionIcon(
    iconKey: String,
    descKey: String,
    tint: Color,
    onClick: () -> Unit,
    longPressMenu: List<Pair<String, ReadMenuAction>>? = null,
    onLongClick: (() -> Unit)? = null,
    onAction: ((ReadMenuAction) -> Unit)? = null,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Box(
            Modifier
                .size(48.dp)
                .clip(CircleShape)
                .combinedClickable(
                    onClick = onClick,
                    onLongClick = onLongClick
                        ?: longPressMenu?.let { { expanded = true } },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = rememberPainter(iconKey),
                contentDescription = rememberString(descKey),
                tint = tint,
                modifier = Modifier.size(24.dp),
            )
        }
        if (longPressMenu != null && onAction != null) {
            AppDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                longPressMenu.forEach { (textKey, action) ->
                    DropdownMenuItem(
                        onClick = {
                            expanded = false
                            onAction(action)
                        },
                    ) {
                        Text(rememberString(textKey), color = AppTheme.colors.primaryText)
                    }
                }
            }
        }
    }
}

private const val MIN_READER_FONT_SIZE = 17
private const val MAX_READER_FONT_SIZE = 40
// 恢复默认排版时回填的字段默认值（对齐 ReadBookConfig 数据类默认值）
private const val DEFAULT_TEXT_SIZE = 17
private const val DEFAULT_LINE_SPACING = 15
private const val DEFAULT_PARAGRAPH_SPACING = 6

/** 阅读纸色档位：只改当前样式的背景与文字色，并同步日/夜模式。 */
private data class ReaderPaperTone(
    val labelKey: String,
    val bg: String,
    val text: String,
    val night: Boolean,
)

private val readerPaperTones = listOf(
    ReaderPaperTone("paper_xuan", "#F5EFE3", "#2B2419", night = false),
    ReaderPaperTone("paper_qing", "#DDE7DF", "#243027", night = false),
    ReaderPaperTone("paper_ink", "#121514", "#EFE8DA", night = true),
)

private fun applyReaderPaperTone(tone: ReaderPaperTone) {
    val config = ReadBookConfigProviders.get()
    // 纸色是阅读页局部选择：不改全局日/夜模式，两套明暗字段都写同一纸色
    config.config.setDayNightPaper(
        bg = tone.bg,
        text = tone.text,
        darkStatusIcons = !tone.night,
    )
    config.save()
    ReadBookEvents.postConfig(
        listOf(
            ReadConfigChange.BG,
            ReadConfigChange.STYLE,
            ReadConfigChange.SYSTEM_UI,
            ReadConfigChange.LOAD_CONTENT,
        )
    )
}

/** 阅读底栏面板页：操作坞 / 排版 / 更多 */
private enum class ReaderPanel { DOCK, STYLE, MORE }

@Composable
private fun ReadMenuBottom(
    state: ReadMenuState,
    panel: ReaderPanel,
    onPanelChange: (ReaderPanel) -> Unit,
) {
    val eInk = LocalEInk.current
    // 底栏背景/文字: 沉浸式(纯色阅读背景)用阅读背景色/阅读文字色; 图片背景回落主题色;
    // E-Ink 模式统一由 [rememberReadMenuPalette] 成对固定为白底黑字, 消除白底浅色字。
    val palette = rememberReadMenuPalette(
        immersive = state.immersive,
        bgColor = state.bgColor,
        textColor = state.textColor,
    )
    val bg = palette.surface
    val text = palette.onSurface
    // 底栏可能落在深色纸/图片上，而 AppTheme 的强调色是按页面白/近黑校正的。
    // 这里再按底栏自身明暗校正一次，保证页签、胶囊、进度数字在墨夜纸上也读得清。
    val panelDark = bg.luminance() < .5f
    val panelAccent =
        if (eInk) text else langhuanReadable(AppTheme.colors.accentFill, panelDark)
    // 章节进度用辅助色；E-Ink 下退回正文色，避免黑白模式出现彩色数字
    val progressColor =
        if (eInk) text else langhuanReadable(AppTheme.colors.companion, panelDark)

    // 4dp 阴影向上: 默认 shadow 光源在上方, 先翻转 180° 加阴影再翻回,
    // 阴影即投射到屏幕底部外侧的上方。面板内容随当前页切换，外壳只此一份。
    Column(
        Modifier
            .fillMaxWidth()
            .graphicsLayer { rotationX = 180f }
            .shadow(4.dp, RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
            .graphicsLayer { rotationX = 180f }
            .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
            .background(if (eInk) Color.White else bg)
            // 浮层底栏逐帧跟随导航栏 insets (与顶栏 platformStatusBarPadding 同理)
            .platformNavigationBarPadding(),
    ) {
        ReaderPanelHandle(text)
        if (eInk) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(rememberColor("divider"))
            )
        }
        if (panel != ReaderPanel.DOCK) {
            ReaderPanelTabs(panel, text, panelAccent, onPanelChange)
        }
        when (panel) {
            ReaderPanel.DOCK -> ReaderDockContent(state, text)
            ReaderPanel.STYLE -> ReaderStylePanel(state, text, eInk, progressColor, panelAccent)
            ReaderPanel.MORE -> ReaderMorePanel(state, text, panelAccent)
        }
    }
}

/** 底栏把手：琅嬛阁的圆角面板从一道 36x4 的短横开始 */
@Composable
private fun ReaderPanelHandle(text: Color) {
    Box(
        Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 2.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .width(36.dp)
                .height(4.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(text.copy(alpha = .22f))
        )
    }
}

/** 面板页签：排版 / 更多；再点当前页签或「收起」回操作坞 */
@Composable
private fun ReaderPanelTabs(
    panel: ReaderPanel,
    text: Color,
    accent: Color,
    onPanelChange: (ReaderPanel) -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = DesignTokens.spacingLg, vertical = DesignTokens.spacingXs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ReaderPanelTab(rememberString("reader_panel_style"), panel == ReaderPanel.STYLE, text, accent) {
            onPanelChange(if (panel == ReaderPanel.STYLE) ReaderPanel.DOCK else ReaderPanel.STYLE)
        }
        ReaderPanelTab(rememberString("reader_panel_more"), panel == ReaderPanel.MORE, text, accent) {
            onPanelChange(if (panel == ReaderPanel.MORE) ReaderPanel.DOCK else ReaderPanel.MORE)
        }
        Spacer(Modifier.weight(1f))
        Text(
            text = rememberString("reader_panel_collapse"),
            color = text.copy(alpha = .55f),
            fontSize = 12.sp,
            modifier = Modifier
                .clip(RoundedCornerShape(12.dp))
                .clickable { onPanelChange(ReaderPanel.DOCK) }
                .padding(horizontal = 10.dp, vertical = 4.dp),
        )
    }
}

@Composable
private fun ReaderPanelTab(
    label: String,
    selected: Boolean,
    tint: Color,
    accent: Color,
    onClick: () -> Unit,
) {
    Text(
        text = label,
        color = if (selected) accent else tint.copy(alpha = .6f),
        fontSize = 13.sp,
        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(
                if (selected) accent.copy(alpha = .12f) else Color.Transparent
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 6.dp),
    )
}

/**
 * 操作坞：上方一行全书进度，下方一行三格（上一章 / 目录 x/y / 下一章）。
 *
 * 搜索、换源、专注都收进顶栏或「更多」，贴近拇指的位置只留翻页与目录。
 */
@Composable
private fun ReaderDockContent(state: ReadMenuState, text: Color) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(
                start = DesignTokens.spacingLg,
                end = DesignTokens.spacingLg,
                top = DesignTokens.spacingXs,
            ),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AppSlider(
            value = (state.bookProgress * PROGRESS_STEPS).roundToInt(),
            max = PROGRESS_STEPS,
            color = text.copy(alpha = .72f),
            trackColor = text.copy(alpha = .16f),
            modifier = Modifier.weight(1f),
            onValueChangeFinished = { state.seekBookProgress(it.toFloat() / PROGRESS_STEPS) },
        )
        Spacer(Modifier.width(DesignTokens.spacingDefault))
        Text(
            text = "${(state.bookProgress * 100).roundToInt()}%",
            color = text.copy(alpha = .6f),
            fontSize = 11.sp,
        )
    }
    Row(Modifier.fillMaxWidth()) {
        BottomMenuItem(
            iconKey = "ic_skip_previous",
            labelKey = "previous_chapter",
            tint = if (state.prevEnabled) text else text.copy(alpha = .3f),
            modifier = Modifier.weight(1f),
        ) { if (state.prevEnabled) state.clickPre() }
        BottomMenuItem(
            iconKey = "ic_toc",
            labelKey = "chapter_list",
            tint = text,
            subLabel = state.chapterIndexText,
            modifier = Modifier.weight(1f),
        ) { state.clickCatalog() }
        BottomMenuItem(
            iconKey = "ic_skip_next",
            labelKey = "next_chapter",
            tint = if (state.nextEnabled) text else text.copy(alpha = .3f),
            modifier = Modifier.weight(1f),
        ) { if (state.nextEnabled) state.clickNext() }
    }
}

@Composable
private fun ReaderPanelAction(
    label: String,
    text: Color,
    horizontalPadding: Dp = 16.dp,
    verticalPadding: Dp = 8.dp,
    onClick: () -> Unit,
) {
    Text(
        text = label,
        color = text,
        fontSize = 13.sp,
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(text.copy(alpha = .08f))
            .clickable(onClick = onClick)
            .padding(horizontal = horizontalPadding, vertical = verticalPadding),
    )
}

/**
 * 面板「更多」页：低频动作 + 整本书相关的开关。
 *
 * 第一行是查找正文 / 专注模式 / 添加书签；其下是本书书签列表（点跳转，右端删除）；
 * 再往下是共用布局、朗读跟随两个开关，最后一行是设置入口。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ReaderMorePanel(state: ReadMenuState, text: Color, accent: Color) {
    val readConfig = ReadBookConfigProviders.get()
    var shareLayout by remember { mutableStateOf(readConfig.shareLayout) }
    val bookmarks by remember(state) {
        state.bookmarkFlow() ?: flowOf(emptyList())
    }.collectAsState(emptyList())

    Column(
        Modifier
            .fillMaxWidth()
            .heightIn(max = 420.dp)
            .verticalScroll(rememberScrollState()),
    ) {
        FlowRow(
            Modifier
                .fillMaxWidth()
                .padding(
                    horizontal = DesignTokens.spacingLg,
                    vertical = DesignTokens.spacingDefault,
                ),
            horizontalArrangement = Arrangement.spacedBy(DesignTokens.spacingDefault),
            verticalArrangement = Arrangement.spacedBy(DesignTokens.spacingXs),
        ) {
            ReaderPanelAction(rememberString("search_content"), text, horizontalPadding = 12.dp) {
                state.clickSearch()
            }
            ReaderPanelAction(
                label = rememberString(if (readerFocusMode) "reader_focus_exit" else "reader_focus"),
                text = text,
                horizontalPadding = 12.dp,
            ) {
                if (readerFocusMode) {
                    readerFocusMode = false
                } else {
                    readerFocusMode = true
                    state.runMenuOut()
                }
            }
            ReaderPanelAction(rememberString("bookmark_add"), text, horizontalPadding = 12.dp) {
                state.addBookmarkHere()
            }
        }

        if (bookmarks.isEmpty()) {
            Text(
                text = rememberString("reader_bookmark_empty"),
                color = text.copy(alpha = .55f),
                fontSize = 12.sp,
                modifier = Modifier.padding(
                    horizontal = DesignTokens.spacingLg,
                    vertical = DesignTokens.spacingDefault,
                ),
            )
        } else {
            bookmarks.forEach { bookmark ->
                val fallbackChapter = rememberString(
                    "reader_chapter_fallback",
                    bookmark.chapterIndex + 1,
                )
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clickable { state.jumpToBookmark(bookmark) }
                        .padding(horizontal = DesignTokens.spacingLg, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(
                            text = bookmark.chapterName.ifBlank { fallbackChapter },
                            color = text,
                            fontSize = 14.sp,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        val preview = bookmark.bookText.trim().take(40)
                        if (preview.isNotEmpty()) {
                            Text(
                                text = preview,
                                color = text.copy(alpha = .55f),
                                fontSize = 11.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                    Text(
                        text = rememberString("delete"),
                        color = accent,
                        fontSize = 12.sp,
                        modifier = Modifier
                            .clip(RoundedCornerShape(12.dp))
                            .clickable { state.deleteBookmark(bookmark) }
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                    )
                }
            }
        }

        ReaderSwitchRow(
            label = rememberString("share_layout"),
            checked = shareLayout,
            text = text,
        ) { checked ->
            shareLayout = checked
            readConfig.shareLayout = checked
            readConfig.save()
            // 共用布局开关切换 config 来源 (shareConfig ↔ durConfig),
            // 生效 pageAnim 可能随之变化, 需重建翻页委托
            ReadBookEvents.postConfig(
                listOf(
                    ReadConfigChange.BG,
                    ReadConfigChange.STYLE,
                    ReadConfigChange.PAGE_ANIM,
                    ReadConfigChange.LOAD_CONTENT,
                )
            )
        }
        ReaderSwitchRow(
            label = rememberString("reader_follow_aloud"),
            checked = readerFollowAloud,
            text = text,
        ) { readerFollowAloud = it }

        Row(
            Modifier
                .fillMaxWidth()
                .padding(
                    horizontal = DesignTokens.spacingLg,
                    vertical = DesignTokens.spacingDefault,
                ),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ReaderPanelAction(rememberString("setting"), text) { state.clickSetting() }
        }
    }
}

/**
 * 面板「排版」页：
 *
 * 1. 上半：四道带数值的滑条（字号 / 字距 / 行距 / 段距），单次调节即生效；
 * 2. 其下一排二级胶囊（字重 / 字体 / 缩进 / 简繁 / 版面），放不下的项收进各自子弹窗；
 * 3. 背景：宣纸/青笺/墨夜三张拟物纸样 + 自定义；
 * 4. 翻页方式独立成三态（滚动 / 覆盖 / 无动画）；
 * 5. 本章进度压成一行，底部是恢复默认排版。
 *
 * 单列布局，整页可滚动。主题色、书签、共用布局与朗读跟随都收进「更多」。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ReaderStylePanel(
    state: ReadMenuState,
    text: Color,
    eInk: Boolean,
    progressColor: Color,
    accent: Color,
) {
    val readConfig = ReadBookConfigProviders.get()
    // 面板内即时状态：点按后先更新本地值让面板立刻响应，再写配置并通知重排/重建翻页委托。
    var fontSize by remember { mutableIntStateOf(readConfig.textSize) }
    var letterSpacing by remember {
        mutableIntStateOf((readConfig.letterSpacing * 100).toInt() + 50)
    }
    var lineSpacing by remember { mutableIntStateOf(readConfig.lineSpacingExtra) }
    var paragraphSpacing by remember { mutableIntStateOf(readConfig.paragraphSpacing) }
    var pageAnim by remember { mutableIntStateOf(readConfig.pageAnim) }
    var paperBg by remember { mutableStateOf(readConfig.config.curBgStr()) }

    var showWeight by remember { mutableStateOf(false) }
    var showIndent by remember { mutableStateOf(false) }
    var showFont by remember { mutableStateOf(false) }
    var showConverter by remember { mutableStateOf(false) }
    var showLayout by remember { mutableStateOf(false) }
    var showBgText by remember { mutableStateOf(false) }

    val weightNames = stringArrayResource(Res.array.text_font_weight)
    val indentNames = stringArrayResource(Res.array.indent)

    fun postConfig(vararg changes: ReadConfigChange) {
        ReadBookEvents.postConfig(changes.toList())
    }

    fun applyFontSize(value: Int) {
        val next = value.coerceIn(MIN_READER_FONT_SIZE, MAX_READER_FONT_SIZE)
        if (next == fontSize) return
        fontSize = next
        readConfig.textSize = next
        readConfig.save()
        postConfig(ReadConfigChange.CHAPTER_STYLE, ReadConfigChange.LOAD_CONTENT)
    }

    fun applyLetterSpacing(value: Int) {
        if (value == letterSpacing) return
        letterSpacing = value
        readConfig.letterSpacing = (value - 50) / 100f
        readConfig.save()
        postConfig(ReadConfigChange.CHAPTER_STYLE, ReadConfigChange.LOAD_CONTENT)
    }

    fun applyLineSpacing(value: Int) {
        if (value == lineSpacing) return
        lineSpacing = value
        readConfig.lineSpacingExtra = value
        readConfig.save()
        postConfig(ReadConfigChange.CHAPTER_STYLE, ReadConfigChange.LOAD_CONTENT)
    }

    fun applyParagraphSpacing(value: Int) {
        if (value == paragraphSpacing) return
        paragraphSpacing = value
        readConfig.paragraphSpacing = value
        readConfig.save()
        postConfig(ReadConfigChange.CHAPTER_STYLE, ReadConfigChange.LOAD_CONTENT)
    }

    fun applyPageAnim(value: Int) {
        if (value == pageAnim) return
        pageAnim = value
        readConfig.pageAnim = value
        readConfig.save()
        postConfig(ReadConfigChange.PAGE_ANIM, ReadConfigChange.LOAD_CONTENT)
    }

    /** 恢复默认排版：只重置字号与间距类字段，背景、字体文件与翻页方式保持不变 */
    fun resetStyle() {
        fontSize = DEFAULT_TEXT_SIZE
        letterSpacing = 50
        lineSpacing = DEFAULT_LINE_SPACING
        paragraphSpacing = DEFAULT_PARAGRAPH_SPACING
        readConfig.textSize = DEFAULT_TEXT_SIZE
        readConfig.letterSpacing = 0f
        readConfig.lineSpacingExtra = DEFAULT_LINE_SPACING
        readConfig.paragraphSpacing = DEFAULT_PARAGRAPH_SPACING
        readConfig.textBold = 0
        readConfig.paragraphIndent = "　　"
        readConfig.save()
        postConfig(
            ReadConfigChange.CHAPTER_STYLE,
            ReadConfigChange.INVALIDATE_TEXT_PAGE,
            ReadConfigChange.LOAD_CONTENT,
        )
    }

    Column(
        Modifier
            .fillMaxWidth()
            .heightIn(max = 420.dp)
            .verticalScroll(rememberScrollState()),
    ) {
        ReaderStyleSectionLabel(
            text = rememberString("reader_section_typography"),
            color = text,
            modifier = Modifier.padding(top = DesignTokens.spacingDefault),
        )
        AppDetailSeekBar(
            title = rememberString("text_size"),
            value = fontSize,
            max = MAX_READER_FONT_SIZE,
            min = MIN_READER_FONT_SIZE,
            textColor = text,
            modifier = Modifier
                .height(DesignTokens.viewHeightSmall)
                .padding(horizontal = DesignTokens.spacingLg),
            onChanged = ::applyFontSize,
        )
        AppDetailSeekBar(
            title = rememberString("text_letter_spacing"),
            value = letterSpacing,
            max = 100,
            min = 30,
            textColor = text,
            valueFormat = { ((it - 50) / 100f).toString() },
            modifier = Modifier
                .height(DesignTokens.viewHeightSmall)
                .padding(horizontal = DesignTokens.spacingLg),
            onChanged = ::applyLetterSpacing,
        )
        AppDetailSeekBar(
            title = rememberString("line_size"),
            value = lineSpacing,
            max = 24,
            min = 8,
            textColor = text,
            valueFormat = { "${it / 10f} 倍" },
            modifier = Modifier
                .height(DesignTokens.viewHeightSmall)
                .padding(horizontal = DesignTokens.spacingLg),
            onChanged = ::applyLineSpacing,
        )
        AppDetailSeekBar(
            title = rememberString("paragraph_size"),
            value = paragraphSpacing,
            max = 20,
            min = 0,
            textColor = text,
            valueFormat = { (it / 10f).toString() },
            modifier = Modifier
                .height(DesignTokens.viewHeightSmall)
                .padding(horizontal = DesignTokens.spacingLg),
            onChanged = ::applyParagraphSpacing,
        )
        // 二级入口：字重 / 字体 / 缩进 / 简繁 / 版面。
        // 高频的四道滑块留在面板上，低频项收进这排胶囊，点开各自的子弹窗。
        FlowRow(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = DesignTokens.spacingLg, vertical = DesignTokens.spacingXs),
            horizontalArrangement = Arrangement.spacedBy(DesignTokens.spacingDefault),
            verticalArrangement = Arrangement.spacedBy(DesignTokens.spacingXs),
        ) {
            ReaderPanelAction(
                rememberString("font_weight_text"), text,
                horizontalPadding = 12.dp, verticalPadding = 6.dp,
            ) { showWeight = true }
            ReaderPanelAction(
                rememberString("text_font"), text,
                horizontalPadding = 12.dp, verticalPadding = 6.dp,
            ) { showFont = true }
            ReaderPanelAction(
                rememberString("text_indent"), text,
                horizontalPadding = 12.dp, verticalPadding = 6.dp,
            ) { showIndent = true }
            ReaderPanelAction(
                rememberString("chinese_converter"), text,
                horizontalPadding = 12.dp, verticalPadding = 6.dp,
            ) { showConverter = true }
            ReaderPanelAction(
                rememberString("reader_layout"), text,
                horizontalPadding = 12.dp, verticalPadding = 6.dp,
            ) { showLayout = true }
        }
        if (!eInk) {
            // 背景：宣纸 / 青笺 / 墨夜三张拟物纸样 + 自定义
            ReaderStyleSectionLabel(
                text = rememberString("reader_section_paper"),
                color = text,
                modifier = Modifier.padding(top = DesignTokens.spacingDefault),
            )
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = DesignTokens.spacingLg, vertical = DesignTokens.spacingXs),
                horizontalArrangement = Arrangement.spacedBy(DesignTokens.spacingDefault),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                readerPaperTones.forEach { tone ->
                    val selected = paperBg.equals(tone.bg, ignoreCase = true)
                    ReaderPaperCard(
                        label = rememberString(tone.labelKey),
                        background = Color(ColorUtils.parseColor(tone.bg)),
                        ink = Color(ColorUtils.parseColor(tone.text)),
                        selected = selected,
                        panelText = text,
                        accent = accent,
                    ) {
                        applyReaderPaperTone(tone)
                        paperBg = tone.bg
                    }
                }
                ReaderPaperCard(
                    label = rememberString("reader_custom_bg"),
                    background = text.copy(alpha = .06f),
                    ink = text,
                    selected = false,
                    panelText = text,
                    accent = accent,
                ) { showBgText = true }
            }
            // 翻页方式：滚动 / 覆盖 / 无动画。滑动、仿真等旧值在 UI 上按覆盖显示。
            ReaderStyleSectionLabel(
                text = rememberString("page_anim"),
                color = text,
                modifier = Modifier.padding(top = DesignTokens.spacingDefault),
            )
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(horizontal = DesignTokens.spacingLg, vertical = DesignTokens.spacingXs),
                horizontalArrangement = Arrangement.spacedBy(DesignTokens.spacingDefault),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                ReaderPageModeChip(
                    label = rememberString("page_anim_scroll"),
                    selected = pageAnim == PageAnim.scrollPageAnim,
                    tint = text,
                    accent = accent,
                ) { applyPageAnim(PageAnim.scrollPageAnim) }
                ReaderPageModeChip(
                    label = rememberString("page_anim_cover"),
                    selected = pageAnim == PageAnim.coverPageAnim ||
                        pageAnim == PageAnim.slidePageAnim ||
                        pageAnim == PageAnim.simulationPageAnim,
                    tint = text,
                    accent = accent,
                ) { applyPageAnim(PageAnim.coverPageAnim) }
                ReaderPageModeChip(
                    label = rememberString("page_anim_none"),
                    selected = pageAnim == PageAnim.noAnim,
                    tint = text,
                    accent = accent,
                ) { applyPageAnim(PageAnim.noAnim) }
            }
        }
        // 本章进度压成一行：百分比、目录位置、章首/章末跳转都在同一行里
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = DesignTokens.spacingLg, vertical = DesignTokens.spacingDefault),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = state.chapterProgressText,
                color = progressColor,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.width(6.dp))
            Text(
                text = state.chapterIndexText,
                color = text.copy(alpha = .55f),
                fontSize = 11.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            ReaderPanelAction(
                rememberString("reader_chapter_start"), text,
                horizontalPadding = 10.dp, verticalPadding = 4.dp,
            ) { state.clickChapterStart() }
            Spacer(Modifier.width(6.dp))
            ReaderPanelAction(
                rememberString("reader_chapter_end"), text,
                horizontalPadding = 10.dp, verticalPadding = 4.dp,
            ) { state.clickChapterEnd() }
        }
        // 底部只留一个低频动作：恢复默认排版
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = DesignTokens.spacingLg, vertical = DesignTokens.spacingDefault),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ReaderPanelAction(rememberString("reader_reset_style"), text) { resetStyle() }
        }
    }

    if (showWeight) {
        AppSelectorDialog(
            onDismissRequest = { showWeight = false },
            title = rememberString("text_font_weight_converter"),
            items = weightNames,
            onItemSelected = { index ->
                showWeight = false
                readConfig.textBold = index
                readConfig.save()
                postConfig(
                    ReadConfigChange.CHAPTER_STYLE,
                    ReadConfigChange.INVALIDATE_TEXT_PAGE,
                    ReadConfigChange.UP_CONTENT,
                )
            },
        )
    }
    if (showIndent) {
        AppSelectorDialog(
            onDismissRequest = { showIndent = false },
            title = rememberString("text_indent"),
            items = indentNames,
            onItemSelected = { index ->
                showIndent = false
                // 对齐 app 端: ReadBookConfig.paragraphIndent = "　".repeat(index)
                readConfig.paragraphIndent = "　".repeat(index)
                readConfig.save()
                postConfig(ReadConfigChange.CHAPTER_STYLE, ReadConfigChange.LOAD_CONTENT)
            },
        )
    }
    if (showFont) {
        FontSelectDialogHost(onDismiss = { showFont = false })
    }
    if (showConverter) {
        ChineseConverterDialogHost(onDismiss = { showConverter = false })
    }
    if (showLayout) {
        ReadLayoutConfigDialogHost(onDismiss = { showLayout = false })
    }
    if (showBgText) {
        BgTextConfigDialogHost(
            onDismiss = {
                showBgText = false
                // 自定义背景改完后就地重读纸色，纸样预览立即跟上
                paperBg = readConfig.config.curBgStr()
            }
        )
    }
}

@Composable
private fun ReaderStyleSectionLabel(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        color = color.copy(alpha = .5f),
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        modifier = modifier
            .fillMaxWidth()
            .padding(
                start = DesignTokens.spacingLg,
                end = DesignTokens.spacingLg,
                bottom = DesignTokens.spacingXs,
            ),
    )
}

/**
 * 拟物纸样：一块带纸色的圆角纸片 + 纸上的示例字，下面标纸名。
 *
 * 比原来 20dp 的小圆点更接近参考里"能看出纸感"的预览：宣纸的米、青笺的淡青、
 * 墨夜的近黑都能直接看到，选中时只加一圈主题色描边，不叠阴影。
 */
@Composable
private fun ReaderPaperCard(
    label: String,
    background: Color,
    ink: Color,
    selected: Boolean,
    panelText: Color,
    accent: Color,
    onClick: () -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(2.dp),
    ) {
        Box(
            Modifier
                .size(width = 54.dp, height = 42.dp)
                .clip(RoundedCornerShape(7.dp))
                .background(background)
                .border(
                    width = if (selected) 1.5.dp else 0.5.dp,
                    color = if (selected) accent else panelText.copy(alpha = .18f),
                    shape = RoundedCornerShape(7.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(text = "文", color = ink, fontSize = 15.sp)
        }
        Spacer(Modifier.height(4.dp))
        Text(
            text = label,
            color = panelText.copy(alpha = if (selected) .9f else .55f),
            fontSize = 10.sp,
            maxLines = 1,
        )
    }
}

@Composable
private fun ReaderSwitchRow(
    label: String,
    checked: Boolean,
    text: Color,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = DesignTokens.spacingLg, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = text.copy(alpha = .8f),
            fontSize = 12.5.sp,
            modifier = Modifier.weight(1f),
        )
        AppSwitch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun ReaderPageModeChip(
    label: String,
    selected: Boolean,
    tint: Color,
    accent: Color,
    onClick: () -> Unit,
) {
    Text(
        text = label,
        color = if (selected) accent else tint.copy(alpha = .6f),
        fontSize = 13.sp,
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(
                if (selected) accent.copy(alpha = .12f) else Color.Transparent
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 6.dp),
    )
}

/**
 * 复刻 mini FloatingActionButton：40dp 圆、底栏色底，按压用 Compose 默认指示。
 *
 * @param focusable 是否参与方向键/TV 焦点搜索 ([listItemFocus])。阅读菜单与阅读内搜索覆盖层的
 *   悬浮按钮需要; 搜索页的开始/停止按钮在原版是未设 `android:focusable` 的 Material FAB,
 *   传 false 保持该行为。
 */
@Composable
fun ReadMenuFab(
    iconKey: String,
    contentDescription: String?,
    bg: Color,
    tint: Color,
    modifier: Modifier = Modifier,
    iconModifier: Modifier = Modifier,
    focusable: Boolean = true,
    onClick: () -> Unit,
) {
    Box(
        modifier
            .padding(DesignTokens.spacingLg)
            .size(40.dp)
            .shadow(6.dp, CircleShape)
            .clip(CircleShape)
            .background(bg)
            .then(if (focusable) Modifier.listItemFocus() else Modifier)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            painter = rememberPainter(iconKey),
            contentDescription = contentDescription,
            tint = tint,
            modifier = iconModifier.size(24.dp),
        )
    }
}

/** 底栏图标+文字项(原 60dp 竖排按钮)；默认宽 60dp，可传 modifier 覆盖(如 weight 均分底栏) */
@Composable
fun BottomMenuItem(
    iconKey: String,
    labelKey: String,
    tint: Color,
    modifier: Modifier = Modifier.width(60.dp),
    subLabel: String? = null,
    onClick: () -> Unit,
) {
    Column(
        modifier
            .clickable(onClick = onClick)
            .padding(
                top = DesignTokens.spacingXs,
                bottom = DesignTokens.spacingDefault,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            painter = rememberPainter(iconKey),
            contentDescription = rememberString(labelKey),
            tint = tint,
            modifier = Modifier.size(20.dp),
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(top = DesignTokens.spacingXs),
        ) {
            Text(
                text = rememberString(labelKey),
                color = tint,
                fontSize = 12.sp,
                maxLines = 1,
            )
            if (!subLabel.isNullOrBlank()) {
                Text(
                    text = subLabel,
                    color = tint.copy(alpha = .55f),
                    fontSize = 11.sp,
                    maxLines = 1,
                    modifier = Modifier.padding(start = DesignTokens.spacingXs),
                )
            }
        }
    }
}
