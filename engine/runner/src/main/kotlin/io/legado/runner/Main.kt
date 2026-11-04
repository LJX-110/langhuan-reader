package io.legado.runner

import io.legado.app.constant.AndroidIdHolder
import io.legado.app.data.AppDatabaseProviders
import io.legado.app.data.AppDbProviders
import io.legado.app.data.BundledDatabaseDriver
import io.legado.app.data.entities.Book
import io.legado.app.data.entities.BookChapter
import io.legado.app.data.entities.BookSource
import io.legado.app.exception.NoStackTraceException
import io.legado.app.help.JsCryptoProviderJvm
import io.legado.app.help.JsCryptoProviders
import io.legado.app.help.RuleBigDataProvider
import io.legado.app.help.RuleBigDataProviders
import io.legado.app.help.book.ContentProcessorAccessor
import io.legado.app.help.book.ContentProcessorProviders
import io.legado.app.data.entities.ReplaceRule
import io.legado.app.help.config.AppConfigProviders
import io.legado.app.help.http.KmpHttpClient
import io.legado.app.help.http.OkHttpClientProvider
import io.legado.app.help.http.OkHttpClientProviders
import io.legado.app.help.http.OkHttpProxyClientProvider
import io.legado.app.help.http.OkHttpProxyClientProviders
import io.legado.app.help.image.ImageOps
import io.legado.app.help.image.ImageRef
import io.legado.app.help.source.SourceCacheProvider
import io.legado.app.help.source.SourceCacheProviders
import io.legado.app.help.source.SourceDebugLogger
import io.legado.app.help.source.SourceDebugLoggers
import io.legado.app.help.source.SourceNetworkProvider
import io.legado.app.help.source.SourceNetworkProviders
import io.legado.app.model.SharedJsScope
import io.legado.app.model.analyzeRule.AnalyzeRuleCore
import io.legado.app.model.script.JsBindingInjector
import io.legado.app.model.script.JsEngineType
import io.legado.app.model.script.JsEngines
import io.legado.app.model.script.quickjs.QuickJsJsEngine
import io.legado.app.model.script.quickjs.QuickJsSharedJsScopeBase
import io.legado.app.model.webBook.WebBook
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File

/**
 * 琅嬛阁引擎 runner：以最小 provider 注册集在 Windows 宿主上验证
 * QuickJS 原生加载 / java.* 绑定 / 规则管线（@js、CSS、text. 选择器）。
 *
 * 跑法：
 *   gradlew -g E:\WorkSpace\Novel\.gradle-home :runner:run
 * 可选参数：quickjs 库路径（默认 native/legado_quickjs.dll）
 */
