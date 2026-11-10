package com.langhuan.reader.ui.route

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.langhuan.reader.ui.book.manga.extension.MangaExtensionScreen
import com.langhuan.reader.ui.book.manga.extension.MangaExtensionScreenModel
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.RouteEntry
import com.langhuan.reader.ui.root.ScreenModelStore

/**
 * 漫画插件管理页路由: 绑定 [MangaExtensionScreenModel] (首入口 init, 幂等) 并渲染
 * [MangaExtensionScreen]; 仓库管理子页 push [AppRoute.MangaExtensionRepos]。
 */
@Composable
fun MangaExtensionRoute(
    entry: RouteEntry,
    navigator: AppNavigator,
    screenModelStore: ScreenModelStore,
) {
    val screenModel = screenModelStore.getOrCreateTyped(entry) {
        MangaExtensionScreenModel()
    }
    val state by screenModel.state.collectAsState()
    val prefDialog by screenModel.prefDialog.collectAsState()
    val searchQuery by screenModel.searchQuery.collectAsState()
    val searchFilterQuery by screenModel.searchFilterQuery.collectAsState()

    MangaExtensionScreen(
        state = state,
        onBack = { navigator.pop() },
        onManageRepos = { navigator.push(AppRoute.MangaExtensionRepos) },
        onInstall = screenModel::install,
        onUpdate = screenModel::update,
        onCancelInstall = screenModel::cancelInstall,
        onUninstall = screenModel::uninstall,
        onTrust = screenModel::trust,
        onRefresh = screenModel::refresh,
        onSelectLanguage = screenModel::selectLanguage,
        onSelectKind = screenModel::selectKind,
        onSelectContent = screenModel::selectContent,
        searchQuery = searchQuery,
        searchFilterQuery = searchFilterQuery,
        onSearchQueryChange = screenModel::setSearchQuery,
        prefDialog = prefDialog,
        onOpenPrefDialog = screenModel::openPrefDialog,
        onSetPreference = screenModel::setPreference,
        onPreferenceClick = screenModel::performPreferenceClick,
        onPreferenceChange = screenModel::applyPreferenceChange,
        onTextItemClick = screenModel::textItemClick,
        onReloadPrefItems = screenModel::reloadPreferences,
        onDismissPrefDialog = screenModel::dismissPrefDialog,
    )
}
