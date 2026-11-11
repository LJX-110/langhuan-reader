package com.langhuan.reader.ui.book.read.page.entities

@Suppress("unused", "MemberVisibilityCanBePrivate")
data class TextParagraph(
    var num: Int,
    val textLines: ArrayList<TextLine> = arrayListOf(),
) {
    val text: String get() = textLines.joinToString("") { it.text }
    val length: Int get() = text.length
    val firstLine: TextLine get() = textLines.first()
    val lastLine: TextLine get() = textLines.last()
    val chapterIndices: IntRange get() = firstLine.chapterPosition..lastLine.chapterPosition + lastLine.charSize
    val chapterPosition: Int get() = firstLine.chapterPosition

    /** 段首在章节内的字符偏移（与 durChapterPos / 书签同一账本）。 */
    val startOffset: Int get() = firstLine.chapterPosition

    /** 段尾（不含）在章节内的字符偏移。 */
    val endOffset: Int get() = lastLine.chapterPosition + lastLine.charSize
    val realNum: Int get() = firstLine.paragraphNum
    val isParagraphEnd: Boolean get() = lastLine.isParagraphEnd

}