fun main(args: Array<String>) {
    // 1) quickjs 原生库定位（fork 桌面端同款系统属性）；
    //    只把非 --flag 的首个参数当作库路径。
    val libArg = args.firstOrNull { !it.startsWith("--") }
    val lib = libArg?.let(::File)
        ?: File("native/legado_quickjs.dll")
    check(lib.isFile) { "quickjs 原生库不存在: ${lib.absolutePath}" }
    System.setProperty("legado.quickjs.lib", lib.absolutePath)
    println("[runner] quickjs lib = ${lib.absolutePath}")

    // 2) 最小 provider 注册集（对齐 app/desktop 的引擎必需项）
    AndroidIdHolder.value = "runner-0000000001"
    JsBindingInjector.registerImageOps(StubImageOps)
    JsEngines.registerProvider { QuickJsJsEngine }
    SharedJsScope.registerProviders { RunnerSharedJsScope }
    JsCryptoProviders.register(JsCryptoProviderJvm)

    // 2.5) WebBook 管线 provider（对齐桌面端注册面：配置/HTTP/缓存/cookie）
    registerRunnerPreferences()
    AppConfigProviders.register(RunnerAppConfig())
    val httpClient = OkHttpClient()
    OkHttpClientProviders.register(object : OkHttpClientProvider {
        override val okHttpClient: KmpHttpClient = httpClient
    })
    OkHttpProxyClientProviders.impl = object : OkHttpProxyClientProvider {
        override fun getProxyClient(proxy: String?): KmpHttpClient = httpClient
    }
    SourceCacheProviders.impl = RunnerSourceCache()
    SourceNetworkProviders.impl = RunnerSourceNetwork()
    RuleBigDataProviders.impl = RunnerBigData()
    ContentProcessorProviders.register(RunnerContentProcessor())

    // 便携数据根（BundledDatabaseDriver 默认 {portableRoot}/legado.db）
    val dataDir = File("data").absoluteFile
    dataDir.mkdirs()
    System.setProperty("legado.portable.root", dataDir.absolutePath)
    // 真实 Room（data jvmMain 的 BundledDatabaseDriver + BundledSQLiteDriver）
    val dbDriver = BundledDatabaseDriver()
    AppDatabaseProviders.register(RunnerAppDatabaseProvider(dbDriver))
    AppDbProviders.register(RunnerAppDbAccessor())
    // 引擎日志直出（对齐 app 端 [Source] 日志通道），便于宿主定位源问题。
    SourceDebugLoggers.impl = object : SourceDebugLogger {
        override fun log(
            key: String,
            msg: String,
            print: Boolean,
            state: Int,
            showTime: Boolean,
        ) {
            if (print) println("[engine][$key] $msg")
        }

        override fun log(msg: String) {
            println("[engine] $msg")
        }
    }

    // 3) 冒烟用例
    var failures = 0
    fun check(name: String, actual: String, expected: String) {
        val ok = actual == expected
        if (!ok) failures++
        println("[${if (ok) "PASS" else "FAIL"}] $name\n        actual   = ${actual.take(120)}\n        expected = ${expected.take(120)}")
    }

    val html = """
        <html><body>
          <div class="wrap"><a href="/book/1_1.html">上一页</a></div>
          <div class="wrap"><a href="/book/1_2.html">下一页</a></div>
        </body></html>
    """.trimIndent()

    val rule = AnalyzeRuleCore()
    rule.setContent(html, "https://example.com/book/1_1.html")

    // A. 纯 JS 规则（验证 quickjs 原生库加载 + eval 通路）
    check("JS 规则 @js:6*7", rule.getString("@js:6*7"), "42")

    // B. java.* 绑定（验证绑定注入 + JsCryptoProviderJvm 桥）
    check(
        "java.md5Encode('abc')",
        rule.getString("@js:java.md5Encode('abc')"),
        "900150983cd24fb0d6963f7d28e17f72",
    )

    // C. text. 选择器（nextContentUrl 高频形态）
    check("text.下一页@href", rule.getString("text.下一页@href"), "/book/1_2.html")

    // D. || 分支 + text. 组合
    check(
        "text.下一页@href||text.下一章@href",
        rule.getString("text.下一页@href||text.下一章@href"),
        "/book/1_2.html",
    )

    // E. {{}} = JS 表达式（Legado 语义）
    check("{{3*4}} 内联 JS", rule.getString("{{3*4}}"), "12")

    // 4) 可选：真实书源搜索——用阅读原生引擎对全量源跑搜索
    //    （对齐"所有书源都由阅读引擎兜底"的目标）。
    //    内联：--search=<pack.json>|<源名或URL>|<关键词>
    //    文件：--search-file=<spec.txt>（三行：pack 路径 / 源名 / 关键词；避免 shell 转义与编码问题）
    args.firstOrNull { it.startsWith("--search=") }?.let {
        val p = it.removePrefix("--search=").split('|')
        runSourceSearch(
            File(p[0]),
            p.getOrNull(1)?.trim() ?: "",
            p.getOrNull(2)?.trim()?.takeIf { k -> k.isNotEmpty() } ?: "斗破苍穹",
        )
    }
    args.firstOrNull { it.startsWith("--search-file=") }?.let {
        val lines = File(it.removePrefix("--search-file="))
            .readLines()
            .map(String::trim)
        check(lines.size >= 2) { "search-file 需要至少两行: pack 路径 / 源名(/关键词)" }
        runSourceSearch(
            File(lines[0]),
            lines[1],
            lines.getOrNull(2)?.takeIf { k -> k.isNotEmpty() } ?: "斗破苍穹",
        )
    }

    // 5) 批量体检：整个包逐源跑 搜索→详情→目录→正文
    //    --batch-file=<spec.txt>（四行：pack 路径 / 关键词 / 数量 / 起始偏移）
    args.firstOrNull { it.startsWith("--batch-file=") }?.let {
        val lines = File(it.removePrefix("--batch-file="))
            .readLines()
            .map(String::trim)
        check(lines.isNotEmpty()) { "batch-file 至少一行 pack 路径" }
        runBatch(
            pack = File(lines[0]),
            keyword = lines.getOrNull(1)?.takeIf { k -> k.isNotEmpty() } ?: "斗破苍穹",
            limit = lines.getOrNull(2)?.toIntOrNull() ?: Int.MAX_VALUE,
            offset = lines.getOrNull(3)?.toIntOrNull() ?: 0,
        )
    }

    println("\n[runner] done. failures=$failures")
    if (failures > 0) {
        kotlin.system.exitProcess(1)
    }
}

