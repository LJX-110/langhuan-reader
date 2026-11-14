package com.langhuan.reader.ui.compose.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

/**
 * 对齐 ThemeStore 全部对外颜色的不可变主题色集合。
 * primaryText/isDark 复刻「由背景色亮度反推」语义(ColorUtils.isColorLight)，非系统夜间模式。
 * fillet 为圆角底色(= bottomBackground)，供 filletBackground 语义使用。
 *
 * KMP 共享: 从 app/ui/compose/theme 下沉到 shared/commonMain, app + desktop 直接复用。
 */
@Immutable
data class AppColors(
    val accent: Color,
    val background: Color,
    val bottomBackground: Color,
    val primaryText: Color,
    val secondaryText: Color,
    val menuText: Color,
    val summaryText: Color,
    // 对齐 ate_control_normal_light/dark: 用于 TextField unfocused 下划线/label/placeholder
    val controlNormal: Color,
    // 对齐 ate_text_disabled_light/dark: 用于 TextField disabled 状态文字/下划线/label/placeholder
    val textDisabled: Color,
    val statusBar: Color,
    val navigationBar: Color,
    val fillet: Color,
    val isDark: Boolean,
    /** 大面积填充用的可见主色（按钮、选中块），接近页面底色时已换辅助色 */
    val accentFill: Color = accent,
    /** 辅助色：书脊、底栏下划线、筛选线等小面积点缀 */
    val companion: Color = accent,
    /** 书页暖纸底色（封面面板） */
    val paper: Color = background,
    /** 纸的暗面（书架顶面渐变收口） */
    val paperDeep: Color = background,
    /** 细边线（分隔线、卡片描边） */
    val line: Color = primaryText,
    /** 3D 书架封面平面的实色（替代半透明，后排文字不会透出来） */
    val shelfCover: Color = paperDeep,
    /** 3D 书架书脊平面的实色 */
    val shelfSpine: Color = paperDeep,
    /** 3D 书架顶面渐变的起始色（收口色用 [shelfCover]） */
    val shelfTop: Color = paperDeep,
    /** 3D 书架落地投影的墨色 */
    val shelfFloor: Color = summaryText,
    /** 3D 书架顶面描边色 */
    val shelfEdge: Color = line,
)
