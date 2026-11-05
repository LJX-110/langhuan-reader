package com.langhuan.engine

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.net.http.SslError
import android.os.Handler
import android.os.Looper
import android.util.AndroidRuntimeException
import android.webkit.CookieManager
import android.webkit.SslErrorHandler
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.legado.app.constant.AppConst.timeLimit
import io.legado.app.exception.NoStackTraceException
import io.legado.app.exception.RegexTimeoutException
import io.legado.app.help.UserAgentProviders
import io.legado.app.help.getUserAgent
import io.legado.app.help.http.BackstageWebViewFactory
import io.legado.app.help.http.BackstageWebViewHandle
import io.legado.app.help.http.CookieStoreProviders
import io.legado.app.help.http.StrResponse
import io.legado.app.utils.EscapeUtils
import io.legado.app.utils.RuleRegexes
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeout
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import java.lang.ref.WeakReference
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * facade 运行期共享件：appContext、主线程投递、后台 IO 作用域。
 *
 * 由 [EngineFacade.init] 早期 [attach]，之后任何引擎调用可用。
 */
internal object FacadeRuntime {

    @Volatile
    private var appContext: Context? = null

    /** 后台 WebView 等异步处理用的进程级作用域。 */
    val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(context: Context) {
        appContext = context.applicationContext
    }

    fun requireContext(): Context =
        appContext ?: error("EngineFacade.init(context) 未调用")

    /** 主线程投递（对照 app 端 runOnUI）。 */
    fun runOnMain(block: () -> Unit) {
        mainHandler.post(block)
    }
}

/**
 * 后台 WebView（反爬 / CF 挑战页源用；移植自 Legado app 端同实现，引擎线 E1）。
 *
 * 相对原实现仅三处宿主替换：
 * - `App.instance` → [FacadeRuntime.requireContext]
 * - `Coroutine.async` → [FacadeRuntime.ioScope]
 * - `runOnUI` → [FacadeRuntime.runOnMain]
 * 另外 `CookieStore`（app 单例）→ [CookieStoreProviders]（facade 已注册 SharedCookieStore）。
 */
