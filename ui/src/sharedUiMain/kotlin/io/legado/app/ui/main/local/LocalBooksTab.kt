package io.legado.app.ui.main.local

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import io.legado.app.data.AppDbProviders
import io.legado.app.data.entities.Book
import io.legado.app.ui.bookshelf.shelf.LanghuanShelf
import io.legado.app.ui.compose.component.LanghuanPageHeader
import io.legado.app.ui.compose.component.LanghuanSearchEntry
import io.legado.app.ui.root.AppNavigator
import io.legado.app.ui.root.AppRoute
import io.legado.app.ui.root.toReadRoute
import io.legado.app.ui.root.toRouteRef

/**
 * 「本地」页签：只列本地导入的书。
 *
 * 数据直接读 [io.legado.app.data.dao.BookDao.flowLocal]（type 位含 BookType.local），
 * 不新建业务层；列表渲染复用书架同一套 [ShelfBooksContent]，因此在书架页做的
 * 外观改造（3D 书架、纸张配色）会自动落到这里。
 *
 * @param active 本页签是否为当前停稳页：不可见时停订阅，与书架 tab 同策略
 */
@Composable
internal fun LocalBooksTab(
    navigator: AppNavigator,
    active: Boolean,
) {
    val db = remember { AppDbProviders.get() }
    val books by produceState(initialValue = emptyList<Book>(), active) {
        if (!active) return@produceState
        db.bookDao.flowLocal().collect { value = it }
    }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        LanghuanPageHeader(title = "本地")
        Spacer(Modifier.height(8.dp))
        LanghuanSearchEntry(
            hint = "搜索本地书籍",
            onClick = { navigator.push(AppRoute.Search()) },
            modifier = Modifier.padding(horizontal = 20.dp),
        )
        Spacer(Modifier.height(10.dp))
        LanghuanShelf(
            books = books,
            modifier = Modifier.weight(1f),
            initialBookUrl = remember(books) {
                books.maxByOrNull { it.durChapterTime }?.bookUrl
            },
            onOpen = { book ->
                val route = book.copy().toReadRoute()
                navigator.push(route)
            },
            onLongPress = { book ->
                navigator.push(AppRoute.BookInfo(book.copy().toRouteRef()))
            },
        )
    }
}
