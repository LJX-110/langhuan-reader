package com.langhuan.reader.ui.book.manga.render

import coil3.PlatformContext
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.BookSource
import com.langhuan.reader.help.image.DecodedImageResult
import com.langhuan.reader.help.image.iosCoilImageLoader
import com.langhuan.reader.help.image.loadMangaPage
import com.langhuan.reader.help.image.peekMangaPage
import com.langhuan.reader.help.image.preloadMangaPage

internal actual fun peekMangaPage(url: String, source: BookSource?): DecodedImageResult? =
    iosCoilImageLoader.peekMangaPage(url, source)

internal actual suspend fun loadMangaPage(
    url: String,
    book: Book,
    source: BookSource?,
    skipMemoryCache: Boolean,
): DecodedImageResult? = iosCoilImageLoader.loadMangaPage(
    PlatformContext.INSTANCE, url, book, source, skipMemoryCache
)

internal actual suspend fun preloadMangaPage(url: String, book: Book, source: BookSource?) {
    iosCoilImageLoader.preloadMangaPage(PlatformContext.INSTANCE, url, book, source)
}
