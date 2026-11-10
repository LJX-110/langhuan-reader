package com.langhuan.reader.lib.epublib.epub

import com.langhuan.reader.lib.epublib.domain.EpubBook

/**
 * Post-processes a book.
 * 
 * 
 * Can be used to clean up a book after reading or before writing.
 * 
 * @author paul
 */
fun interface BookProcessor {
    fun processBook(book: EpubBook?): EpubBook?

    companion object {
        /**
         * A BookProcessor that returns the input book unchanged.
         */
        val IDENTITY_BOOKPROCESSOR: BookProcessor = BookProcessor { book: EpubBook? -> book }
    }
}