/** runner 版源变量缓存（内存实现，够跑单次会话）。 */
private class RunnerSourceCache : SourceCacheProvider {
    private val disk = mutableMapOf<String, String>()
    private val memory = mutableMapOf<String, Any>()

    override fun get(key: String): String? = disk[key]
    override fun put(key: String, value: String) {
        disk[key] = value
    }

    override fun delete(key: String) {
        disk.remove(key)
    }

    override fun getFromMemory(key: String): Any? = memory[key]
    override fun putMemory(key: String, value: Any) {
        memory[key] = value
    }

    override fun deleteMemory(key: String) {
        memory.remove(key)
    }
}

/** runner 版 cookie 存储（内存实现）。 */
private class RunnerSourceNetwork : SourceNetworkProvider {
    private val cookies = mutableMapOf<String, String>()

    override fun getCookie(tag: String): String = cookies[tag] ?: ""
    override fun replaceCookie(tag: String, cookie: String) {
        cookies[tag] = cookie
    }

    override fun removeCookie(tag: String) {
        cookies.remove(tag)
    }
}

/**
 * 从书源整包里挑一个源，用 [WebBook.getBookListAwait] 跑一次真实搜索并打印结果。
 */
private fun runSourceSearch(pack: File, name: String, keyword: String) {
    check(pack.isFile) { "书源包不存在: ${pack.absolutePath}" }

    val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        explicitNulls = false
    }
    val root = json.parseToJsonElement(pack.readText())
    val arr: JsonArray = when (root) {
        is JsonArray -> root
        is JsonObject ->
            (root["sources"] ?: root["data"]) as? JsonArray
                ?: error("书源包缺少 sources/data 数组")
        else -> error("书源包格式不支持")
    }
    val source = arr.firstNotNullOfOrNull { el ->
        runCatching { json.decodeFromJsonElement(BookSource.serializer(), el) }
            .getOrNull()
            ?.takeIf { it.bookSourceName == name || it.bookSourceUrl == name }
    }
    checkNotNull(source) { "未找到书源: $name" }

    println("[search] ${source.bookSourceName} key=$keyword …")
    val started = System.currentTimeMillis()
    val page = runBlocking { WebBook.getBookListAwait(source, keyword, 1) }
    val cost = System.currentTimeMillis() - started
    println(
        "[search] ${source.bookSourceName} hits=${page.books.size} " +
            "hasNext=${page.hasNextPage} cost=${cost}ms"
    )
    page.books.take(10).forEachIndexed { i, b ->
        println("  ${i + 1}. ${b.name} / ${b.author} / ${b.bookUrl}")
    }
    if (page.books.isEmpty()) {
        kotlin.system.exitProcess(2)
    }

    // 5) 详情 → 目录 → 正文（与阅读同款的完整链路，验证"目录/正文加载不出来"）
    val hit = page.books.first()
    val book = Book(
        bookUrl = hit.bookUrl,
        name = hit.name,
        author = hit.author,
        origin = source.bookSourceUrl,
        originName = source.bookSourceName,
        kind = hit.kind,
        intro = hit.intro,
        coverUrl = hit.coverUrl,
        tocUrl = hit.bookUrl,
    )
    runBlocking {
        try {
            WebBook.getBookInfoAwait(source, book)
            println(
                "[detail] name=${book.name} author=${book.author} " +
                    "tocUrl=${book.tocUrl} cover=${book.coverUrl?.take(70)}"
            )
        } catch (e: Exception) {
            println("[detail] FAILED: ${e.message}")
        }
        val toc = try {
            WebBook.getChapterListAwait(source, book).getOrThrow()
        } catch (e: Exception) {
            println("[toc] FAILED: ${e.message}")
            emptyList()
        }
        println(
            "[toc] chapters=${toc.size} first3=" +
                toc.take(3).joinToString(" | ") { it.title }
        )
        val chapter: BookChapter? = toc.firstOrNull { !it.isVolume } ?: toc.firstOrNull()
        if (chapter != null) {
            try {
                book.totalChapterNum = toc.size
                val chIdx = toc.indexOf(chapter)
                val nextUrl = toc.getOrNull(chIdx + 1)?.getAbsoluteURL(book) ?: ""
                val content = WebBook.getContentAwait(
                    source,
                    book,
                    chapter,
                    nextChapterUrl = nextUrl,
                    needSave = false,
                )
                val plain = content.replace(Regex("\\s+"), " ")
                println("[content] ${chapter.title} len=${content.length}")
                println("  head: ${plain.take(120)}")
            } catch (e: Exception) {
                println("[content] FAILED: ${e.message}")
            }
        }
    }
}

