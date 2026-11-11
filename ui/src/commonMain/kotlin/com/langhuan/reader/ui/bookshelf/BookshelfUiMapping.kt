package com.langhuan.reader.ui.bookshelf

import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.BookGroup
import com.langhuan.reader.help.book.isAudio
import com.langhuan.reader.help.book.isLocal
import com.langhuan.reader.uimodel.BookItemUi
import com.langhuan.reader.uimodel.GroupUi

/**
 * 实体 → UI 展示模型的过渡映射 (P3 书架切片)。
 *
 * 目前映射放在 :ui 内, 让页面先只消费 [BookItemUi] / [GroupUi];
 * 等各页迁移完成、宿主层接管数据访问后, 本文件随 `:ui -> :data` 一起移除。
 */
internal fun Book.toBookItemUi(): BookItemUi = BookItemUi(
    bookUrl = bookUrl,
    name = name,
    author = author,
    coverUrl = coverUrl,
    origin = origin,
    originName = originName,
    type = type,
    groupId = group,
    intro = intro,
    kind = kind,
    latestChapterTitle = latestChapterTitle,
    latestChapterTime = latestChapterTime,
    durChapterTitle = durChapterTitle,
    durChapterIndex = durChapterIndex,
    durChapterPos = durChapterPos,
    durChapterTime = durChapterTime,
    totalChapterNum = totalChapterNum,
    unreadCount = getUnreadChapterNum(),
    lastCheckCount = lastCheckCount,
    wordCount = wordCount,
    isLocal = isLocal,
    isAudio = isAudio,
    canUpdate = canUpdate,
    customCoverUrl = customCoverUrl,
    customTag = customTag,
    customIntro = customIntro,
)

internal fun BookGroup.toGroupUi(bookCount: Int? = null): GroupUi = GroupUi(
    groupId = groupId,
    groupName = groupName,
    cover = cover,
    order = order,
    show = show,
    bookSort = bookSort,
    enableRefresh = enableRefresh,
    bookCount = bookCount,
)
