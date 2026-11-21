package com.langhuan.reader.ui.main.my

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.langhuan.reader.help.config.ReadBookConfigProviders
import com.langhuan.reader.help.image.DecodedBitmapCache
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.help.update.AppUpdateManager
import com.langhuan.reader.ui.about.checkUpdateAndPrompt
import com.langhuan.reader.ui.compose.component.AlertButton
import com.langhuan.reader.ui.compose.component.AppAlertDialog
import com.langhuan.reader.ui.config.ConfigActionsShared
import com.langhuan.reader.ui.config.LanghuanSkinDialog
import com.langhuan.reader.ui.compose.theme.LanghuanThemes
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.widget.dialog.WaitDialog
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.clear_cache
import com.langhuan.reader.ui.generated.resources.clear_cache_success
import com.langhuan.reader.ui.generated.resources.is_latest_version
import com.langhuan.reader.ui.generated.resources.ok
import com.langhuan.reader.ui.generated.resources.shrink_database
import com.langhuan.reader.ui.generated.resources.success

import com.langhuan.reader.ui.generated.resources.system_font
import com.langhuan.reader.ui.generated.resources.check_update
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.stringResource

/**
 * 「我的」页内容宿主：把面板回调接到弹窗 / 平台能力 / 导航。
 *
 * tab 与 push 路由共用这一份，避免两处各写一套弹窗。
 */
@Composable
fun MyConfigContent(
    navigator: AppNavigator,
) {
    val platform = remember { PlatformCapabilityProviders.get() }
    val scope = rememberCoroutineScope()

    // 版本号只读取一次：平台信息在进程内不变
    val versionName = remember { platform.getAppVersionName().orEmpty() }
    val readConfig = ReadBookConfigProviders.get()
    val systemFontStr = stringResource(Res.string.system_font)
    var fontValue by remember {
        mutableStateOf(readConfig.textFont.substringAfterLast('/').ifEmpty { systemFontStr })
    }

    var showSkinDialog by remember { mutableStateOf(false) }
    var showFontSettings by remember { mutableStateOf(false) }
    var showCleanCacheConfirm by remember { mutableStateOf(false) }
    var showShrinkDatabaseConfirm by remember { mutableStateOf(false) }
    var checkingUpdate by remember { mutableStateOf(false) }

    val okStr = stringResource(Res.string.ok)
    val cancelStr = stringResource(Res.string.cancel)
    val successStr = stringResource(Res.string.success)
    val clearCacheSuccessStr = stringResource(Res.string.clear_cache_success)
    val latestVersionStr = stringResource(Res.string.is_latest_version)
    val checkFailedStr = stringResource(Res.string.check_update)

    MyConfigScreen(
        themeValue = LanghuanThemes.all.getOrNull(LanghuanThemes.currentIndex())?.name.orEmpty(),
        fontValue = fontValue,
        versionValue = versionName,
        showCheckUpdate = AppUpdateManager.isAvailable(),
        checkingUpdate = checkingUpdate,
        onThemeMode = { showSkinDialog = true },
        onFont = { showFontSettings = true },
        onBottomNav = { platform.showBottomNavConfigDialog() },
        onBookSourceManage = { navigator.push(AppRoute.BookSourceManage) },
        onReplaceManage = { navigator.push(AppRoute.ReplaceRule) },
        onTxtTocRuleManage = { navigator.push(AppRoute.TxtTocRule) },
        onBackupRestore = { navigator.push(AppRoute.BackupConfig) },
        onBookmark = { navigator.push(AppRoute.Bookmark()) },
        onReadRecord = { navigator.push(AppRoute.ReadRecord) },
        onCleanCache = { showCleanCacheConfirm = true },
        onShrinkDatabase = { showShrinkDatabaseConfirm = true },
        onAbout = { navigator.push(AppRoute.About) },
        onCheckUpdate = {
            if (!checkingUpdate) {
                scope.launch {
                    checkingUpdate = true
                    try {
                        checkUpdateAndPrompt(
                            silent = false,
                            latestText = latestVersionStr,
                            failedLabel = checkFailedStr,
                        )
                    } finally {
                        checkingUpdate = false
                    }
                }
            }
        },
    )

    if (showSkinDialog) {
        LanghuanSkinDialog(onDismiss = { showSkinDialog = false })
    }

    // 字体：字体族 / 字重 / 界面字号统一收进这一处
    if (showFontSettings) {
        FontSettingsDialog(
            onDismiss = {
                showFontSettings = false
                fontValue = readConfig.textFont.substringAfterLast('/').ifEmpty { systemFontStr }
            }
        )
    }

    if (showCleanCacheConfirm) {
        AppAlertDialog(
            onDismissRequest = { showCleanCacheConfirm = false },
            title = stringResource(Res.string.clear_cache),
            okButton = AlertButton(text = okStr) {
                showCleanCacheConfirm = false
                scope.launch {
                    ConfigActionsShared.clearCache()
                    DecodedBitmapCache.clear()
                    Toasters.get().toast(clearCacheSuccessStr)
                }
            },
            cancelButton = AlertButton(text = cancelStr),
        )
    }

    if (showShrinkDatabaseConfirm) {
        AppAlertDialog(
            onDismissRequest = { showShrinkDatabaseConfirm = false },
            title = stringResource(Res.string.shrink_database),
            okButton = AlertButton(text = okStr) {
                showShrinkDatabaseConfirm = false
                scope.launch {
                    ConfigActionsShared.shrinkDatabase()
                    Toasters.get().toast(successStr)
                }
            },
            cancelButton = AlertButton(text = cancelStr),
        )
    }

    WaitDialog(visible = checkingUpdate, onDismissRequest = {})
}
