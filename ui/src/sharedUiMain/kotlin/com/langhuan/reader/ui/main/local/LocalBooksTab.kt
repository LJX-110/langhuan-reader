package com.langhuan.reader.ui.main.local

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
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.ui.bookshelf.shelf.LanghuanShelf
import com.langhuan.reader.ui.bookshelf.toBookItemUi
import com.langhuan.reader.ui.compose.component.LanghuanPageHeader
import com.langhuan.reader.ui.compose.component.LanghuanSearchEntry
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.toReadRoute
import com.langhuan.reader.ui.root.toRouteRef

/**
 * 「本地」页签：只列本地导入的书。
 *
 * 数据直接读 [com.langhuan.reader.data.dao.BookDao.flowLocal]（type 位含 BookType.local），
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
    // 渲染层只吃 Ui 模型; 实体按 bookUrl 回查, 供点击跳转与封面解密
    val bookItems = remember(books) { books.map { it.toBookItemUi() } }
    val bookEntities = remember(books) { books.associateBy { it.bookUrl } }
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
            books = bookItems,
            modifier = Modifier.weight(1f),
            coverBook = { bookEntities[it.bookUrl] },
            initialBookUrl = remember(bookItems) {
                bookItems.maxByOrNull { it.durChapterTime }?.bookUrl
            },
            onOpen = { item ->
                bookEntities[item.bookUrl]?.let { navigator.push(it.copy().toReadRoute()) }
            },
            onLongPress = { item ->
                bookEntities[item.bookUrl]?.let {
                    navigator.push(AppRoute.BookInfo(it.copy().toRouteRef()))
                }
            },
        )
    }
}
