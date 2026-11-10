package com.langhuan.reader.ui.book.manage

import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.help.book.BookStorageProviders
import com.langhuan.reader.model.fileBook.FileBook

// iOS/鸿蒙书架管理平台实现: 复用 commonMain 的 BookStorageProviders/FileBook
class NativeBookshelfManagePlatform : BookshelfManagePlatform {

    // migrateBook 用接口默认实现 (直接调下沉后的 Book.migrateTo), 不再自写简化版

    // 列出已缓存章节文件名集合: 委托 BookStorageProviders
    override fun getChapterFiles(book: Book): HashSet<String> {
        return BookStorageProviders.get().getChapterFiles(book).toHashSet()
    }

    // 删除本地书源文件: 与 app/桌面同一条统一入口 (清章节缓存 + 删封面 + 按 deleteOriginal 删源文件);
    // iOS/鸿蒙的目录授权在入口外层包裹
    override fun deleteLocalBook(book: Book, deleteOriginal: Boolean) {
        FileBook.deleteBook(book, deleteOriginal)
    }
}

// iOS/鸿蒙宿主注册入口 (对照 app 端 registerAndroidBookshelfManagePlatform)
fun registerNativeBookshelfManagePlatform() {
    BookshelfManagePlatformProviders.register(NativeBookshelfManagePlatform())
}
