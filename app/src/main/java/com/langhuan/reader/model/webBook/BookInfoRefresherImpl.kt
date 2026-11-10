package com.langhuan.reader.model.webBook

import com.langhuan.reader.data.entities.BaseSource
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.BookSource

/**
 * [BookInfoRefresher] 安卓实现: 委托给 [WebBook.getBookInfoAwait]。
 *
 * 注册时机: App.onCreate 调 [registerAndroidBookInfoRefresher]。
 *
 * P2 Step 2: 解除 AnalyzeRule→WebBook 直接依赖,
 * 让 AnalyzeRule 主体下沉 shared 后经 [BookInfoRefreshers] 反向调用。
 */
object BookInfoRefresherImpl : BookInfoRefresher {
    override suspend fun refreshBookInfo(bookSource: BaseSource, book: Any, canReName: Boolean) {
        WebBook.getBookInfoAwait(
            bookSource as BookSource,
            book as Book,
            canReName,
        )
    }
}

/** 安卓宿主启动早期注册 BookInfoRefresher。 */
fun registerAndroidBookInfoRefresher() {
    BookInfoRefreshers.register(BookInfoRefresherImpl)
}
