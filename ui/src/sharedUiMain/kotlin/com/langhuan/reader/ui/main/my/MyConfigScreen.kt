package com.langhuan.reader.ui.main.my

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.langhuan.reader.ui.compose.component.LanghuanSettingsDivider
import com.langhuan.reader.ui.compose.component.LanghuanSettingsGroup
import com.langhuan.reader.ui.compose.component.LanghuanSettingsRow
import com.langhuan.reader.ui.compose.platform.rememberNavigationBarPaddingValues
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.about
import com.langhuan.reader.ui.generated.resources.backup_password
import com.langhuan.reader.ui.generated.resources.backup_restore
import com.langhuan.reader.ui.generated.resources.book_source
import com.langhuan.reader.ui.generated.resources.book_source_manage
import com.langhuan.reader.ui.generated.resources.bookmark
import com.langhuan.reader.ui.generated.resources.check_update
import com.langhuan.reader.ui.generated.resources.clear_cache
import com.langhuan.reader.ui.generated.resources.font_scale
import com.langhuan.reader.ui.generated.resources.ic_bookmark
import com.langhuan.reader.ui.generated.resources.ic_cfg_about
import com.langhuan.reader.ui.generated.resources.ic_cfg_backup
import com.langhuan.reader.ui.generated.resources.ic_cfg_replace
import com.langhuan.reader.ui.generated.resources.ic_cfg_source
import com.langhuan.reader.ui.generated.resources.ic_cfg_theme
import com.langhuan.reader.ui.generated.resources.ic_clear_all
import com.langhuan.reader.ui.generated.resources.ic_history
import com.langhuan.reader.ui.generated.resources.ic_interface_setting
import com.langhuan.reader.ui.generated.resources.ic_lock_outline
import com.langhuan.reader.ui.generated.resources.ic_save
import com.langhuan.reader.ui.generated.resources.ic_toc
import com.langhuan.reader.ui.generated.resources.ic_update
import com.langhuan.reader.ui.generated.resources.my_group_appearance
import com.langhuan.reader.ui.generated.resources.my_group_data
import com.langhuan.reader.ui.generated.resources.read_record
import com.langhuan.reader.ui.generated.resources.replace_purify
import com.langhuan.reader.ui.generated.resources.shrink_database
import com.langhuan.reader.ui.generated.resources.theme_mode
import com.langhuan.reader.ui.generated.resources.txt_toc_rule
import com.langhuan.reader.ui.generated.resources.version
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringResource

/**
 * 「我的」页设置面板（四组：外观 / 书源 / 数据 / 关于）。
 *
 * 只做展示与回调，弹窗与读写在 MyConfigContent 里承接。
 * 行内不写解释性小字，右侧只放当前值（字体大小、版本号）。
 */
@Composable
fun MyConfigScreen(
    fontScaleValue: String,
    versionValue: String,
    showCheckUpdate: Boolean,
    checkingUpdate: Boolean,
    onThemeMode: () -> Unit,
    onFontScale: () -> Unit,
    onBookSourceManage: () -> Unit,
    onReplaceManage: () -> Unit,
    onTxtTocRuleManage: () -> Unit,
    onBackupRestore: () -> Unit,
    onBackupPassword: () -> Unit,
    onBookmark: () -> Unit,
    onReadRecord: () -> Unit,
    onCleanCache: () -> Unit,
    onShrinkDatabase: () -> Unit,
    onAbout: () -> Unit,
    onCheckUpdate: () -> Unit,
) {
    val iconTheme = painterResource(Res.drawable.ic_cfg_theme)
    val iconFont = painterResource(Res.drawable.ic_interface_setting)
    val iconSource = painterResource(Res.drawable.ic_cfg_source)
    val iconReplace = painterResource(Res.drawable.ic_cfg_replace)
    val iconToc = painterResource(Res.drawable.ic_toc)
    val iconBackup = painterResource(Res.drawable.ic_cfg_backup)
    val iconPassword = painterResource(Res.drawable.ic_lock_outline)
    val iconBookmark = painterResource(Res.drawable.ic_bookmark)
    val iconHistory = painterResource(Res.drawable.ic_history)
    val iconClean = painterResource(Res.drawable.ic_clear_all)
    val iconShrink = painterResource(Res.drawable.ic_save)
    val iconAbout = painterResource(Res.drawable.ic_cfg_about)
    val iconUpdate = painterResource(Res.drawable.ic_update)

    val titleAppearance = stringResource(Res.string.my_group_appearance)
    val titleSource = stringResource(Res.string.book_source)
    val titleData = stringResource(Res.string.my_group_data)
    val titleAbout = stringResource(Res.string.about)

    AppTheme {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = rememberNavigationBarPaddingValues(),
        ) {
            item {
                LanghuanSettingsGroup(title = titleAppearance) {
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.theme_mode),
                        icon = iconTheme,
                        onClick = onThemeMode,
                    )
                    LanghuanSettingsDivider()
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.font_scale),
                        icon = iconFont,
                        value = fontScaleValue,
                        onClick = onFontScale,
                    )
                }
            }
            item {
                LanghuanSettingsGroup(title = titleSource) {
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.book_source_manage),
                        icon = iconSource,
                        onClick = onBookSourceManage,
                    )
                    LanghuanSettingsDivider()
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.replace_purify),
                        icon = iconReplace,
                        onClick = onReplaceManage,
                    )
                    LanghuanSettingsDivider()
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.txt_toc_rule),
                        icon = iconToc,
                        onClick = onTxtTocRuleManage,
                    )
                }
            }
            item {
                LanghuanSettingsGroup(title = titleData) {
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.backup_restore),
                        icon = iconBackup,
                        onClick = onBackupRestore,
                    )
                    LanghuanSettingsDivider()
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.backup_password),
                        icon = iconPassword,
                        onClick = onBackupPassword,
                    )
                    LanghuanSettingsDivider()
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.bookmark),
                        icon = iconBookmark,
                        onClick = onBookmark,
                    )
                    LanghuanSettingsDivider()
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.read_record),
                        icon = iconHistory,
                        onClick = onReadRecord,
                    )
                    LanghuanSettingsDivider()
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.clear_cache),
                        icon = iconClean,
                        onClick = onCleanCache,
                    )
                    LanghuanSettingsDivider()
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.shrink_database),
                        icon = iconShrink,
                        onClick = onShrinkDatabase,
                    )
                }
            }
            item {
                LanghuanSettingsGroup(title = titleAbout) {
                    LanghuanSettingsRow(
                        title = stringResource(Res.string.version),
                        icon = iconAbout,
                        value = versionValue,
                        onClick = onAbout,
                    )
                    if (showCheckUpdate) {
                        LanghuanSettingsDivider()
                        LanghuanSettingsRow(
                            title = stringResource(Res.string.check_update),
                            icon = iconUpdate,
                            showArrow = false,
                            enabled = !checkingUpdate,
                            onClick = onCheckUpdate,
                        )
                    }
                }
            }
        }
    }
}
