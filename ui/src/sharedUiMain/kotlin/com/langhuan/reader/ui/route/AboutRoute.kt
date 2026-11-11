package com.langhuan.reader.ui.route

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import com.langhuan.reader.help.update.AppUpdateManager
import com.langhuan.reader.ui.about.AboutHeaderCard
import com.langhuan.reader.ui.about.AboutScreen
import com.langhuan.reader.ui.about.AboutScreenModel
import com.langhuan.reader.ui.about.AboutUiActions
import com.langhuan.reader.ui.about.AboutUiState
import com.langhuan.reader.ui.compose.component.AppTitleBar
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.root.RouteEntry
import com.langhuan.reader.ui.root.ScreenModelStore
import com.langhuan.reader.ui.widget.dialog.WaitDialog
import kotlinx.coroutines.launch
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.about
import com.langhuan.reader.ui.generated.resources.check_update
import com.langhuan.reader.ui.generated.resources.is_latest_version
import org.jetbrains.compose.resources.stringResource

/**
 * 关于页路由入口：顶部应用名 + 版本号（点按复制），下方只留「检查更新」。
 */
@Composable
fun AboutRoute(
    entry: RouteEntry,
    navigator: AppNavigator,
    screenModelStore: ScreenModelStore,
) {
    val screenModel = screenModelStore.getOrCreateTyped(entry) { AboutScreenModel() }
    val state by screenModel.state.collectAsState()

    val latestVersionStr = stringResource(Res.string.is_latest_version)
    val checkFailedStr = stringResource(Res.string.check_update)
    LaunchedEffect(Unit) {
        val versionName = PlatformCapabilityProviders.get().getAppVersionName().orEmpty()
        screenModel.updateState(
            AboutUiState(
                appVersion = versionName,
                // 入口 gate: 已注册 AppUpdateEnvironment 的端才显示
                showCheckUpdate = AppUpdateManager.isAvailable(),
            )
        )
    }

    val scope = rememberCoroutineScope()
    val actions = object : AboutUiActions {
        override fun onCopyVersion() {
            PlatformCapabilityProviders.get().copyToClipboard(state.appVersion)
        }

        override fun onCheckUpdate() {
            scope.launch { screenModel.checkUpdate(latestVersionStr, checkFailedStr) }
        }
    }

    Column(Modifier.fillMaxSize()) {
        AppTitleBar(
            title = stringResource(Res.string.about),
            onBack = { navigator.pop() },
        )
        AboutHeaderCard(
            version = state.appVersion,
            onCopyVersion = actions::onCopyVersion,
        )
        AboutScreen(state = state, actions = actions)
    }

    WaitDialog(visible = state.checkingUpdate, onDismissRequest = {})
}
