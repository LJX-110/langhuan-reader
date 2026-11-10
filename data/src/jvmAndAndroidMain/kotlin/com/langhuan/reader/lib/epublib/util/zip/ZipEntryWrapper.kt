package com.langhuan.reader.lib.epublib.util.zip

import java.util.zip.ZipEntry

class ZipEntryWrapper(private val zipEntry: Any) {
    init {
        require(
            zipEntry is ZipEntry || zipEntry is AndroidZipEntry
                || zipEntry is com.langhuan.reader.model.fileBook.ZipEntry
        ) { "使用了不支持的类" }
    }

    constructor(zipEntry: ZipEntry) : this(zipEntry as Any)
    constructor(zipEntry: AndroidZipEntry) : this(zipEntry as Any)
    constructor(zipEntry: com.langhuan.reader.model.fileBook.ZipEntry) : this(zipEntry as Any)

    val isDirectory: Boolean
        get() = when (zipEntry) {
            is ZipEntry -> zipEntry.isDirectory
            is AndroidZipEntry -> zipEntry.isDirectory
            is com.langhuan.reader.model.fileBook.ZipEntry -> zipEntry.isDirectory
            else -> true
        }

    fun getZipEntry(): ZipEntry = zipEntry as ZipEntry

    val androidZipEntry: AndroidZipEntry get() = zipEntry as AndroidZipEntry

    val remoteZipEntry: com.langhuan.reader.model.fileBook.ZipEntry
        get() = zipEntry as com.langhuan.reader.model.fileBook.ZipEntry

    val name: String?
        get() = when (zipEntry) {
            is ZipEntry -> zipEntry.name
            is AndroidZipEntry -> zipEntry.name
            is com.langhuan.reader.model.fileBook.ZipEntry -> zipEntry.name
            else -> null
        }

    val size: Long
        get() = when (zipEntry) {
            is ZipEntry -> zipEntry.size
            is AndroidZipEntry -> zipEntry.getSize()
            is com.langhuan.reader.model.fileBook.ZipEntry -> zipEntry.size
            else -> -1
        }
}
