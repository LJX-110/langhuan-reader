package com.langhuan.reader.ui.book.manga.extension

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.langhuan.reader.model.webBook.PluginFilterSession
import com.langhuan.reader.ui.compose.component.AppChipRow
import com.langhuan.reader.ui.compose.component.AppChipRowOption
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.manga_search_filters
import com.langhuan.reader.ui.generated.resources.reset
import org.jetbrains.compose.resources.stringResource

/**
 * 插件源筛选入口行 (发现页筛选分类 / 搜索页按源区块共用): `[筛选] [重置]`。
 *
 * 面板本身收进 [PluginFilterDialog] —— 选项多的源 (如 hanime1 的標籤分类) 内联会把结果区挤没。
 * 筛选状态由宿主 VM 持有的会话实例承载 (与取数委派同一份), 对话框内改动只在关闭时经
 * [onApplied] 上报一次 (改多项只重取一次); [onReset] 重建会话为源默认 (宿主换新实例后重取数)。
 */
@Composable
fun PluginFilterEntryRow(
    session: PluginFilterSession,
    onApplied: () -> Unit,
    onReset: () -> Unit,
    onEditingChanged: (Boolean) -> Unit = {},
) {
    var dialogOpen by remember(session) { mutableStateOf(false) }

    AppChipRow {
        AppChipRowOption(
            text = stringResource(Res.string.manga_search_filters),
            onClick = {
                dialogOpen = true
                onEditingChanged(true)
            },
        )
        AppChipRowOption(
            text = stringResource(Res.string.reset),
            onClick = onReset,
        )
    }

    if (dialogOpen) {
        PluginFilterDialog(
            session = session,
            onDismiss = { changed ->
                dialogOpen = false
                if (changed) onApplied()
                onEditingChanged(false)
            },
        )
    }
}
