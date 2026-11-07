package com.langhuan.engine

import android.content.Context
import io.legado.app.constant.AndroidIdHolder
import io.legado.app.data.entities.Book
import io.legado.app.data.entities.BookChapter
import io.legado.app.data.entities.BookListPage
import io.legado.app.data.entities.BookSource
import io.legado.app.help.AppCacheManager
import io.legado.app.help.JsCryptoProviderJvm
import io.legado.app.help.JsCryptoProviders
import io.legado.app.help.RuleBigDataProviders
import io.legado.app.help.book.ContentProcessorProviders
import io.legado.app.help.config.AppConfigProviders
import io.legado.app.help.config.PreferenceProviders
import io.legado.app.help.http.OkHttpClientProvider
import io.legado.app.help.http.OkHttpClientProviders
import io.legado.app.help.http.OkHttpProxyClientProvider
import io.legado.app.help.http.OkHttpProxyClientProviders
import io.legado.app.help.http.KmpHttpClient
import io.legado.app.help.http.BackstageWebViewProviders
import io.legado.app.help.http.CookieStoreProviders
import io.legado.app.help.http.SharedCookieStore
import io.legado.app.help.http.registerSharedCookieJarBridge
import io.legado.app.help.source.SourceCacheProviders
import io.legado.app.help.source.SourceDebugLogger
import io.legado.app.help.source.SourceDebugLoggers
import io.legado.app.help.source.SourceNetworkProviders
import io.legado.app.data.AppDatabase
import io.legado.app.data.AppDatabaseProviders
import io.legado.app.data.AppDbProviders
import io.legado.app.model.SharedJsScope
import io.legado.app.model.script.JsBindingInjector
import io.legado.app.model.script.JsEngines
import io.legado.app.model.script.quickjs.QuickJsJsEngine
import io.legado.app.model.script.quickjs.QuickJsSharedJsScopeBase
import io.legado.app.model.webBook.WebBook
import io.legado.app.utils.ChineseUtils
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.OkHttpClient
import java.io.File

/**
 * 琅嬛阁引擎门面（Android）。
 *
 * 与 `:runner` 同一套「阅读引擎 + 最小 provider 注册面」，区别只在宿主件：
 * - 数据根 = app 私有目录（后续写入的 DB/缓存都落在 filesDir/legado）
 * - Room = AndroidSQLiteDriver（runner 用 Bundled）
 * - JS = quickjs-android-native（JNI 自带加载，无需外部 DLL）
 *
 * 对外 API 一律 JSON in/out，供 MethodChannel 直接转发。
 */
object EngineFacade {

    @Volatile
    private var initialized = false
    private lateinit var appContext: Context

    /** 引擎日志回流（琅嬛阁日志页用；由宿主设置）。 */
    @Volatile
    var logSink: ((String) -> Unit)? = null