internal class BackstageWebView(
    private val url: String? = null,
    private val html: String? = null,
    private val encode: String? = null,
    private val tag: String? = null,
    private val headerMap: Map<String, String>? = null,
    private val sourceRegex: String? = null,
    private val overrideUrlRegex: String? = null,
    private val javaScript: String? = null,
    private val delayTime: Long = 1000L,
) : BackstageWebViewHandle {

    private val mHandler = Handler(Looper.getMainLooper())
    private var callback: Callback? = null
    private var mWebView: WebView? = null

    override suspend fun getStrResponse(): StrResponse = withTimeout(timeLimit) {
        suspendCancellableCoroutine { block ->
            block.invokeOnCancellation {
                FacadeRuntime.runOnMain {
                    destroy()
                }
            }
            callback = object : Callback() {
                override fun onResult(response: StrResponse) {
                    if (!block.isCompleted) {
                        block.resume(response)
                    }
                }

                override fun onError(error: Throwable) {
                    if (!block.isCompleted)
                        block.resumeWithException(error)
                }
            }
            FacadeRuntime.runOnMain {
                try {
                    load()
                } catch (error: Throwable) {
                    block.resumeWithException(error)
                }
            }
        }
    }

    private fun getEncoding(): String = encode ?: "utf-8"

    @Throws(AndroidRuntimeException::class)
    private fun load() {
        val webView = createWebView()
        mWebView = webView
        try {
            when {
                !html.isNullOrEmpty() -> if (url.isNullOrEmpty()) {
                    webView.loadData(html, "text/html", getEncoding())
                } else {
                    webView.loadDataWithBaseURL(url, html, "text/html", getEncoding(), url)
                }

                else -> if (headerMap == null) {
                    webView.loadUrl(url!!)
                } else {
                    webView.loadUrl(url!!, headerMap)
                }
            }
        } catch (e: Exception) {
            callback?.onError(e)
        }
    }

    @SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
    private fun createWebView(): WebView {
        val webView = WebView(FacadeRuntime.requireContext())
        val settings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.blockNetworkImage = true
        settings.userAgentString = headerMap.getUserAgent { UserAgentProviders.getWebViewUA() }
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        if (sourceRegex.isNullOrBlank() && overrideUrlRegex.isNullOrBlank()) {
            webView.webViewClient = HtmlWebViewClient()
        } else {
            webView.webViewClient = SnifferWebClient()
        }
        return webView
    }

    private fun destroy() {
        mWebView?.destroy()
        mWebView = null
    }

    private fun getJs(): String {
        javaScript?.let {
            if (it.isNotEmpty()) {
                return it
            }
        }
        return JS
    }

    private fun setCookie(url: String) {
        tag?.let { key ->
            FacadeRuntime.ioScope.launch {
                val cookie = CookieManager.getInstance().getCookie(url)
                CookieStoreProviders.get()?.setCookie(key, cookie)
            }
        }
    }

    private inner class HtmlWebViewClient : WebViewClient() {

        private var runnable: EvalJsRunnable? = null
        private var isRedirect = false

        override fun shouldOverrideUrlLoading(
            view: WebView,
            request: WebResourceRequest,
        ): Boolean {
            isRedirect = isRedirect || request.isRedirect
            return super.shouldOverrideUrlLoading(view, request)
        }

        override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
            super.onPageStarted(view, url, favicon)
            if (runnable == null) {
                runnable = EvalJsRunnable(view, url, getJs())
            }
            mHandler.removeCallbacks(runnable!!)
            mHandler.postDelayed(runnable!!, delayTime)
        }

        override fun onPageFinished(view: WebView, url: String) {
            super.onPageFinished(view, url)
            setCookie(url)
        }

        @SuppressLint("WebViewClientOnReceivedSslError")
        override fun onReceivedSslError(
            view: WebView?,
            handler: SslErrorHandler?,
            error: SslError?,
        ) {
            handler?.proceed()
        }

        private inner class EvalJsRunnable(
            webView: WebView,
            private val url: String,
            private val mJavaScript: String,
        ) : Runnable {

            var retry = 0
            private val mWebView: WeakReference<WebView> = WeakReference(webView)

            override fun run() {
                mWebView.get()?.evaluateJavascript(mJavaScript) {
                    handleResult(it)
                }
            }

            private fun handleResult(result: String) = FacadeRuntime.ioScope.launch {
                if (result.isNotEmpty() && result != "null") {
                    val content = EscapeUtils.unescapeJson(result)
                        .replace(quoteRegex, "")
                    try {
                        val response = buildStrResponse(content)
                        callback?.onResult(response)
                    } catch (e: Exception) {
                        callback?.onError(e)
                    }
                    mHandler.post {
                        destroy()
                    }
                    return@launch
                }
                if (retry > 30) {
                    callback?.onError(NoStackTraceException("js执行超时"))
                    mHandler.post {
                        destroy()
                    }
                    return@launch
                }
                retry++
                mHandler.postDelayed(this@EvalJsRunnable, 1000)
            }

            private fun buildStrResponse(content: String): StrResponse {
                if (!isRedirect) {
                    return StrResponse(url, content)
                }
                val originUrl = this@BackstageWebView.url ?: url
                val originResponse = Response.Builder()
                    .code(302)
                    .request(Request.Builder().url(originUrl).build())
                    .protocol(Protocol.HTTP_1_1)
                    .message("Found")
                    .build()
                val response = Response.Builder()
                    .code(200)
                    .request(Request.Builder().url(url).build())
                    .protocol(Protocol.HTTP_1_1)
                    .message("OK")
                    .priorResponse(originResponse)
                    .build()
                return StrResponse(response, content)
            }
        }
    }

    /**
     * 嗅探正则的全量匹配（对照原 `url.matches(pattern.toRegex())`）。
     * 经 [RuleRegexes] 平台实现匹配并带时间上限；编译失败或超时按“未命中”处理。
     */
    private fun matchesEntire(text: String, pattern: String): Boolean = try {
        RuleRegexes.get()
            .matchesEntire(text, pattern, multiline = false, timeout = SNIFF_REGEX_TIMEOUT)
    } catch (_: RegexTimeoutException) {
        false
    }

    private inner class SnifferWebClient : WebViewClient() {

        override fun shouldOverrideUrlLoading(
            view: WebView,
            request: WebResourceRequest,
        ): Boolean {
            if (shouldOverrideUrlLoading(request.url.toString())) {
                return true
            }
            return super.shouldOverrideUrlLoading(view, request)
        }

        @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION", "KotlinRedundantDiagnosticSuppress")
        override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
            if (shouldOverrideUrlLoading(url)) {
                return true
            }
            return super.shouldOverrideUrlLoading(view, url)
        }

        private fun shouldOverrideUrlLoading(requestUrl: String): Boolean {
            overrideUrlRegex?.let {
                if (matchesEntire(requestUrl, it)) {
                    try {
                        val response = StrResponse(url!!, requestUrl)
                        callback?.onResult(response)
                    } catch (e: Exception) {
                        callback?.onError(e)
                    }
                    destroy()
                    return true
                }
            }
            return false
        }

        override fun onLoadResource(view: WebView, resUrl: String) {
            sourceRegex?.let {
                if (matchesEntire(resUrl, it)) {
                    try {
                        val response = StrResponse(url!!, resUrl)
                        callback?.onResult(response)
                    } catch (e: Exception) {
                        callback?.onError(e)
                    }
                    destroy()
                }
            }
        }

        override fun onPageStarted(webView: WebView, url: String, favicon: Bitmap?) {
            super.onPageStarted(webView, url, favicon)
            if (!javaScript.isNullOrEmpty()) {
                val runnable = LoadJsRunnable(webView, javaScript)
                mHandler.postDelayed(runnable, delayTime)
            }
        }

        override fun onPageFinished(webView: WebView, url: String) {
            super.onPageFinished(webView, url)
            setCookie(url)
        }

        @SuppressLint("WebViewClientOnReceivedSslError")
        override fun onReceivedSslError(
            view: WebView?,
            handler: SslErrorHandler?,
            error: SslError?,
        ) {
            handler?.proceed()
        }

        private inner class LoadJsRunnable(
            webView: WebView,
            private val mJavaScript: String?,
        ) : Runnable {

            private val mWebView: WeakReference<WebView> = WeakReference(webView)

            override fun run() {
                mWebView.get()?.loadUrl("javascript:${mJavaScript}")
            }
        }
    }

    companion object {
        const val JS = "document.documentElement.outerHTML"
        private val quoteRegex = "^\"|\"$".toRegex()

        /** 嗅探正则的单次匹配上限（毫秒），与原实现同口径。 */
        private const val SNIFF_REGEX_TIMEOUT = 1000L
    }

    abstract class Callback {
        abstract fun onResult(response: StrResponse)
        abstract fun onError(error: Throwable)
    }
}

/** [BackstageWebViewFactory] 的 facade 实现；在 [EngineFacade.init] 注册。 */
internal object BackstageWebViewFactoryImpl : BackstageWebViewFactory {

    override fun create(
        url: String?,
        html: String?,
        encode: String?,
        tag: String?,
        headerMap: Map<String, String>?,
        sourceRegex: String?,
        overrideUrlRegex: String?,
        javaScript: String?,
        delayTime: Long,
    ): BackstageWebViewHandle = BackstageWebView(
        url = url,
        html = html,
        encode = encode,
        tag = tag,
        headerMap = headerMap,
        sourceRegex = sourceRegex,
        overrideUrlRegex = overrideUrlRegex,
        javaScript = javaScript,
        delayTime = delayTime,
    )
}
