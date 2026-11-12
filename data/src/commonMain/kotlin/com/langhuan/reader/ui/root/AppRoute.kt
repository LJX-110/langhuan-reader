package com.langhuan.reader.ui.root

import com.langhuan.reader.constant.SourceType
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.BookSource
import com.langhuan.reader.data.entities.SearchBook
import com.langhuan.reader.help.book.isAudio
import com.langhuan.reader.ui.book.searchContent.SearchResult
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** 应用内唯一类型化路由参数。平台入口不得再平行保存页面参数。 */
@Serializable
sealed interface AppRoute {
    @Serializable
    @SerialName("main")
    data class Main(val tab: MainTab = MainTab.BOOKSHELF) : AppRoute

    @Serializable
    @SerialName("search")
    data class Search(
        val key: String? = null,
        val searchScope: String? = null,
        val submit: Boolean = true,
    ) : AppRoute

    @Serializable
    @SerialName("book_info")
    data class BookInfo(val book: BookRef) : AppRoute

    @Serializable
    @SerialName("reader")
    data class Reader(
        val book: BookRef,
        val chapterIndex: Int? = null,
        val chapterPos: Int? = null,
    ) : AppRoute

    @Serializable
    @SerialName("book_source")
    data object BookSourceManage : AppRoute

    @Serializable
    @SerialName("explore_show")
    data class ExploreShow(
        val source: BookSource,
        val title: String,
        val exploreUrl: String? = null,
    ) : AppRoute

    /**
     * 发现show 外部入口 (对照 master ExploreShowActivity 冷启动直开):
     * 只带 sourceUrl/exploreUrl/exploreName extra, 书源对象未预取;
     * 查源下沉到路由内 (对照 master initData(intent): IntentData.source ?: DAO 查 sourceUrl),
     * 查源期间页面直接渲染加载态, 书架不进导航栈。
     * 应用内跳转 (已有 BookSource 对象) 走 [ExploreShow], 不查源。
     */
    @Serializable
    @SerialName("explore_show_by_url")
    data class ExploreShowByUrl(
        val sourceUrl: String,
        val title: String? = null,
        val exploreUrl: String? = null,
    ) : AppRoute

    /**
     * 单源搜索结果页 (搜索界面"按源分类"布局的二级页): 复用发现 show 界面,
     * 但数据走 [BookSource.searchUrl] 搜索规则 (isSearch=true, key=[keyword]),
     * 与 [ExploreShow] (explore 规则) 区分。
     */
    @Serializable
    @SerialName("source_search_show")
    data class SourceSearchShow(
        val source: BookSource,
        val keyword: String,
    ) : AppRoute

    @Serializable
    @SerialName("my_config")
    data object MyConfig : AppRoute

    @Serializable
    @SerialName("remote_book")
    data object RemoteBook : AppRoute

    @Serializable
    @SerialName("replace_edit")
    data class ReplaceEdit(
        val ruleId: Long = -1L,
        val pattern: String? = null,
        val isRegex: Boolean = false,
        val scope: String? = null,
    ) : AppRoute

    // 三端合并: 书籍阅读类 (音频/RSS/目录/换源/书签/书评/信息编辑)
    @Serializable
    @SerialName("audio_play")
    data class AudioPlay(
        val book: BookRef,
        val chapterIndex: Int? = null,
        val chapterPos: Int? = null,
    ) : AppRoute

    @Serializable
    @SerialName("toc")
    data class Toc(val book: BookRef) : AppRoute

    @Serializable
    @SerialName("book_info_edit")
    data class BookInfoEdit(val book: BookRef) : AppRoute

    @Serializable
    @SerialName("bookmark")
    data class Bookmark(val book: BookRef? = null) : AppRoute

    // 段评/书评列表页 (发布入口为弹窗形态 ReviewPostDialogHost, 对照原版 ReviewPostActivity)
    @Serializable
    @SerialName("review_list")
    data class ReviewList(val book: BookRef) : AppRoute

    // 三端合并: 书源/规则编辑类 (仅传稳定 ID/URL)
    @Serializable
    @SerialName("book_source_edit")
    data class BookSourceEdit(val sourceUrl: String) : AppRoute

    @Serializable
    @SerialName("replace_rule")
    data object ReplaceRule : AppRoute

    @Serializable
    @SerialName("txt_toc_rule")
    data object TxtTocRule : AppRoute

    // 关键词高亮管理 (规则默认作用范围 = 本书, 故带上阅读页当前书)
    @Serializable
    @SerialName("keyword_highlight")
    data class KeywordHighlight(val book: BookRef? = null) : AppRoute

