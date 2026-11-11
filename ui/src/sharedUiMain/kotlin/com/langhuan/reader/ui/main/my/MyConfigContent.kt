package com.langhuan.reader.ui.main.my

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalDensity
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.help.image.DecodedBitmapCache
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.help.update.AppUpdateManager
import com.langhuan.reader.ui.about.checkUpdateAndPrompt
import com.langhuan.reader.ui.compose.component.AlertButton
import com.langhuan.reader.ui.compose.component.AppAlertDialog
import com.langhuan.reader.ui.compose.platform.LocalEventBusProvider
import com.langhuan.reader.ui.config.ConfigActionsShared
import com.langhuan.reader.ui.config.LanghuanSkinDialog
import com.langhuan.reader.ui.dialog.NumberPickerDialog
import com.langhuan.reader.ui.dialog.TextInputDialog
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.widget.dialog.WaitDialog
import com.langhuan.reader.utils.format
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.backup_password
import com.langhuan.reader.ui.generated.resources.btn_default_s
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.clear_cache
import com.langhuan.reader.ui.generated.resources.clear_cache_success
import com.langhuan.reader.ui.generated.resources.font_scale
import com.langhuan.reader.ui.generated.resources.is_latest_version
import com.langhuan.reader.ui.generated.resources.ok
import com.langhuan.reader.ui.generated.resources.set_local_password_summary
import com.langhuan.reader.ui.generated.resources.shrink_database
import com.langhuan.reader.ui.generated.resources.success
import com.langhuan.reader.ui.generated.resources.sure
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
    val pref = PreferenceProviders.get()
    val eventBus = LocalEventBusProvider.current
    val platform = remember { PlatformCapabilityProviders.get() }
    val scope = rememberCoroutineScope()

    // 版本号只读取一次：平台信息在进程内不变
    val versionName = remember { platform.getAppVersionName().orEmpty() }
    val fontScaleValue = "%.1f".format(LocalDensity.current.fontScale)

    var showSkinDialog by remember { mutableStateOf(false) }
    var showFontScalePicker by remember { mutableStateOf(false) }
    var showBackupPasswordDialog by remember { mutableStateOf(false) }
    var showCleanCacheConfirm by remember { mutableStateOf(false) }
    var showShrinkDatabaseConfirm by remember { mutableStateOf(false) }
    var checkingUpdate by remember { mutableStateOf(false) }

    val okStr = stringResource(Res.string.ok)
    val cancelStr = stringResource(Res.string.cancel)
    val sureStr = stringResource(Res.string.sure)
    val successStr = stringResource(Res.string.success)
    val clearCacheSuccessStr = stringResource(Res.string.clear_cache_success)
    val latestVersionStr = stringResource(Res.string.is_latest_version)
    val checkFailedStr = stringResource(Res.string.check_update)

    MyConfigScreen(
        fontScaleValue = fontScaleValue,
        versionValue = versionName,
        showCheckUpdate = AppUpdateManager.isAvailable(),
        checkingUpdate = checkingUpdate,
        onThemeMode = { showSkinDialog = true },
        onFontScale = { showFontScalePicker = true },
        onBookSourceManage = { navigator.push(AppRoute.BookSourceManage) },
        onReplaceManage = { navigator.push(AppRoute.ReplaceRule) },
        onTxtTocRuleManage = { navigator.push(AppRoute.TxtTocRule) },
        onBackupRestore = { navigator.push(AppRoute.BackupConfig) },
        onBackupPassword = { showBackupPasswordDialog = true },
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

    // 字体档位 8..16, 10 = 1.0; 改完广播重建让 LocalDensity 生效
    if (showFontScalePicker) {
        val current = pref.getInt(PreferKey.fontScale, 0).let { if (it == 0) 10 else it }
        NumberPickerDialog(
            title = stringResource(Res.string.font_scale),
            value = current,
            range = 8..16,
            onConfirm = {
                pref.putInt(PreferKey.fontScale, it)
                eventBus.emitRecreate()
            },
            onDismiss = { showFontScalePicker = false },
            neutralButtonText = stringResource(Res.string.btn_default_s),
            onNeutral = {
                pref.putInt(PreferKey.fontScale, 0)
                eventBus.emitRecreate()
            },
        )
    }

    // 备份密码：新建备份时用于加密，恢复加密备份时仍需同一密码
    if (showBackupPasswordDialog) {
        TextInputDialog(
            title = stringResource(Res.string.backup_password),
            message = stringResource(Res.string.set_local_password_summary),
            hint = "password",
            onConfirm = { password ->
                platform.setLocalPassword(password)
                showBackupPasswordDialog = false
            },
            onDismiss = { showBackupPasswordDialog = false },
        )
    }

    if (showCleanCacheConfirm) {
        AppAlertDialog(
            onDismissRequest = { showCleanCacheConfirm = false },
            title = stringResource(Res.string.clear_cache),
            message = sureStr,
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
            title = sureStr,
            message = stringResource(Res.string.shrink_database),
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
