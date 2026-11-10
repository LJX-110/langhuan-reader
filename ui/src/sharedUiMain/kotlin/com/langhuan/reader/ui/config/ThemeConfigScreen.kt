package com.langhuan.reader.ui.config

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.ui.compose.platform.rememberLauncherIconPainters
import com.langhuan.reader.ui.compose.preference.PreferenceScreen
import com.langhuan.reader.ui.compose.preference.iconListPreference
import com.langhuan.reader.ui.compose.preference.preference
import com.langhuan.reader.ui.compose.preference.switchPreference
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.book_info_horizontal_layout
import com.langhuan.reader.ui.generated.resources.book_info_horizontal_layout_summary
import com.langhuan.reader.ui.generated.resources.bookshelf_layout
import com.langhuan.reader.ui.generated.resources.bottom_nav_config
import com.langhuan.reader.ui.generated.resources.bottom_nav_config_summary
import com.langhuan.reader.ui.generated.resources.change_icon
import com.langhuan.reader.ui.generated.resources.change_icon_summary
import com.langhuan.reader.ui.generated.resources.cover_config
import com.langhuan.reader.ui.generated.resources.cover_config_summary
import com.langhuan.reader.ui.generated.resources.customize_day_theme
import com.langhuan.reader.ui.generated.resources.customize_night_theme
import com.langhuan.reader.ui.generated.resources.font_scale
import com.langhuan.reader.ui.generated.resources.icon_names
import com.langhuan.reader.ui.generated.resources.icons
import com.langhuan.reader.ui.generated.resources.langhuan_skin
import com.langhuan.reader.ui.generated.resources.langhuan_skin_summary
import com.langhuan.reader.ui.generated.resources.monet_color_extract
import com.langhuan.reader.ui.generated.resources.monet_color_extract_failed
import com.langhuan.reader.ui.generated.resources.search_layout
import com.langhuan.reader.ui.generated.resources.source_edit_text_max_line
import com.langhuan.reader.ui.generated.resources.theme_list
import com.langhuan.reader.ui.generated.resources.theme_list_summary
import com.langhuan.reader.ui.generated.resources.welcome_style
import com.langhuan.reader.ui.generated.resources.welcome_style_summary
import org.jetbrains.compose.resources.stringArrayResource
import org.jetbrains.compose.resources.stringResource

/**
 * 主题设置页（迁 pref_config_theme.xml）。逐条对齐原条目顺序/key/默认值。
 * 唯一新增为莫奈取色组 (无原版对应): 一键取色 + 自动跟随壁纸开关, 平台能力注入,
 * 仅 Android 12+ 非 eInk 显示 ([monetColorExtractSupported] 门)。
 * 换图标入口已移除: 只保留一套图标, [iconChangeSupported] 恒为 false, 该项不再展示。
 * 动态 summary（字体缩放）与点击型交互（布局/搜索/底栏/主题弹窗/NumberPicker/跳转）由宿主传入。
 *
 * 下沉 shared/sharedUiMain:
 * - stringResource(R.string.xxx) → stringResource(Res.string.xxx) (key-based, 跨平台)
 * - stringArrayResource(R.array.icon_names/icons) → rememberStringArray("icon_names"/"icons")
 * - LocalContext + getCompatDrawable + BitmapPainter 图标加载链 → rememberLauncherIconPainters
 *   (AdaptiveIconDrawable 不支持 painterResource, Android actual 内部转 Bitmap)
 * - PreferenceScreen/switchPreference/iconListPreference/preference 走 shared/sharedUiMain 的
 *   com.langhuan.reader.ui.compose.preference 包, 与 app 端原包名/类名一致, app/desktop 端共用。
 */
