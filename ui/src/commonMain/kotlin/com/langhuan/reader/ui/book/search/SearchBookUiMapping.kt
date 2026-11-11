package com.langhuan.reader.ui.book.search

import com.langhuan.reader.data.entities.SearchBook
import com.langhuan.reader.help.book.isAudio
import com.langhuan.reader.help.book.isLocal
import com.langhuan.reader.uimodel.BookItemUi

/**
 * SearchBook → UI 展示模型的过渡映射 (P3 搜索/发现结果页)。
 *
 * 与书架映射同口径; 等宿主层接管数据访问后, 本文件随 `:ui -> :data` 一起移除。
 */
internal fun SearchBook.toBookItemUi(): BookItemUi = BookItemUi(
    bookUrl = bookUrl,
    name = name,
    author = author,
    coverUrl = coverUrl,
    origin = origin,
    originName = originName,
    type = type,
    intro = intro,
    kind = kind,
    latestChapterTitle = latestChapterTitle,
    wordCount = wordCount,
    isLocal = isLocal,
    isAudio = isAudio,
)
