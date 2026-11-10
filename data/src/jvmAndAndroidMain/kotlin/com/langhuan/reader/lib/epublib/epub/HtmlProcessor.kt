package com.langhuan.reader.lib.epublib.epub

import com.langhuan.reader.lib.epublib.domain.Resource

@kotlin.Suppress("unused")
interface HtmlProcessor {
    fun processHtmlResource(resource: Resource?, out: java.io.OutputStream?)
}
