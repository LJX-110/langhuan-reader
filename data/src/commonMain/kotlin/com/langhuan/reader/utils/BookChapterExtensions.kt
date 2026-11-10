package com.langhuan.reader.utils

import com.langhuan.reader.data.entities.BookChapter

fun BookChapter.internString() {
    title = title.platformIntern()
    bookUrl = bookUrl.platformIntern()
}
