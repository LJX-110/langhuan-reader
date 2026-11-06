package com.langhuan.reader

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.langhuan.engine.EngineFacade
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * 原生引擎桥：MethodChannel `langhuan/engine` → facade JSON API。
 *
 * - facade 调用是阻塞式 → 全部放到单线程执行器，不占主线程；
 * - 回包在主线程（MethodChannel.Result 要求）；
 * - 引擎初始化（EngineFacade.init）惰性执行、一次。
 */
object EngineBridge {

    /**
     * 受限线程池：搜索 / 发现要并发多源，单线程会整队排队；facade 调用是阻塞式，
     * 每次请求独占一个线程，4 并发在移动端稳当（引擎内部共用 OkHttp 连接池）。
     */
    private val executor = Executors.newFixedThreadPool(4) { r ->
        Thread(r, "langhuan-engine")
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var initialized = false

    fun attach(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "langhuan/engine").setMethodCallHandler { call, result ->
            when (call.method) {
                "ping" -> result.success(true)
                "search", "explore", "bookInfo", "toc", "content" -> {
                    val source = call.argument<String>("source")
                    if (source.isNullOrEmpty()) {
                        result.error("bad_args", "source is required", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        val (json, error) = try {
                            ensureInit(app)
                            call.args() to null
                        } catch (e: Exception) {
                            null to e
                        }
                        mainHandler.post {
                            if (error != null) {
                                result.error("engine_error", error.message, null)
                            } else {
                                result.success(json)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun ensureInit(app: Context) {
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            EngineFacade.logSink = { Log.d("LanghuanEngine", it) }
            EngineFacade.init(app)
            initialized = true
        }
    }

    /** 把一次调用翻译成 facade 的 JSON 进出。 */
    private fun io.flutter.plugin.common.MethodCall.args(): String = when (method) {
        "search" -> EngineFacade.search(
            argument<String>("source").orEmpty(),
            argument<String>("keyword").orEmpty(),
            argument<Int>("page") ?: 1,
        )
        "explore" -> EngineFacade.explore(
            argument<String>("source").orEmpty(),
            argument<String>("key").orEmpty(),
            argument<Int>("page") ?: 1,
            argument<String>("nextPageUrl"),
        )
        "bookInfo" -> EngineFacade.bookInfo(
            argument<String>("source").orEmpty(),
            argument<String>("book").orEmpty(),
        )
        "toc" -> EngineFacade.toc(
            argument<String>("source").orEmpty(),
            argument<String>("book").orEmpty(),
        )
        else -> EngineFacade.content(
            argument<String>("source").orEmpty(),
            argument<String>("book").orEmpty(),
            argument<String>("chapter").orEmpty(),
            argument<String>("nextChapterUrl").orEmpty(),
        )
    }
}
