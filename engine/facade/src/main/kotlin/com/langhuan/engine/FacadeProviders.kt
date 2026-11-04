package com.langhuan.engine

import android.content.Context
import android.content.SharedPreferences
import androidx.room3.Room
import androidx.sqlite.driver.AndroidSQLiteDriver
import io.legado.app.data.AppDatabase
import io.legado.app.data.AppDatabaseProvider
import io.legado.app.data.AppDatabaseProviders
import io.legado.app.data.AppDbAccessor
import io.legado.app.data.DatabaseMigrations
import io.legado.app.data.runInImmediateTransaction
import io.legado.app.data.entities.Book
import io.legado.app.data.entities.BookChapter
import io.legado.app.data.entities.ReplaceRule
import io.legado.app.exception.NoStackTraceException
import io.legado.app.help.RuleBigDataProvider
import io.legado.app.help.book.ContentProcessorAccessor
import io.legado.app.help.config.AppConfigAccessor
import io.legado.app.help.config.PreferenceProvider
import io.legado.app.help.image.ImageOps
import io.legado.app.help.image.ImageRef
import io.legado.app.help.source.SourceCacheProvider
import io.legado.app.help.source.SourceNetworkProvider
import io.legado.app.model.script.quickjs.QuickJsSharedJsScopeBase
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.Request

// ============================== 基础件 ==============================

/** 图片能力占位：文本链路不需要（真图解密后续接 BitmapImageOps）。 */
object NoopImageOps : ImageOps {
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
        throw UnsupportedOperationException("engine facade 未内置图片能力")
}

/** jsLib 共享 scope：内存缓存 + OkHttp 下载。 */
class AndroidSharedJsScope : QuickJsSharedJsScopeBase() {
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

/** SharedPreferences 版偏好存储。 */
class SharedPrefsProvider(context: Context) : PreferenceProvider {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("langhuan_engine_config", Context.MODE_PRIVATE)
    private val listeners = mutableListOf<(String) -> Unit>()

    init {
        prefs.registerOnSharedPreferenceChangeListener { _, key ->
            key?.let { k -> listeners.toList().forEach { it(k) } }
        }
    }

    override fun getString(key: String, default: String): String =
        prefs.getString(key, default) ?: default

    override fun getStringOrNull(key: String): String? = prefs.getString(key, null)

    override fun getInt(key: String, default: Int): Int = prefs.getInt(key, default)

    override fun getBoolean(key: String, default: Boolean): Boolean =
        prefs.getBoolean(key, default)

    override fun getLong(key: String, default: Long): Long = prefs.getLong(key, default)

    override fun getFloat(key: String, default: Float): Float = prefs.getFloat(key, default)

    override fun putString(key: String, value: String?) {
        prefs.edit().apply {
            if (value == null) remove(key) else putString(key, value)
        }.apply()
    }

    override fun putInt(key: String, value: Int) {
        prefs.edit().putInt(key, value).apply()
    }

    override fun putBoolean(key: String, value: Boolean) {
        prefs.edit().putBoolean(key, value).apply()
    }

    override fun putLong(key: String, value: Long) {
        prefs.edit().putLong(key, value).apply()
    }

    override fun putFloat(key: String, value: Float) {
        prefs.edit().putFloat(key, value).apply()
    }

    override fun remove(key: String) {
        prefs.edit().remove(key).apply()
    }

    override fun contains(key: String): Boolean = prefs.contains(key)

    override fun getAll(): Map<String, *> = prefs.all

    override fun addPreferenceChangeListener(
        listener: (key: String) -> Unit,
    ): () -> Unit {
        listeners.add(listener)
        return { listeners.remove(listener) }
    }
}

// ============================== 数据与网络件 ==============================

/** 源变量缓存（内存；后续可换 DB 持久化）。 */
class MemorySourceCache : SourceCacheProvider {
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

/** cookie 存储（内存；后续可接 OkHttp CookieJar 持久化）。 */
class MemorySourceNetwork : SourceNetworkProvider {
    private val cookies = mutableMapOf<String, String>()

    override fun getCookie(tag: String): String = cookies[tag] ?: ""
    override fun replaceCookie(tag: String, cookie: String) {
        cookies[tag] = cookie
    }

    override fun removeCookie(tag: String) {
        cookies.remove(tag)
    }
}

/** 大变量存储（内存）。 */
class MemoryBigData : RuleBigDataProvider {
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

/** 正文处理：不加替换规则原样返回（替换规则后续再接 DB）。 */
class PassthroughContentProcessor : ContentProcessorAccessor {
    override fun getTitleReplaceRules(book: Book): List<ReplaceRule> = emptyList()

    override fun getContent(
        book: Book,
        chapter: BookChapter,
        content: String,
        useReplace: Boolean,
    ): CharSequence = content

    override fun upReplaceRules() = Unit
}

// ============================== 数据库件 ==============================

/** Room（AndroidSQLiteDriver + 迁移表）。 */
class AndroidDatabaseProvider(
    private val appContext: Context,
) : AppDatabaseProvider {
    override val appDb: AppDatabase by lazy {
        Room.databaseBuilder(
            appContext,
            AppDatabase::class.java,
            AppDatabase.DATABASE_NAME,
        )
            .setDriver(AndroidSQLiteDriver())
            .addMigrations(*DatabaseMigrations.migrations)
            .build()
    }
}

/** AppDbAccessor：转发全部 DAO（与桌面/runner 同构）。 */
class AndroidDbAccessor : AppDbAccessor {
    private val appDb: AppDatabase get() = AppDatabaseProviders.get().appDb

    override val bookDao get() = appDb.bookDao
    override val bookSourceDao get() = appDb.bookSourceDao
    override val bookChapterDao get() = appDb.bookChapterDao
    override val bookGroupDao get() = appDb.bookGroupDao
    override val keywordHighlightDao get() = appDb.keywordHighlightDao
    override val replaceRuleDao get() = appDb.replaceRuleDao
    override val txtTocRuleDao get() = appDb.txtTocRuleDao
    override val dictRuleDao get() = appDb.dictRuleDao
    override val readRecordDao get() = appDb.readRecordDao
    override val serverDao get() = appDb.serverDao
    override val sourceFilterRuleDao get() = appDb.sourceFilterRuleDao
    override val httpTTSDao get() = appDb.httpTTSDao
    override val cacheDao get() = appDb.cacheDao
    override val cookieDao get() = appDb.cookieDao
    override val ruleSubDao get() = appDb.ruleSubDao
    override val bookmarkDao get() = appDb.bookmarkDao
    override val searchKeywordDao get() = appDb.searchKeywordDao
    override val keyboardAssistsDao get() = appDb.keyboardAssistsDao

    override suspend fun <R> runInTransactionSuspending(block: suspend () -> R): R {
        return appDb.runInImmediateTransaction(block)
    }
}
