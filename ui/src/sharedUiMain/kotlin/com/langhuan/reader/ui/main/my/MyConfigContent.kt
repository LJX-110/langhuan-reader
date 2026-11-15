package com.langhuan.reader.ui.main.my

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalDensity
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.help.config.ReadBookConfigProviders
import com.langhuan.reader.help.image.DecodedBitmapCache
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.help.update.AppUpdateManager
import com.langhuan.reader.ui.about.checkUpdateAndPrompt
import com.langhuan.reader.ui.book.read.ReadBookEvents
import com.langhuan.reader.ui.book.read.ReadConfigChange
import com.langhuan.reader.ui.compose.component.AlertButton
import com.langhuan.reader.ui.compose.component.AppAlertDialog
import com.langhuan.reader.ui.compose.component.AppSelectorDialog
import com.langhuan.reader.ui.compose.platform.LocalEventBusProvider
import com.langhuan.reader.ui.config.ConfigActionsShared
import com.langhuan.reader.ui.config.LanghuanSkinDialog
import com.langhuan.reader.ui.compose.theme.LanghuanThemes
import com.langhuan.reader.ui.dialog.NumberPickerDialog
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.route.FontSelectDialogHost
import com.langhuan.reader.ui.widget.dialog.WaitDialog
import com.langhuan.reader.utils.format
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.btn_default_s
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.clear_cache
import com.langhuan.reader.ui.generated.resources.clear_cache_success
import com.langhuan.reader.ui.generated.resources.font_weight
import com.langhuan.reader.ui.generated.resources.interface_font_size
import com.langhuan.reader.ui.generated.resources.is_latest_version
import com.langhuan.reader.ui.generated.resources.ok
import com.langhuan.reader.ui.generated.resources.shrink_database
import com.langhuan.reader.ui.generated.resources.success
import com.langhuan.reader.ui.generated.resources.sure
import com.langhuan.reader.ui.generated.resources.system_font
import com.langhuan.reader.ui.generated.resources.text_font_weight
import com.langhuan.reader.ui.generated.resources.check_update
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.stringArrayResource
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
    val fontScaleValue = "%.1f×".format(LocalDensity.current.fontScale)
    val readConfig = ReadBookConfigProviders.get()
    val weightNames = stringArrayResource(Res.array.text_font_weight)
    val systemFontStr = stringResource(Res.string.system_font)
    var fontValue by remember {
        mutableStateOf(readConfig.textFont.substringAfterLast('/').ifEmpty { systemFontStr })
    }
    var fontWeight by remember { mutableIntStateOf(readConfig.textBold) }
    val fontWeightValue = weightNames.getOrNull(fontWeight).orEmpty()

    var showSkinDialog by remember { mutableStateOf(false) }
    var showFontSelect by remember { mutableStateOf(false) }
    var showFontWeight by remember { mutableStateOf(false) }
    var showFontScalePicker by remember { mutableStateOf(false) }
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
        themeValue = LanghuanThemes.all.getOrNull(LanghuanThemes.currentIndex())?.name.orEmpty(),
        fontValue = fontValue,
        fontWeightValue = fontWeightValue,
        fontScaleValue = fontScaleValue,
        versionValue = versionName,
        showCheckUpdate = AppUpdateManager.isAvailable(),
        checkingUpdate = checkingUpdate,
        onThemeMode = { showSkinDialog = true },
        onFont = { showFontSelect = true },
        onFontWeight = { showFontWeight = true },
        onFontScale = { showFontScalePicker = true },
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

    // 字体族：与阅读面板共用同一份 ReadBookConfig.textFont，选中后就地更新当前值
    if (showFontSelect) {
        FontSelectDialogHost(
            onDismiss = {
                showFontSelect = false
                fontValue = readConfig.textFont.substringAfterLast('/').ifEmpty { systemFontStr }
            }
        )
    }

    // 字重：0 正常 / 1 粗体 / 2 细体
    if (showFontWeight) {
        AppSelectorDialog(
            onDismissRequest = { showFontWeight = false },
            title = stringResource(Res.string.font_weight),
            items = weightNames,
            onItemSelected = { index ->
                showFontWeight = false
                fontWeight = index
                readConfig.textBold = index
                readConfig.save()
                ReadBookEvents.postConfig(
                    listOf(
                        ReadConfigChange.CHAPTER_STYLE,
                        ReadConfigChange.INVALIDATE_TEXT_PAGE,
                        ReadConfigChange.UP_CONTENT,
                    )
                )
            },
        )
    }

    // 界面字号档位 8..16, 10 = 1.0; 改完广播重建让 LocalDensity 生效
    if (showFontScalePicker) {
        val current = pref.getInt(PreferKey.fontScale, 0).let { if (it == 0) 10 else it }
        NumberPickerDialog(
            title = stringResource(Res.string.interface_font_size),
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