/** 批量体检的一行结果。 */
private data class BatchRow(
    val name: String,
    val search: String,
    val detail: String,
    val toc: String,
    val content: String,
)

private fun String.searchOk() = endsWith("条") && this != "0条"

private fun failureOf(e: Exception): String = when (e) {
    is TimeoutCancellationException -> "超时"
    else -> (e.message ?: e::class.simpleName ?: "失败").take(40)
}

/**
 * 批量体检：整个包逐源跑 搜索→详情→目录→正文，逐行打印 + 写 JSON 报告。
 * 对"所有书源"用阅读原生引擎做端到端验证（站点反爬/死站会如实归因）。
 */
private fun runBatch(pack: File, keyword: String, limit: Int, offset: Int) {
    check(pack.isFile) { "书源包不存在: ${pack.absolutePath}" }
    val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        explicitNulls = false
    }
    val root = json.parseToJsonElement(pack.readText())
    val arr: JsonArray = when (root) {
        is JsonArray -> root
        is JsonObject ->
            (root["sources"] ?: root["data"]) as? JsonArray
                ?: error("书源包缺少 sources/data 数组")
        else -> error("书源包格式不支持")
    }
    val sources = arr.mapNotNull { el ->
        runCatching { json.decodeFromJsonElement(BookSource.serializer(), el) }
            .getOrNull()
    }.filter { it.bookSourceType == 0 }
    val slice = sources.drop(offset).take(limit)
    println(
        "[batch] 共 ${sources.size} 个文本源，本次跑 ${slice.size} 个" +
            "（offset=$offset）key=$keyword"
    )
    val rows = mutableListOf<BatchRow>()
    var okCount = 0
    for ((i, source) in slice.withIndex()) {
        val name = source.bookSourceName.ifEmpty { source.bookSourceUrl }
        var search = "-"
        var detail = "-"
        var toc = "-"
        var content = "-"
        val book = Book()
        val t0 = System.currentTimeMillis()
        runBlocking {
            val page = try {
                withTimeout(20_000) { WebBook.getBookListAwait(source, keyword, 1) }
            } catch (e: Exception) {
                search = failureOf(e)
                null
            }
            if (page == null) return@runBlocking
            if (page.books.isEmpty()) {
                search = "0条"
                return@runBlocking
            }
            search = "${page.books.size}条"
            val hit = page.books.first()
            book.bookUrl = hit.bookUrl
            book.name = hit.name
            book.author = hit.author
            book.origin = source.bookSourceUrl
            book.originName = source.bookSourceName
            book.tocUrl = hit.bookUrl
            book.kind = hit.kind
            book.intro = hit.intro
            book.coverUrl = hit.coverUrl
            detail = try {
                withTimeout(20_000) { WebBook.getBookInfoAwait(source, book) }
                "ok"
            } catch (e: Exception) {
                failureOf(e)
            }
            val chapters = try {
                withTimeout(30_000) {
                    WebBook.getChapterListAwait(source, book).getOrThrow()
                }
            } catch (e: Exception) {
                toc = failureOf(e)
                emptyList()
            }
            if (chapters.isEmpty()) return@runBlocking
            toc = "${chapters.size}章"
            book.totalChapterNum = chapters.size
            val chIdx = chapters.indexOfFirst { !it.isVolume }
                .let { if (it >= 0) it else 0 }
            val ch = chapters[chIdx]
            val nextUrl = chapters.getOrNull(chIdx + 1)?.getAbsoluteURL(book) ?: ""
            content = try {
                val text = withTimeout(30_000) {
                    WebBook.getContentAwait(
                        source,
                        book,
                        ch,
                        nextChapterUrl = nextUrl,
                        needSave = false,
                    )
                }
                if (text.isBlank()) "空" else "${text.length}字"
            } catch (e: Exception) {
                failureOf(e)
            }
        }
        val cost = System.currentTimeMillis() - t0
        rows.add(BatchRow(name, search, detail, toc, content))
        val allOk = search.searchOk() && detail == "ok" &&
            toc.endsWith("章") && content.endsWith("字")
        if (allOk) okCount++
        println(
            "[batch] ${i + 1}/${slice.size} ${if (allOk) "OK " else "!! "}$name" +
                " | 搜:$search 详:$detail 目:$toc 文:$content | ${cost}ms"
        )
    }
    val searchOk = rows.count { it.search.searchOk() }
    val detailOk = rows.count { it.detail == "ok" }
    val tocOk = rows.count { it.toc.endsWith("章") }
    val contentOk = rows.count { it.content.endsWith("字") }
    println(
        "[batch] ===== 汇总：全链通过 $okCount/${rows.size} ｜ " +
            "搜索 $searchOk ｜ 详情 $detailOk ｜ 目录 $tocOk ｜ 正文 $contentOk ====="
    )
    val report = buildJsonObject {
        put("keyword", keyword)
        put("total", rows.size)
        put("ok", okCount)
        put("searchOk", searchOk)
        put("detailOk", detailOk)
        put("tocOk", tocOk)
        put("contentOk", contentOk)
        put("rows", buildJsonArray {
            rows.forEach { r ->
                add(
                    buildJsonObject {
                        put("name", r.name)
                        put("search", r.search)
                        put("detail", r.detail)
                        put("toc", r.toc)
                        put("content", r.content)
                    }
                )
            }
        })
    }
    val out = File("batch-report.json")
    out.writeText(report.toString())
    println("[batch] 报告已写：${out.absolutePath}")
}

