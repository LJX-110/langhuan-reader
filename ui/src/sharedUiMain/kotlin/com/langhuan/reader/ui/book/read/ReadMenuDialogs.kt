package com.langhuan.reader.ui.book.read

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.constant.AppConst
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.LocalDate
import com.langhuan.reader.data.entities.localDateNow
import com.langhuan.reader.data.entities.localDateParseOrNull
import com.langhuan.reader.data.entities.toYearMonthDay
import com.langhuan.reader.ui.compose.component.AppAlertDialog
import com.langhuan.reader.ui.compose.component.AppNumberField
import com.langhuan.reader.ui.compose.component.AppSelectorDialog
import com.langhuan.reader.ui.compose.component.AppSwitch
import com.langhuan.reader.ui.compose.component.AppTextField
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens

/**
 * 阅读菜单选择器对话框集 (iOS/鸿蒙/desktop 共用, 对照 app 端 ReadMenu 的
 * activity.selector / activity.alert 弹窗):
 * - [ImageStyleDialog]: 图片样式 4 项选择器
 * - [DownloadDialog]: 离线缓存起止章节号
 * - [CharsetDialog]: 文本编码选择器
 *
 * 对话框只负责收集输入 + 改 [Book.config], 落库/重载由调用方 (ReaderRoute) 的
 * onApply 回调执行 (需要 viewModel/DAO 上下文)。
 */

/** 图片样式选择器 (对照 app 端 menu_image_style 的 4 项 selector)。 */
@Composable
fun ImageStyleDialog(
    book: Book,
    onApply: (imageStyle: String) -> Unit,
    onDismiss: () -> Unit,
) {
    val styles = arrayListOf(
        Book.imgStyleDefault, Book.imgStyleFull, Book.imgStyleText, Book.imgStyleSingle
    )
    val labels = arrayListOf("默认", "充满", "文字", "单页")
    val current = styles.indexOf(book.config.imageStyle).coerceAtLeast(0)
    AppSelectorDialog(
        onDismissRequest = onDismiss,
        title = "图片样式",
        items = labels,
        onItemSelected = { index ->
            onApply(styles[index])
        },
    )
}

/** 离线缓存对话框 (对照 app 端 showDownloadDialog: 起始/结束章节号, 章节号从 1 起)。 */
@Composable
fun DownloadDialog(
    book: Book,
    onApply: (start: Int, end: Int) -> Unit,
    onDismiss: () -> Unit,
) {
    var startText by remember { mutableStateOf((book.durChapterIndex + 1).toString()) }
    var endText by remember { mutableStateOf(book.totalChapterNum.toString()) }

    AppAlertDialog(
        onDismissRequest = onDismiss,
        title = "离线缓存",
        okButton = com.langhuan.reader.ui.compose.component.AlertButton(
            text = "确认",
            onClick = {
                val start = startText.toIntOrNull() ?: 0
                val end = endText.toIntOrNull() ?: book.totalChapterNum
                onApply(start, end)
            },
        ),
        cancelButton = com.langhuan.reader.ui.compose.component.AlertButton(text = "取消"),
    ) {
        Column(Modifier.padding(horizontal = DesignTokens.spacingDefault)) {
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = DesignTokens.spacingDefault),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "起始章节",
                    color = AppTheme.colors.primaryText,
                    fontSize = 16.sp,
                    modifier = Modifier.weight(1f),
                )
                AppNumberField(
                    value = startText,
                    onValueChange = { startText = it },
                    modifier = Modifier.width(96.dp),
                )
            }
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = DesignTokens.spacingDefault),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "结束章节",
                    color = AppTheme.colors.primaryText,
                    fontSize = 16.sp,
                    modifier = Modifier.weight(1f),
                )
                AppNumberField(
                    value = endText,
                    onValueChange = { endText = it },
                    modifier = Modifier.width(96.dp),
                )
            }
        }
    }
}

/** 文本编码选择器 (对照 app 端 showCharsetConfig 的 charset 列表)。 */
@Composable
fun CharsetDialog(
    book: Book,
    onApply: (charset: String) -> Unit,
    onDismiss: () -> Unit,
) {
    val current = AppConst.charsets.indexOf(book.charset).coerceAtLeast(0)
    AppSelectorDialog(
        onDismissRequest = onDismiss,
        title = "设置编码",
        items = AppConst.charsets,
        onItemSelected = { index ->
            onApply(AppConst.charsets[index])
        },
    )
}

