package com.langhuan.reader.ui.book.read.config

import androidx.compose.runtime.Composable
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.ui.compose.component.rememberResponsiveColumns
import com.langhuan.reader.ui.compose.preference.PreferenceScreen
import com.langhuan.reader.ui.compose.preference.listPreference
import com.langhuan.reader.ui.compose.preference.preference
import com.langhuan.reader.ui.compose.preference.switchPreference
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.auto_change_source
import com.langhuan.reader.ui.generated.resources.click_regional_config
import com.langhuan.reader.ui.generated.resources.double_page_horizontal
import com.langhuan.reader.ui.generated.resources.double_page_title
import com.langhuan.reader.ui.generated.resources.double_page_value
import com.langhuan.reader.ui.generated.resources.hang_first_punctuation
import com.langhuan.reader.ui.generated.resources.keep_light
import com.langhuan.reader.ui.generated.resources.page_touch_slop_title
import com.langhuan.reader.ui.generated.resources.preview_image_by_click
import com.langhuan.reader.ui.generated.resources.progress_bar_behavior
import com.langhuan.reader.ui.generated.resources.progress_bar_behavior_title
import com.langhuan.reader.ui.generated.resources.progress_bar_behavior_value
import com.langhuan.reader.ui.generated.resources.pt_hide_navigation_bar
import com.langhuan.reader.ui.generated.resources.pt_hide_status_bar
import com.langhuan.reader.ui.generated.resources.screen_direction
import com.langhuan.reader.ui.generated.resources.screen_direction_title
import com.langhuan.reader.ui.generated.resources.screen_direction_value
import com.langhuan.reader.ui.generated.resources.screen_time_out
import com.langhuan.reader.ui.generated.resources.screen_time_out_value
import com.langhuan.reader.ui.generated.resources.show_read_title_addition
import com.langhuan.reader.ui.generated.resources.text_bottom_justify
import com.langhuan.reader.ui.generated.resources.text_full_justify
import org.jetbrains.compose.resources.stringArrayResource
import org.jetbrains.compose.resources.stringResource

/**
 * 阅读界面更多设置（迁 pref_config_read.xml）。逐条对齐原条目顺序/key/默认值。
 * 底部弹窗深色底，条目均 isBottomBackground=true（showReadTitleAddition 原 XML 未设，保持默认）。
 * 各 key 的事件广播由宿主 Dialog 的 OnSharedPreferenceChangeListener 承接。
 *
 * 下沉 shared/sharedUiMain 后:
 * - `stringResource(R.string.xxx)` → `stringResource(Res.string.xxx)` (key-based, 跨平台)
 * - `stringArrayResource(R.array.xxx)` → `stringArrayResource(Res.array.xxx)` (key-based, 跨平台)
 * - PreferenceScreen/listPreference/switchPreference/preference 走 shared/sharedUiMain 的
 *   com.langhuan.reader.ui.compose.preference 包, 内部通过 PreferenceProviders 单例读写 prefs
 */
