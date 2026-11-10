package com.langhuan.reader.ui.route

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.ui.book.manga.extension.MangaReposScreen
import com.langhuan.reader.ui.book.manga.extension.MangaReposScreenModel
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.RouteEntry
import com.langhuan.reader.ui.root.ScreenModelStore

/** 漫画插件仓库管理页路由: 绑定 [MangaReposScreenModel] 并渲染 [MangaReposScreen]。 */
@Composable
fun MangaExtensionReposRoute(
    entry: RouteEntry,
    navigator: AppNavigator,
    screenModelStore: ScreenModelStore,
) {
    val screenModel = screenModelStore.getOrCreateTyped(entry) {
        MangaReposScreenModel(toast = { Toasters.get().toast(it) })
    }
    val state by screenModel.state.collectAsState()

    MangaReposScreen(
        state = state,
        onBack = { navigator.pop() },
        onAddRepo = screenModel::addRepo,
        onRemoveRepo = screenModel::removeRepo,
    )
}