@Composable
fun ThemeConfigScreen(
    fontScaleSummary: String,
    onBookshelfLayout: () -> Unit,
    onSearchLayout: () -> Unit,
    onCoverConfig: () -> Unit,
    onWelcomeStyle: () -> Unit,
    onBottomNavConfig: () -> Unit,
    onThemeList: () -> Unit,
    onCustomizeDayTheme: () -> Unit,
    onCustomizeNightTheme: () -> Unit,
    /** 莫奈取色点击回调 (Android 12+ 一键取壁纸主色派生日/夜主题色, 取色即默认跟随壁纸变化) */
    onMonetColorExtract: () -> Unit,
    onFontScale: () -> Unit,
    /** 平台是否支持莫奈取色 (false 时隐藏“莫奈取色”项; 同 [iconChangeSupported] 平台过滤) */
    monetColorExtractSupported: Boolean = false,
    /** 源编辑框最大行数 summary (动态: 格式化后的当前值) */
    sourceEditMaxLineSummary: String,
    /** 源编辑框最大行数点击回调 (弹 NumberPicker) */
    onSourceEditMaxLine: () -> Unit,
    /** 平台是否支持更换桌面图标 (false 时隐藏"换图标"项; 默认 true 与 Android 行为一致) */
    iconChangeSupported: Boolean = true,
    /** 选中图标回调 (Android/iOS 经平台能力切换桌面图标; null 时仅写 pref 不触发切换) */
    onIconChange: ((String) -> Unit)? = null,
) {
    val iconNames = stringArrayResource(Res.array.icon_names)
    val icons = stringArrayResource(Res.array.icons)
    // 换图标图集：按 mipmap 名解析预览 painter（复刻 IconListPreference：getIdentifier + getCompatDrawable）。
    // 图标是自适应图标(AdaptiveIconDrawable)，painterResource 不支持，Android actual 内部转 bitmap 后包 BitmapPainter。
    // 仅在"换图标"项展示时求值 (桌面/鸿蒙 launcherIconChangeSupported=false 隐藏该项,
    // 同时跳过 rememberLauncherIconPainters 调用, 对应端 actual 返回空列表)。
    val iconPainters = if (iconChangeSupported) rememberLauncherIconPainters(icons) else emptyList()

    val titleBookshelfLayout = stringResource(Res.string.bookshelf_layout)
    val titleSearchLayout = stringResource(Res.string.search_layout)
    val titleBookInfoHLayout = stringResource(Res.string.book_info_horizontal_layout)
    val summaryBookInfoHLayout = stringResource(Res.string.book_info_horizontal_layout_summary)
    val titleCoverConfig = stringResource(Res.string.cover_config)
    val summaryCoverConfig = stringResource(Res.string.cover_config_summary)
    val titleChangeIcon = stringResource(Res.string.change_icon)
    val summaryChangeIcon = stringResource(Res.string.change_icon_summary)
    val titleWelcomeStyle = stringResource(Res.string.welcome_style)
    val summaryWelcomeStyle = stringResource(Res.string.welcome_style_summary)
    val titleBottomNav = stringResource(Res.string.bottom_nav_config)
    val summaryBottomNav = stringResource(Res.string.bottom_nav_config_summary)
    val titleThemeList = stringResource(Res.string.theme_list)
    val summaryThemeList = stringResource(Res.string.theme_list_summary)
    val titleCustomizeDay = stringResource(Res.string.customize_day_theme)
    val titleCustomizeNight = stringResource(Res.string.customize_night_theme)
    val titleMonetColorExtract = stringResource(Res.string.monet_color_extract)
    val titleFontScale = stringResource(Res.string.font_scale)
    val titleSourceEditMaxLine = stringResource(Res.string.source_edit_text_max_line)
    val titleSkin = stringResource(Res.string.langhuan_skin)
    val summarySkin = stringResource(Res.string.langhuan_skin_summary)
    // 皮肤选择：12 套双色主题，点开即预览、确定才落库
    var showSkinDialog by remember { mutableStateOf(false) }

    AppTheme {
        PreferenceScreen {
            preference(
                title = titleSkin,
                summary = summarySkin,
                onClick = { showSkinDialog = true },
            )
            preference(
                title = titleBookshelfLayout,
                onClick = onBookshelfLayout,
            )
            preference(
                title = titleSearchLayout,
                onClick = onSearchLayout,
            )
            switchPreference(
                prefKey = PreferKey.bookInfoHorizontalLayout,
                title = titleBookInfoHLayout,
                summary = summaryBookInfoHLayout,
                defaultValue = false,
            )
            preference(
                title = titleCoverConfig,
                summary = summaryCoverConfig,
                onClick = onCoverConfig,
            )
            if (iconChangeSupported) {
                iconListPreference(
                    prefKey = PreferKey.launcherIcon,
                    title = titleChangeIcon,
                    summary = summaryChangeIcon,
                    entries = iconNames,
                    values = icons,
                    icons = iconPainters,
                    defaultValue = "ic_launcher",
                    onValueChange = onIconChange,
                )
            }
            preference(
                title = titleWelcomeStyle,
                summary = summaryWelcomeStyle,
                onClick = onWelcomeStyle,
            )
            preference(
                title = titleBottomNav,
                summary = summaryBottomNav,
                onClick = onBottomNavConfig,
            )
            preference(
                title = titleFontScale,
                summary = fontScaleSummary,
                onClick = onFontScale,
            )
            preference(
                title = titleSourceEditMaxLine,
                summary = sourceEditMaxLineSummary,
                onClick = onSourceEditMaxLine,
            )
        }
        // 皮肤对话框
        if (showSkinDialog) {
            LanghuanSkinDialog(onDismiss = { showSkinDialog = false })
        }
    }
}