    /**
     * 弹窗预览: 逐个列出全部对话框/弹层形制并就地弹出, 供改界面时逐项对照。
     *
     * 纯调试页面, 无业务语义: 入口只在桌面端「我的」页提供 (其余端不传回调, 条目不渲染)。
     * 页面内所有弹窗读写的都是数据副本 (桌面端入口会先把真实数据只读复制到独立数据根再重启进入),
     * 不影响正式数据。
     */
    @Serializable
    @SerialName("dialog_preview")
    data object DialogPreview : AppRoute

    // 三端合并: 书架/搜索/导入类
    @Serializable
    @SerialName("bookshelf_manage")
    data class BookshelfManage(val groupId: Long = -1L) : AppRoute

    @Serializable
    @SerialName("search_content")
    data class SearchContent(
        val index: Int = 0,
        val word: String? = null,
        val initialResults: List<SearchResult>? = null,
        // 当前书籍 (阅读页全文搜索入口传入; 修复: SearchContent 页面 book 曾依赖
        // IntentData.book 全局槽, 路由跳转未设置 → book 恒 null → 只跳界面不搜索, 2026-08-06)
        val book: BookRef? = null,
    ) : AppRoute

    @Serializable
    @SerialName("import_book")
    data object ImportBook : AppRoute

    // 三端合并: 配置类 (MY 子项)
    @Serializable
    @SerialName("about")
    data object About : AppRoute

    @Serializable
    @SerialName("read_record")
    data object ReadRecord : AppRoute

    @Serializable
    @SerialName("backup_config")
    data object BackupConfig : AppRoute

    // 三端合并: 工具类 (WebView/登录/JS/关联)
    // 字段对应原 app 端 WebViewActivity 的 intent extras:
    // title/sourceName/sourceKey/sourceType (initData 取书源 headerMap 用),
    // saveResult/refetchAfterSuccess (原 sourceVerificationEnable/refetchAfterSuccess, 验证回传用),
    // isLogin (原登录模式: 回传 cookie 到书源)。
    @Serializable
    @SerialName("web_view")
    data class WebView(
        val url: String,
        val title: String = "",
        val sourceName: String = "",
        val sourceKey: String = "",
        val sourceType: Int = SourceType.book,
        val isLogin: Boolean = false,
        val saveResult: Boolean = false,
        val refetchAfterSuccess: Boolean = true,
    ) : AppRoute

}

@Serializable
enum class MainTab { HOME, BOOKSHELF, DISCOVERY, MY }

/**
 * 路由只持有可序列化业务快照，不持有 Activity、UIViewController 或平台文件句柄。
 * SearchBook 与 Book 均已位于 commonMain 且可序列化。
 */
@Serializable
sealed interface BookRef {
    val bookUrl: String

    @Serializable
    @SerialName("book")
    data class Stored(val value: Book) : BookRef {
        override val bookUrl: String get() = value.bookUrl
    }

    @Serializable
    @SerialName("search_book")
    data class Search(val value: SearchBook) : BookRef {
        override val bookUrl: String get() = value.bookUrl
    }
}

/**
 * Book → 路由可序列化快照。
 *
 * # 拷贝契约 (2026-08: 去掉内部 copy)
 * `toRouteRef`/`asBook` 不再拷贝, 直接共享调用方对象:
 * - **DB-flow 边界必须显式 `copy()`**: 书架列表/搜索页"书架"区块等来自
 *   `bookDao.observeAll()` flow 的实体, 进入路由前需 `book.copy().toRouteRef()`
 *   (否则路由与 flow 实体别名, DB 流无法正确捕捉修改)。
 * - **瞬态书直接共享**: 搜索结果/发现/深链抓取等一次性对象无别名风险, 零拷贝。
 */
fun Book.toRouteRef(): BookRef = BookRef.Stored(this)
fun SearchBook.toRouteRef(): BookRef = BookRef.Search(this)

// 按 app 端 startActivityForBook 逻辑分流阅读类路由 (音频/目录/正文)
fun Book.toReadRoute(): AppRoute = toRouteRef().toReadRoute()

// 由 BookRef 构造阅读类路由, 保留 chapterIndex/chapterPos (供 OpenBook/OpenReader 外部启动定位章节)
fun BookRef.toReadRoute(chapterIndex: Int? = null, chapterPos: Int? = null): AppRoute {
    val book = asBook()
    return when {
        book.isAudio -> AppRoute.AudioPlay(this, chapterIndex, chapterPos)
        else -> AppRoute.Reader(this, chapterIndex, chapterPos)
    }
}

fun BookRef.asBook(): Book = when (this) {
    is BookRef.Stored -> value
    is BookRef.Search -> value.toBook()
}
