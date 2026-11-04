package com.langhuan.engine

import android.content.Context
import io.legado.app.constant.AndroidIdHolder
import io.legado.app.data.entities.BookSource
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
import io.legado.app.help.source.SourceCacheProviders
import io.legado.app.help.source.SourceDebugLogger
import io.legado.app.help.source.SourceDebugLoggers
import io.legado.app.help.source.SourceNetworkProviders
import io.legado.app.data.AppDatabaseProviders
import io.legado.app.data.AppDbProviders
import io.legado.app.model.SharedJsScope
import io.legado.app.model.script.JsBindingInjector
import io.legado.app.model.script.JsEngines
import io.legado.app.model.script.quickjs.QuickJsJsEngine
import io.legado.app.model.script.quickjs.QuickJsSharedJsScopeBase
import io.legado.app.model.webBook.WebBook
import kotlinx.coroutines.runBlocking
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

    /** 引擎日志回流（琅嬛阁日志页用；由宿主设置）。 */
    @Volatile
    var logSink: ((String) -> Unit)? = null

    fun init(context: Context) {
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            initialized = true
            val app = context.applicationContext
            System.setProperty(
                "legado.portable.root",
                File(app.filesDir, "legado").apply { mkdirs() }.absolutePath,
            )
            AndroidIdHolder.value = "langhuan-engine-01"

            // JS 引擎 + 绑定（quickjs-android-native 随 :modules:quickjs 打包）
            JsBindingInjector.registerImageOps(NoopImageOps)
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

            // 缓存 / cookie / 大变量 / 正文处理
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
        }
    }

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        explicitNulls = false
    }

    /** 搜索：书源 JSON + 关键词 → `{ok, hits:[{name,author,coverUrl,bookUrl,lastChapter,intro,kind}], error}`。 */
    fun search(sourceJson: String, keyword: String): String = runBlocking {
        val source = try {
            json.decodeFromString(BookSource.serializer(), sourceJson)
        } catch (e: Exception) {
            return@runBlocking errorJson("书源 JSON 解析失败: ${e.message}")
        }
        try {
            val page = WebBook.getBookListAwait(source, keyword, 1)
            buildJsonObject {
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
                            }
                        )
                    }
                })
            }.toString()
        } catch (e: Exception) {
            errorJson(e.message ?: e::class.simpleName ?: "搜索失败")
        }
    }

    private fun errorJson(message: String): String =
        buildJsonObject {
            put("ok", false)
            put("error", message.take(200))
        }.toString()
}