@Composable
fun MoreConfigScreen(
    onPageTouchSlop: () -> Unit,
    onClickRegionalConfig: () -> Unit,
    onPrefChange: (String) -> Unit = {},
) {
    val screenDirectionEntries = stringArrayResource(Res.array.screen_direction_title)
    val screenDirectionValues = stringArrayResource(Res.array.screen_direction_value)
    val screenTimeOutEntries = stringArrayResource(Res.array.screen_time_out)
    val screenTimeOutValues = stringArrayResource(Res.array.screen_time_out_value)
    val doublePageEntries = stringArrayResource(Res.array.double_page_title)
    val doublePageValues = stringArrayResource(Res.array.double_page_value)
    val progressBarEntries = stringArrayResource(Res.array.progress_bar_behavior_title)
    val progressBarValues = stringArrayResource(Res.array.progress_bar_behavior_value)

    // 按平台过滤: 桌面无系统栏/无屏幕方向, 这三项拨了没有任何效果
    val caps = PlatformCapabilityProviders.get()
    val hasSystemBars = caps.hasSystemBars()
    val hasScreenOrientation = caps.hasScreenOrientation()

    val titleScreenDirection = stringResource(Res.string.screen_direction)
    val titleKeepLight = stringResource(Res.string.keep_light)
    val titleHideStatusBar = stringResource(Res.string.pt_hide_status_bar)
    val titleHideNavigationBar = stringResource(Res.string.pt_hide_navigation_bar)
    val titleDoublePage = stringResource(Res.string.double_page_horizontal)
    val titleProgressBarBehavior = stringResource(Res.string.progress_bar_behavior)
    val titleTextFullJustify = stringResource(Res.string.text_full_justify)
    val titleTextBottomJustify = stringResource(Res.string.text_bottom_justify)
    val titleHangFirstPunctuation = stringResource(Res.string.hang_first_punctuation)
    val titlePageTouchSlop = stringResource(Res.string.page_touch_slop_title)
    val titleAutoChangeSource = stringResource(Res.string.auto_change_source)
    val titlePreviewImageByClick = stringResource(Res.string.preview_image_by_click)
    val titleClickRegionalConfig = stringResource(Res.string.click_regional_config)
    val titleShowReadTitleAddition = stringResource(Res.string.show_read_title_addition)

    AppTheme {
        // 宽屏自动分列: 单列 640dp→2 列、1000dp→3 列, 之后每 +400dp 加一列 (窄屏恒单列)
        PreferenceScreen(columns = rememberResponsiveColumns(1)) {
            if (hasScreenOrientation) {
                listPreference(
                    prefKey = PreferKey.screenOrientation,
                    title = titleScreenDirection,
                    entries = screenDirectionEntries,
                    values = screenDirectionValues,
                    defaultValue = "0",
                    isBottomBackground = true,
                    onValueChange = { onPrefChange(PreferKey.screenOrientation) },
                )
            }
            listPreference(
                prefKey = PreferKey.keepLight,
                title = titleKeepLight,
                entries = screenTimeOutEntries,
                values = screenTimeOutValues,
                defaultValue = "0",
                isBottomBackground = true,
                onValueChange = { onPrefChange(PreferKey.keepLight) },
            )
            if (hasSystemBars) {
                switchPreference(
                    prefKey = PreferKey.hideStatusBar,
                    title = titleHideStatusBar,
                    defaultValue = false,
                    isBottomBackground = true,
                    onCheckedChange = { onPrefChange(PreferKey.hideStatusBar) },
                )
                switchPreference(
                    prefKey = PreferKey.hideNavigationBar,
                    title = titleHideNavigationBar,
                    defaultValue = false,
                    isBottomBackground = true,
                    onCheckedChange = { onPrefChange(PreferKey.hideNavigationBar) },
                )
            }
            listPreference(
                prefKey = PreferKey.doublePageHorizontal,
                title = titleDoublePage,
                entries = doublePageEntries,
                values = doublePageValues,
                defaultValue = "0",
                isBottomBackground = true,
                onValueChange = { onPrefChange(PreferKey.doublePageHorizontal) },
            )
            listPreference(
                prefKey = PreferKey.progressBarBehavior,
                title = titleProgressBarBehavior,
                entries = progressBarEntries,
                values = progressBarValues,
                defaultValue = "page",
                isBottomBackground = true,
                onValueChange = { onPrefChange(PreferKey.progressBarBehavior) },
            )
            switchPreference(
                prefKey = PreferKey.textFullJustify,
                title = titleTextFullJustify,
                defaultValue = true,
                isBottomBackground = true,
                onCheckedChange = { onPrefChange(PreferKey.textFullJustify) },
            )
            switchPreference(
                prefKey = PreferKey.textBottomJustify,
                title = titleTextBottomJustify,
                defaultValue = true,
                isBottomBackground = true,
                onCheckedChange = { onPrefChange(PreferKey.textBottomJustify) },
            )
            switchPreference(
                prefKey = PreferKey.hangFirstPunctuation,
                title = titleHangFirstPunctuation,
                defaultValue = false,
                isBottomBackground = true,
                onCheckedChange = { onPrefChange(PreferKey.hangFirstPunctuation) },
            )
            // 音量键翻页恒生效 (2026-08 用户拍板), 无开关条目; 滚轮翻页已彻底禁用 (2026-08 用户拍板), 无开关条目
            preference(
                title = titlePageTouchSlop,
                isBottomBackground = true,
                onClick = onPageTouchSlop,
            )
            switchPreference(
                prefKey = PreferKey.autoChangeSource,
                title = titleAutoChangeSource,
                defaultValue = true,
                isBottomBackground = true,
            )
            switchPreference(
                prefKey = PreferKey.previewImageByClick,
                title = titlePreviewImageByClick,
                defaultValue = false,
                isBottomBackground = true,
            )
            preference(
                title = titleClickRegionalConfig,
                isBottomBackground = true,
                onClick = onClickRegionalConfig,
            )
            switchPreference(
                prefKey = PreferKey.showReadTitleAddition,
                title = titleShowReadTitleAddition,
                defaultValue = true,
                onCheckedChange = { onPrefChange(PreferKey.showReadTitleAddition) },
            )
        }
    }
}
