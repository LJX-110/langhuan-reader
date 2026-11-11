package com.langhuan.reader.desktop.model.webBook

import com.langhuan.reader.api.controller.ImageControllerProvider
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.BookChapter
import com.langhuan.reader.data.entities.BookSource
import com.langhuan.reader.help.book.BookImageDownloadShared
import com.langhuan.reader.help.book.isLocal
import com.langhuan.reader.help.file.desktopResolveStoredRef
import com.langhuan.reader.help.http.OkHttpClientProviders
import com.langhuan.reader.utils.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import com.langhuan.reader.ui.generated.resources.Res

/**
 * desktop 端 [ImageControllerProvider] 真实实现 (封面/插图字节流)。
 *
 * 插图链路复用四端统一的 [BookImageDownloadShared] (带书源 header/防盗链下载,
 * 并跑 ImageUtils.decode 执行反爬切片重排与落盘缓存, 与 Android 原版 BookHelp 对齐)。
 */
class DesktopImageControllerProvider : ImageControllerProvider {

    // 按 bookUrl 缓存 book 与 bookSource 快照, 避免每张切片重复查库, 并发安全
    @Volatile
    private var cache: BookSourceCache? = null

    override fun getCover(coverPath: String?): ByteArray? = runCatching {
        if (coverPath.isNullOrBlank()) return@runCatching null
        if (coverPath.startsWith("http://", true) || coverPath.startsWith("https://", true)) {
            return@runCatching runBlocking { downloadBytes(coverPath) }
        }
        val file = desktopResolveStoredRef(coverPath)
        if (file.exists() && file.isFile) file.readBytes() else null
    }.getOrNull()

    override fun getImg(bookUrl: String, src: String, width: Int): ByteArray? = runCatching {
        val cached = resolveBookAndSource(bookUrl) ?: return@runCatching null
        runBlocking {
            withContext(Dispatchers.IO) {
                val chapter = placeholderImageChapter(src, bookUrl)
                BookImageDownloadShared.loadImageBytes(cached.source, cached.book, src, chapter)
            }
        }
    }.getOrNull()

    private fun resolveBookAndSource(bookUrl: String): BookSourceCache? {
        val current = cache
        if (current != null && current.bookUrl == bookUrl) {
            return current
        }
        val book = runBlocking { AppDbProviders.get().bookDao.getBook(bookUrl) } ?: return null
        val source = if (book.isLocal) null else {
            runBlocking { AppDbProviders.get().bookSourceDao.getBookSource(book.origin) }
        }
        val newCache = BookSourceCache(bookUrl, book, source)
        cache = newCache
        return newCache
    }

    private suspend fun downloadBytes(url: String): ByteArray? {
        val client = OkHttpClientProviders.get().okHttpClient
        return try {
            val request = okhttp3.Request.Builder().url(url).build()
            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) response.body.bytes() else null
            }
        } catch (e: Exception) {
            null
        }
    }

    private data class BookSourceCache(
        val bookUrl: String,
        val book: Book,
        val source: BookSource?,
    )

    override fun defaultCoverBytes(): ByteArray? = runCatching {
        runBlocking { Res.readBytes("drawable/image_cover_default.jpg") }
    }.getOrNull()
}

/**
 * 图片缓存占位章节: 路径仅由 book+url 派生, chapter 只参与签名, 占位即可。
 * webBook 图片缓存与 PDF 页渲染缓存 (PDF 渲染后端 DesktopPdfRenderPort) 共用。
 */
fun placeholderImageChapter(url: String, bookUrl: String): BookChapter =
    BookChapter(url = url, bookUrl = bookUrl)

