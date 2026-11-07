package io.legado.app.model.chapter

import io.legado.app.data.AppDbProviders
import io.legado.app.data.entities.Book
import io.legado.app.data.entities.BookChapter
import io.legado.app.help.book.ContentProcessorProviders
import io.legado.app.help.book.isNotShelf
import io.legado.app.model.ReadTimeRecorder
import io.legado.app.utils.systemCurrentTimeMillis

/**
 * 阅读进度落库与云端同步 (四模式共用)。
 *
 * 原版由 `Book.saveRead()` 扩展 + `BaseReadViewModel.uploadProgress/syncProgress` 承担;
 * KMP 化后四模式各写一份 (文字 `saveProgressAwait`、漫画 `saveReadAwait`、
 * 音频 `AudioPlayShared.saveRead`、视频 `saveRead`), 且分化出「有没有回写内存 book 实体」
 * 「有没有发 UP_BOOKSHELF」「章名要不要过替换规则」三处差异。此处收敛为单一实现。
 *
 * 章名一律过标题替换规则 + 内存目录优先取章 (原版 `ReadBook.saveRead` 口径);
 * 视频原先直接用 `chapter.title` 不过规则, 是缺陷 (书架/详情显示的章名与阅读页不一致), 不复刻。
 */
object ChapterProgressStore {

    /**
     * 落库当前进度并回写内存 [book] 实体。
     *
     * 内存回写是必需的: 详情页/目录页经 IntentData 交接读的是内存实体, 不回写就停在跳转前那一章。
     * 只 PATCH 进度列而非整行 update: 整行会冲掉后台 updateToc/refreshBookInfo 写入的最新元数据。
     *
     * @param durChapterPos 章内位置; 末页/末图停留时由调用方取负编码 (原版 `durChapterPos * -1`)
     * @param chapter 当前章 (取章名; null 时保留 book 原章名)
     */
    suspend fun save(
        book: Book,
        durChapterIndex: Int,
        durChapterPos: Int,
        chapter: BookChapter?,
    ) {
        val durChapterTitle = chapter?.getDisplayTitle(
            ContentProcessorProviders.get().getTitleReplaceRules(book),
            book.getUseReplaceRule(),
        ) ?: book.durChapterTitle
        val durChapterTime = systemCurrentTimeMillis()
        book.durChapterIndex = durChapterIndex
        book.durChapterPos = durChapterPos
        book.durChapterTitle = durChapterTitle
        book.durChapterTime = durChapterTime
        book.lastCheckCount = 0
        AppDbProviders.get().bookDao.updateProgress(
            bookUrl = book.bookUrl,
            durChapterIndex = durChapterIndex,
            durChapterPos = durChapterPos,
            durChapterTime = durChapterTime,
            durChapterTitle = durChapterTitle,
        )
        ReadTimeRecorder.flushAll()
    }
}
