package com.langhuan.reader.ui.book.manga.entities

import com.langhuan.reader.data.entities.BookChapter

data class MangaChapter(
    val chapter: BookChapter,
    val pages: List<BaseMangaPage>,
    val imageCount: Int
)
