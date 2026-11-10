package com.langhuan.reader.desktop.help.book

import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.constant.BookType
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.help.AppWebDavShared
import com.langhuan.reader.help.book.LocalBookLocators
import com.langhuan.reader.help.book.getRemoteUrl
import com.langhuan.reader.lib.webdav.WebDav
import com.langhuan.reader.lib.webdav.WebDavException
import com.langhuan.reader.model.fileBook.LocalZipWrapper
import com.langhuan.reader.model.fileBook.RangedSource
import com.langhuan.reader.model.fileBook.RemoteZipWrapper
import com.langhuan.reader.model.fileBook.ZipFileWrapperFactory

/**
 * [ZipFileWrapperFactory] 桌面 JVM 实现。
 *
 * 分派对齐 app 端 `ZipFileWrappers.create`:
 * - `webdav::` / `http(s)://` → [RemoteZipWrapper] (WebDAV 范围读取, 不全量下载)
 * - 本地 .cbz / .zip → [LocalZipWrapper]
 * - 其他本地压缩包 (rar/7z/cbr) → null (desktop 无 libarchive, app 端走 LocalArchiveWrapper)
 *
 * # bookUrl 解析
 * 本地路径经 [LocalBookLocators.get().getReadableFileRef] 解析: 先按 bookUrl 取路径,
 * 引用失效时按文件名在"书籍保存位置"与"导入目录"里找回同名文件 (不回写 bookUrl、不落库):
 * - `file:///C:/path/book.cbz` → `C:\path\book.cbz`
 * - `/path/book.cbz` → 直接当本地路径
 *
 * 注册: desktop `Main.kt` 中
 * `ZipFileWrapperFactoryProviders.register(DesktopZipFileWrapperFactory)`。
 */
object DesktopZipFileWrapperFactory : ZipFileWrapperFactory {

    override fun create(book: Book): ZipFileWrapperFactory.CreateResult? {
        return runCatching {
            if (book.bookUrl.startsWith(BookType.webDavTag) || book.bookUrl.startsWith("http")) {
                return@runCatching createRemote(book)
            }
            val path = LocalBookLocators.get().getReadableFileRef(book) ?: return null
            val lowerPath = path.lowercase()
            if (lowerPath.endsWith(".cbz") || lowerPath.endsWith(".zip")) {
                ZipFileWrapperFactory.CreateResult(LocalZipWrapper(java.io.File(path)))
            } else {
                null
            }
        }.onFailure { AppLog.put("读取Cbz文件失败\n${it.localizedMessage}", it) }.getOrNull()
    }

    /** 远程 cbz: 从 book.variable("cbz:") + wordCount 恢复 zip 元数据, 避免每次重新探测中央目录。 */
    private fun createRemote(book: Book): ZipFileWrapperFactory.CreateResult {
        val url = book.getRemoteUrl() ?: book.bookUrl
        val webdav = runCatching { WebDav.fromPath(url) }.getOrElse {
            AppWebDavShared.authorization?.let { WebDav(url, it) }
                ?: throw WebDavException("No Auth")
        }
        var eocd = 0L
        var central = 0L
        var size = 0L
        book.variable?.takeIf { it.startsWith("cbz:") }?.substring(4)?.split(",")?.let { p ->
            eocd = p.getOrNull(0)?.toLongOrNull() ?: 0L
            central = p.getOrNull(1)?.toLongOrNull() ?: 0L
            size = p.getOrNull(2)?.toLongOrNull() ?: 0L
        }
        val count = book.wordCount?.replace("页", "")?.toIntOrNull() ?: 0
        val source = RangedSource { offset, length, fileSize ->
            webdav.readRange(offset, length, fileSize)
        }
        val wrapper = if (eocd > 0 && central > 0 && count > 0) {
            RemoteZipWrapper(source, book.originName, size, eocd, central, count)
        } else {
            RemoteZipWrapper(source, book.originName, size)
        }
        return ZipFileWrapperFactory.CreateResult(wrapper)
    }
}