/** runner 版正文处理器：不加替换规则、正文原样返回（纯粹验证引擎链路）。 */
private class RunnerContentProcessor : ContentProcessorAccessor {
    override fun getTitleReplaceRules(book: Book): List<ReplaceRule> = emptyList()

    override fun getContent(
        book: Book,
        chapter: BookChapter,
        content: String,
        useReplace: Boolean,
    ): CharSequence = content

    override fun upReplaceRules() = Unit
}

/** runner 版大变量存储（内存实现）。 */
private class RunnerBigData : RuleBigDataProvider {
    private val bookVars = mutableMapOf<String, MutableMap<String, String>>()
    private val chapterVars = mutableMapOf<String, MutableMap<String, String>>()

    override fun putBookVariable(bookUrl: String, key: String, value: String?) {
        val m = bookVars.getOrPut(bookUrl) { mutableMapOf() }
        if (value == null) m.remove(key) else m[key] = value
    }

    override fun getBookVariable(bookUrl: String, key: String?): String? =
        key?.let { bookVars[bookUrl]?.get(it) }

    override fun hasBookVariable(bookUrl: String, key: String): Boolean =
        bookVars[bookUrl]?.containsKey(key) == true

    override fun putChapterVariable(
        bookUrl: String,
        chapterUrl: String,
        key: String,
        value: String?,
    ) {
        val m = chapterVars.getOrPut("$bookUrl|$chapterUrl") { mutableMapOf() }
        if (value == null) m.remove(key) else m[key] = value
    }

    override fun getChapterVariable(
        bookUrl: String,
        chapterUrl: String,
        key: String,
    ): String? = chapterVars["$bookUrl|$chapterUrl"]?.get(key)

    override fun listBookDataDirs(): List<String> = emptyList()

    override fun clearInvalidBookData(bookUrls: Set<String>) = Unit
}

/** 冒烟用图片实现：文本链路不需要图片能力，调用即抛（与未实现语义一致）。 */
private object StubImageOps : ImageOps {
    override fun decode(bytes: ByteArray): ImageRef = unsupported()
    override fun decode(base64: String): ImageRef = unsupported()
    override fun encode(img: ImageRef, format: String, quality: Int): ByteArray = unsupported()
    override fun split(img: ImageRef, rows: Int, cols: Int): List<ImageRef> = unsupported()
    override fun stitch(imgs: List<ImageRef>, direction: String): ImageRef = unsupported()
    override fun crop(img: ImageRef, x: Int, y: Int, w: Int, h: Int): ImageRef = unsupported()
    override fun rotate(img: ImageRef, deg: Int): ImageRef = unsupported()
    override fun flip(img: ImageRef, direction: String): ImageRef = unsupported()
    override fun size(img: ImageRef): Map<String, Int> = unsupported()

    private fun <T> unsupported(): T =
        throw UnsupportedOperationException("runner 未内置图片能力")
}

/** jsLib 共享 scope：内存缓存 + OkHttp 下载（对齐桌面端薄适配语义）。 */
private object RunnerSharedJsScope : QuickJsSharedJsScopeBase() {
    private val mem = LinkedHashMap<String, String>()
    private val client = OkHttpClient()

    override fun cachedJsLibContent(name: String): String? = synchronized(mem) { mem[name] }

    override fun storeJsLibContent(name: String, content: String) {
        synchronized(mem) { mem[name] = content }
    }

    override fun downloadJsLibContent(url: String): String? = runBlocking {
        runCatching {
            client.newCall(Request.Builder().url(url).build()).execute().use { resp ->
                if (resp.isSuccessful) resp.body.string() else null
            }
        }.getOrNull()
    }

    override fun jsLibDownloadFailedException(url: String): Exception =
        NoStackTraceException("下载jsLib-${url}失败")
}
