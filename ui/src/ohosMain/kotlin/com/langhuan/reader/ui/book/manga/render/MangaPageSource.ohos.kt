package com.langhuan.reader.ui.book.manga.render

import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.BookSource
import com.langhuan.reader.help.coroutine.IoDispatcher
import com.langhuan.reader.help.image.DecodedBitmapCache
import com.langhuan.reader.help.image.DecodedImageResult
import com.langhuan.reader.help.image.MangaImageBytesLoader
import com.langhuan.reader.help.image.decodeImageAuto
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.withContext

/**
 * 鸿蒙无 coil3 变体 (`nonOhosUiMain` 就是为此存在), 故保留手写链路:
 * [DecodedBitmapCache] 当内存缓存 + [MangaImageBytesLoader] 取字节 + [decodeImageAuto] 解码。
 *
 * fork 生态补齐 coil3 的 ohosArm64 变体后, 本文件可删, 直接复用 jvm/iOS 的 Coil3 actual。
 */
internal actual fun peekMangaPage(url: String, source: BookSource?): DecodedImageResult? =
    DecodedBitmapCache.get(mangaCacheKey(url, source))?.let { DecodedImageResult.Static(it) }

internal actual suspend fun loadMangaPage(
    url: String,
    book: Book,
    source: BookSource?,
    skipMemoryCache: Boolean,
): DecodedImageResult? {
    val key = mangaCacheKey(url, source)
    if (!skipMemoryCache) {
        DecodedBitmapCache.get(key)?.let { return DecodedImageResult.Static(it) }
    }
    val bytes = withContext(IoDispatcher) {
        runCatching {
            MangaImageBytesLoader.load(url, book, source, currentCoroutineContext())
        }.getOrNull()
    }
    if (bytes == null || bytes.isEmpty()) return null
    val decoded = withContext(Dispatchers.Default) { decodeImageAuto(bytes) } ?: return null
    if (decoded is DecodedImageResult.Static) DecodedBitmapCache.put(key, decoded.bitmap)
    return decoded
}

internal actual suspend fun preloadMangaPage(url: String, book: Book, source: BookSource?) {
    loadMangaPage(url, book, source, skipMemoryCache = false)
}
