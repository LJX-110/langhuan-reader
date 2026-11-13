package com.langhuan.reader.ui.main.local

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.ui.bookshelf.shelf.LanghuanShelf
import com.langhuan.reader.ui.bookshelf.toBookItemUi
import com.langhuan.reader.ui.compose.component.LanghuanPageHeader
import com.langhuan.reader.ui.compose.component.LanghuanSearchEntry
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.ic_add
import com.langhuan.reader.ui.generated.resources.ic_import
import com.langhuan.reader.ui.generated.resources.import_bookshelf
import com.langhuan.reader.ui.generated.resources.import_local
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.toReadRoute
import com.langhuan.reader.ui.root.toRouteRef
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringResource

/**
 * 「本地」页签：只列本地导入的书。
 *
 * 数据直接读 [com.langhuan.reader.data.dao.BookDao.flowLocal]（type 位含 BookType.local），
 * 不新建业务层；列表渲染复用书架同一套 [LanghuanShelf]，因此在书架页做的
 * 外观改造（3D 书架、纸张配色）会自动落到这里。
 *
 * 导入入口从书架溢出菜单移到了本页：右上角两个图标 + 空态里的两个按钮。
 *
 * @param active 本页签是否为当前停稳页：不可见时停订阅，与书架 tab 同策略
 * @param onImportLocalBook 选本地文件导入
 * @param onImportBookshelf 粘贴/选文件导入书单
 */
@Composable
internal fun LocalBooksTab(
    navigator: AppNavigator,
    active: Boolean,
    onImportLocalBook: () -> Unit,
    onImportBookshelf: () -> Unit,
) {
    val db = remember { AppDbProviders.get() }
    val books by produceState(initialValue = emptyList<Book>(), active) {
        if (!active) return@produceState
        db.bookDao.flowLocal().collect { value = it }
    }
    // 渲染层只吃 Ui 模型; 实体按 bookUrl 回查, 供点击跳转与封面解密
    val bookItems = remember(books) { books.map { it.toBookItemUi() } }
    val bookEntities = remember(books) { books.associateBy { it.bookUrl } }
    val colors = AppTheme.colors
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        LanghuanPageHeader(title = "本地") {
            IconButton(onClick = onImportLocalBook) {
                Icon(
                    painter = painterResource(Res.drawable.ic_add),
                    contentDescription = stringResource(Res.string.import_local),
                    tint = colors.primaryText,
                )
            }
            IconButton(onClick = onImportBookshelf) {
                Icon(
                    painter = painterResource(Res.drawable.ic_import),
                    contentDescription = stringResource(Res.string.import_bookshelf),
                    tint = colors.primaryText,
                )
            }
        }
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
            emptyContent = {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Text(
                        text = "本地还没有书",
                        color = colors.summaryText,
                        fontSize = 14.sp,
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        LocalEmptyAction(
                            label = stringResource(Res.string.import_local),
                            onClick = onImportLocalBook,
                        )
                        LocalEmptyAction(
                            label = stringResource(Res.string.import_bookshelf),
                            onClick = onImportBookshelf,
                        )
                    }
                }
            },
        )
    }
}

/** 空态动作：一枚浅底胶囊，不画边框，和阅读面板的次级按钮同一种感觉。 */
@Composable
private fun LocalEmptyAction(label: String, onClick: () -> Unit) {
    val colors = AppTheme.colors
    Text(
        text = label,
        color = colors.accent,
        fontSize = 13.sp,
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(colors.accent.copy(alpha = .10f))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 7.dp),
    )
}
