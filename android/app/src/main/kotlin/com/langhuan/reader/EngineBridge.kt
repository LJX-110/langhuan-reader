package com.langhuan.reader

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.langhuan.engine.EngineFacade
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/**
 * 原生引擎桥：MethodChannel `langhuan/engine` → facade JSON API。
 *
 * - facade 调用是阻塞式 → 放到 4 线程有界池，不占主线程；
 * - 回包在主线程（MethodChannel.Result 要求）；
 * - 引擎初始化（EngineFacade.init）惰性执行、一次；支持 cancel(requestId)。
 */
object EngineBridge {

    /**
     * 受限线程池：4 并发 + 有界队列，避免慢源无限堆积。
     * facade 调用是阻塞式，每次请求独占一个线程；队列满时明确返回 engine_busy。
     */
    private val executor = ThreadPoolExecutor(
        4,
        4,
        30,
        TimeUnit.SECONDS,
        ArrayBlockingQueue<Runnable>(64),
    ) { r -> Thread(r, "langhuan-engine") }

    /** requestId → 当前执行线程；用于 cancel（运行中的请求）。 */
    private val running = ConcurrentHashMap<String, Thread>()

    /**
     * 看门狗：Dart 侧超时后仍可能留下阻塞调用，这里在 75s 后强制中断线程，
     * 避免 4 个卡死请求永久占满执行位（Dart 列表 20s / 正文 60s，留余量）。
     */
    private val watchdog = Executors.newSingleThreadScheduledExecutor { r ->
        Thread(r, "langhuan-watchdog").apply { isDaemon = true }
    }

    /** 原生日志 → Dart 日志页（EventChannel `langhuan/engine_log`）。 */
    private var logSink: EventChannel.EventSink? = null
    private val logBacklog = ArrayDeque<String>()

    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var initialized = false

    fun attach(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        EventChannel(messenger, "langhuan/engine_log").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    logSink = events
                    flushBacklog()
                }

                override fun onCancel(arguments: Any?) {
                    logSink = null
                }
            },
        )
        MethodChannel(messenger, "langhuan/engine").setMethodCallHandler { call, result ->
            when (call.method) {
                "ping" -> result.success(true)
                "cancel" -> {
                    val requestId = call.argument<String>("requestId").orEmpty()
                    running.remove(requestId)?.interrupt()
                    result.success(true)
                }
                "cookie", "clearCookies", "cacheStats", "clearEngineCache",
                "convertChinese" ->
                    dispatch(app, call, result)
                "search", "explore", "bookInfo", "toc", "content" -> {
                    val source = call.argument<String>("source")
                    if (source.isNullOrEmpty()) {
                        result.error("bad_args", "source is required", null)
                        return@setMethodCallHandler
                    }
                    dispatch(app, call, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun dispatch(
        app: Context,
        call: io.flutter.plugin.common.MethodCall,
        result: MethodChannel.Result,
    ) {
        val requestId = call.argument<String>("requestId") ?: "auto-${System.nanoTime()}"
        try {
            executor.execute {
                running[requestId] = Thread.currentThread()
                val guard = watchdog.schedule(
                    { running[requestId]?.interrupt() },
                    75,
                    TimeUnit.SECONDS,
                )
                val (json, error) = try {
                    ensureInit(app)
                    call.args() to null
                } catch (e: Exception) {
                    null to e
                } finally {
                    guard.cancel(false)
                    running.remove(requestId)
                }
                mainHandler.post {
                    if (error != null) {
                        result.error(errorCode(error), error.message, null)
                    } else {
                        result.success(json)
                    }
                }
            }
        } catch (_: RejectedExecutionException) {
            result.error("engine_busy", "引擎繁忙，请稍后重试", null)
        }
    }

    /**
     * 结构化错误码：Dart 侧按 code 决定用户文案，不直接展示异常字符串。
     * 未识别的异常一律 engine_error，细节留在日志里。
     */
    private fun errorCode(e: Throwable): String = when (e) {
        is InterruptedException -> "engine_cancelled"
        is java.util.concurrent.TimeoutException, is java.net.SocketTimeoutException ->
            "engine_timeout"
        is java.net.UnknownHostException, is java.net.ConnectException, is java.io.IOException ->
            "engine_network"
        else -> "engine_error"
    }

    private fun ensureInit(app: Context) {
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            EngineFacade.logSink = { line ->
                Log.d("LanghuanEngine", line)
                emitLog(line)
            }
            EngineFacade.init(app)
            initialized = true
        }
    }

    /** 日志统一在主线程投递；未监听时先入环形缓冲，onListen 后补发。 */
    private fun emitLog(line: String) {
        mainHandler.post {
            val sink = logSink
            if (sink == null) {
                synchronized(logBacklog) {
                    if (logBacklog.size >= 200) logBacklog.removeFirst()
                    logBacklog.addLast(line)
                }
            } else {
                runCatching { sink.success(line) }
            }
        }
    }

    private fun flushBacklog() {
        mainHandler.post {
            val sink = logSink ?: return@post
            val pending = synchronized(logBacklog) {
                logBacklog.toList().also { logBacklog.clear() }
            }
            pending.forEach { line -> runCatching { sink.success(line) } }
        }
    }

    /** 把一次调用翻译成 facade 的 JSON 进出。 */
    private fun io.flutter.plugin.common.MethodCall.args(): String = when (method) {
        "cookie" -> EngineFacade.cookieHeader(argument<String>("url").orEmpty())
        "clearCookies" -> EngineFacade.clearCookies()
        "cacheStats" -> EngineFacade.cacheStats()
        "clearEngineCache" -> EngineFacade.clearEngineCache()
        "convertChinese" -> EngineFacade.convertChinese(
            argument<String>("text").orEmpty(),
            argument<Boolean>("traditional") ?: false,
        )
        "search" -> EngineFacade.search(
            argument<String>("source").orEmpty(),
            argument<String>("keyword").orEmpty(),
            argument<Int>("page") ?: 1,
            argument<String>("nextPageUrl"),
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