    fun init(context: Context) {
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            val app = context.applicationContext
            appContext = app
            System.setProperty(
                "legado.portable.root",
                File(app.filesDir, "legado").apply { mkdirs() }.absolutePath,
            )
            AndroidIdHolder.value = "langhuan-engine-01"
            FacadeRuntime.attach(app)

            // JS 引擎 + 绑定（quickjs-android-native 随 :modules:quickjs 打包）
            JsBindingInjector.registerImageOps(BitmapImageOps)
            JsEngines.registerProvider { QuickJsJsEngine }
            SharedJsScope.registerProviders { AndroidSharedJsScope() }
            JsCryptoProviders.register(JsCryptoProviderJvm)

            // 配置与偏好
            PreferenceProviders.register(SharedPrefsProvider(app))
            AppConfigProviders.register(DefaultAppConfig())

            // HTTP（共享单例；代理请求暂直连）
            val client = OkHttpClient()
            OkHttpClientProviders.register(object : OkHttpClientProvider {
                override val okHttpClient: KmpHttpClient = client
            })
            OkHttpProxyClientProviders.impl = object : OkHttpProxyClientProvider {
                override fun getProxyClient(proxy: String?): KmpHttpClient = client
            }

            // cookie 持久化：shared 的 Room 实现（cookieDao + 内存热层）
            CookieStoreProviders.register(SharedCookieStore)
            // OkHttp 层 cookie 桥（HttpHelper 自动 loadRequest/saveResponse）
            registerSharedCookieJarBridge()
            // 后台 WebView（反爬 / CF 源；Android 实现，移植自 app 端）
            BackstageWebViewProviders.register(BackstageWebViewFactoryImpl)

            // 缓存 / 大变量 / 正文处理
            SourceCacheProviders.impl = MemorySourceCache()
            SourceNetworkProviders.impl = MemorySourceNetwork()
            RuleBigDataProviders.impl = MemoryBigData()
            ContentProcessorProviders.register(PassthroughContentProcessor())

            // 数据库（Room + AndroidSQLiteDriver）
            AppDatabaseProviders.register(AndroidDatabaseProvider(app))
            AppDbProviders.register(AndroidDbAccessor())

            // 引擎日志直出（宿主可挂 logSink 转发到应用日志页）
            SourceDebugLoggers.impl = object : SourceDebugLogger {
                override fun log(
                    key: String,
                    msg: String,
                    print: Boolean,
                    state: Int,
                    showTime: Boolean,
                ) {
                    if (print) logSink?.invoke("[$key] $msg")
                }

                override fun log(msg: String) {
                    logSink?.invoke(msg)
                }
            }
            initialized = true
        }
    }

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        explicitNulls = false
    }

    /**
     * 搜索：书源 JSON + 关键词 + 页码
     * → `{ok, hits:[{name,author,coverUrl,bookUrl,lastChapter,intro,kind}], hasNextPage, nextPageUrl, error}`。
     */
    fun search(
        sourceJson: String,
        keyword: String,
        page: Int = 1,
        nextPageUrl: String? = null,
    ): String = runBlocking {
        val source = decodeSource(sourceJson)
            ?: return@runBlocking errorJson("书源 JSON 解析失败")
        try {
            bookListJson(
                WebBook.getBookListAwait(
                    source,
                    keyword,
                    page.coerceAtLeast(1),
                    nextPageUrl = nextPageUrl?.takeIf { it.isNotBlank() },
                ),
            )
        } catch (e: Exception) {
            errorJson(e.message ?: e::class.simpleName ?: "搜索失败")
        }
    }

    /**
     * 发现：书源 JSON + 分类 key（exploreUrl 段）+ 页码 → 回包同 [search]。
     *
     * 引擎侧 `isSearch = false`：走 exploreRule（列表规则为空时自动回落搜索规则），
     * 分类 URL 的 `{{page}}` 变量由引擎按 [page] 展开。
     */
    fun explore(
        sourceJson: String,
        key: String,
        page: Int = 1,
        nextPageUrl: String? = null,
    ): String = runBlocking {
        val source = decodeSource(sourceJson)
            ?: return@runBlocking errorJson("书源 JSON 解析失败")
        try {
            bookListJson(
                WebBook.getBookListAwait(
                    source,
                    key,
                    page.coerceAtLeast(1),
                    isSearch = false,
                    nextPageUrl = nextPageUrl?.takeIf { it.isNotBlank() },
                ),
            )
        } catch (e: Exception) {
            errorJson(e.message ?: e::class.simpleName ?: "发现失败")
        }
    }

    /** 书单页 → `{ok, hits, hasNextPage, nextPageUrl}`（search / explore 共用）。 */
    private fun bookListJson(page: BookListPage): String = buildJsonObject {
        put("ok", true)
        put("hits", buildJsonArray {
            page.books.forEach { b ->
                add(
                    buildJsonObject {
                        put("name", b.name)
                        put("author", b.author)
                        put("coverUrl", b.coverUrl ?: "")
                        put("bookUrl", b.bookUrl)
                        put("lastChapter", b.latestChapterTitle ?: "")
                        put("intro", b.intro ?: "")
                        put("kind", b.kind ?: "")
                        put("wordCount", b.wordCount ?: "")
                    }
                )
            }
        })
        put("hasNextPage", page.hasNextPage)
        put("nextPageUrl", page.nextPageUrl ?: "")
    }.toString()

    /** 正文简繁转换：`traditional=true` 转繁体，否则转简体。 */
    fun convertChinese(text: String, traditional: Boolean): String = try {
        buildJsonObject {
            put("ok", true)
            put(
                "text",
                if (traditional) ChineseUtils.s2t(text) else ChineseUtils.t2s(text),
            )
        }.toString()
    } catch (e: Exception) {
        errorJson(e.message ?: e::class.simpleName ?: "简繁转换失败")
    }

    /** 当前 URL 所属域名的 Cookie（含 session；无则空串）。 */
    fun cookieHeader(url: String): String = buildJsonObject {
        put("ok", true)
        put("cookie", CookieStoreProviders.get()?.getCookie(url).orEmpty())
    }.toString()

    /** 清除全部登录态：OkHttp cookie + Room cookie + 内存热层。 */
    fun clearCookies(): String {
        CookieStoreProviders.get()?.clear()
        runBlocking { AppDbProviders.get().cookieDao.deleteAll() }
        AppCacheManager.clearCookieMemory()
        return okJson()
    }

    /** 引擎私有缓存字节数（不含登录态 Cookie）。 */
    fun cacheStats(): String = buildJsonObject {
        put("ok", true)
        put("bytes", engineDataBytes())
    }.toString()

    /** 清除引擎私有缓存：filesDir/legado + cacheDao + 内存源变量。 */
    fun clearEngineCache(): String {
        File(appContext.filesDir, "legado").deleteRecursively()
        runBlocking { AppDbProviders.get().cacheDao.deleteAll() }
        AppCacheManager.clearSourceVariables()
        return okJson()
    }

    /** 详情：书源 JSON + 书籍 JSON → 更新后的书籍 JSON（键 `book`）。 */
    fun bookInfo(sourceJson: String, bookJson: String): String = runBlocking {
        val source = decodeSource(sourceJson)
            ?: return@runBlocking errorJson("书源 JSON 解析失败")
        val book = try {
            json.decodeFromString(Book.serializer(), bookJson)
        } catch (e: Exception) {
            return@runBlocking errorJson("书籍 JSON 解析失败: ${e.message}")
        }
        try {
            WebBook.getBookInfoAwait(source, book)
            buildJsonObject {
                put("ok", true)
                put("book", json.encodeToString(Book.serializer(), book))
            }.toString()
        } catch (e: Exception) {
            errorJson(e.message ?: e::class.simpleName ?: "详情失败")
        }
    }

    /**
     * 目录：书源 JSON + 书籍 JSON → `{ok, book, chapters:[…]}`。
     * 返回更新后的书籍（totalChapterNum 等随目录刷新）。
     */
    fun toc(sourceJson: String, bookJson: String): String = runBlocking {
        val source = decodeSource(sourceJson)
            ?: return@runBlocking errorJson("书源 JSON 解析失败")
        val book = try {
            json.decodeFromString(Book.serializer(), bookJson)
        } catch (e: Exception) {
            return@runBlocking errorJson("书籍 JSON 解析失败: ${e.message}")
        }
        try {
            val chapters = WebBook.getChapterListAwait(source, book).getOrThrow()
            buildJsonObject {
                put("ok", true)
                put("book", json.encodeToString(Book.serializer(), book))
                put(
                    "chapters",
                    json.encodeToString(
                        ListSerializer(BookChapter.serializer()),
                        chapters,
                    ),
                )
            }.toString()
        } catch (e: Exception) {
            errorJson(e.message ?: e::class.simpleName ?: "目录失败")
        }
    }

    /**
     * 正文：书源 JSON + 书籍 JSON + 章节 JSON（+ 下一章 URL）→ `{ok, content}`。
     * 调用方按 TOC 顺序补 `nextChapterUrl`（阅读正常流程要求，缺失会报「未传入下一章节URL」）。
     */
    fun content(
        sourceJson: String,
        bookJson: String,
        chapterJson: String,
        nextChapterUrl: String = "",
    ): String = runBlocking {
        val source = decodeSource(sourceJson)
            ?: return@runBlocking errorJson("书源 JSON 解析失败")
        val book = try {
            json.decodeFromString(Book.serializer(), bookJson)
        } catch (e: Exception) {
            return@runBlocking errorJson("书籍 JSON 解析失败: ${e.message}")
        }
        val chapter = try {
            json.decodeFromString(BookChapter.serializer(), chapterJson)
        } catch (e: Exception) {
            return@runBlocking errorJson("章节 JSON 解析失败: ${e.message}")
        }
        try {
            val text = WebBook.getContentAwait(
                source,
                book,
                chapter,
                nextChapterUrl = nextChapterUrl.takeIf { it.isNotEmpty() },
                needSave = false,
            )
            buildJsonObject {
                put("ok", true)
                put("content", text)
            }.toString()
        } catch (e: Exception) {
            errorJson(e.message ?: e::class.simpleName ?: "正文失败")
        }
    }

    private fun decodeSource(sourceJson: String): BookSource? = try {
        json.decodeFromString(BookSource.serializer(), sourceJson)
    } catch (_: Exception) {
        null
    }

    private fun errorJson(message: String): String =
        buildJsonObject {
            put("ok", false)
            put("error", message.take(200))
        }.toString()

    private fun okJson(): String = buildJsonObject { put("ok", true) }.toString()

    private fun engineDataBytes(): Long {
        val root = File(appContext.filesDir, "legado")
        val db = appContext.getDatabasePath(AppDatabase.DATABASE_NAME)
        return listOf(root, db, File("${db.path}-wal"), File("${db.path}-shm"))
            .sumOf { file -> if (file.exists()) file.walkTopDown().filter { it.isFile }.sumOf { it.length() } else 0L }
    }
}
