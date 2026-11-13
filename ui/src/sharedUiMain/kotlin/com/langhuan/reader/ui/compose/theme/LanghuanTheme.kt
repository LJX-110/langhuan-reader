package com.langhuan.reader.ui.compose.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.langhuan.reader.help.config.PreferenceProviders
import kotlin.math.abs

/**
 * 琅嬛阁双色主题：主色驱动按钮与选中态，辅助色只做书脊、下划线等小面积点缀。
 *
 * 页面底色始终是白（浅色）或近黑（深色），荧光色不会铺满整页——
 * 这是「主题只改强调色与辅助色」的硬约束。
 */
data class LanghuanThemePreset(
    val name: String,
    val accent: Color,
    val secondary: Color,
)

/**
 * 只换 12 套主题强调色时的轻量刷新事件。
 *
 * 与 `EventBus.RECREATE` 分开：后者会让 Android 宿主 `Activity.recreate()`，
 * 在阅读页换主题会把正在读的一页连同翻页委托一起重建；这里只让 [AppTheme]
 * 重读皮肤下标并重组颜色，正文与阅读位置都不动。
 */
const val LANGHUAN_THEME_ACCENT_CHANGED = "langhuanThemeAccentChanged"

/**
 * 12 套可切换皮肤。与 Flutter 版 `theme_presets.dart` 一一对应，
 * 默认第 1 套（鸢尾蓝 · 流光白）。
 */
object LanghuanThemes {
    const val DEFAULT_INDEX = 1

    /** 持久层键名（int，越界自动回落默认值） */
    const val PREF_KEY = "langhuanThemeIndex"

    val all: List<LanghuanThemePreset> = listOf(
        LanghuanThemePreset("橘橙 · 青金石", Color(0xFFFD742D), Color(0xFF01008A)),
        LanghuanThemePreset("鸢尾蓝 · 流光白", Color(0xFF0F64B5), Color(0xFFFFFBEA)),
        LanghuanThemePreset("荧光绿 · 深空灰", Color(0xFF08FC2E), Color(0xFF101820)),
        LanghuanThemePreset("火山橙 · 藏蓝", Color(0xFFFF6047), Color(0xFF000035)),
        LanghuanThemePreset("电光蓝 · 玫红", Color(0xFF12F2FD), Color(0xFFE4058E)),
        LanghuanThemePreset("金菊 · 晶石紫", Color(0xFFFADE1F), Color(0xFF690DAD)),
        LanghuanThemePreset("靓丽黄 · 宝蓝", Color(0xFFFFFF00), Color(0xFF002FA7)),
        LanghuanThemePreset("瓦松绿 · 玉子", Color(0xFF4E8966), Color(0xFFFFFEEE)),
        LanghuanThemePreset("米白 · 凝液紫", Color(0xFFFFFBEA), Color(0xFF47176D)),
        LanghuanThemePreset("电光蓝 · 晶石紫", Color(0xFF00F0FD), Color(0xFF690DAD)),
        LanghuanThemePreset("旭日黄 · 深灰绿", Color(0xFFFDEB55), Color(0xFF185A56)),
        LanghuanThemePreset("勃艮第红 · 米白", Color(0xFF470125), Color(0xFFFFFBEA)),
    )

    /** 当前选中下标；持久层异常或越界时回落默认值。 */
    fun currentIndex(): Int = runCatching {
        PreferenceProviders.get().getInt(PREF_KEY, DEFAULT_INDEX)
    }.getOrDefault(DEFAULT_INDEX).coerceIn(0, all.lastIndex)

    fun select(index: Int) {
        PreferenceProviders.get().putInt(PREF_KEY, index.coerceIn(0, all.lastIndex))
    }
}

// ---------------------------------------------------------------- 页面底色

private val LightPage = Color(0xFFFFFFFF)
private val DarkPage = Color(0xFF0E0E0E)
private val DarkSurface = Color(0xFF181818)

/** 书页暖纸（封面面板底色），与页面纯白区分。 */
private val PaperWhite = Color(0xFFFAF8F2)
private val PaperCream = Color(0xFFF3F1EA)

private val LightLine = Color(0xFFE8E8E8)
private val DarkLine = Color(0xFF2A2A2A)

/**
 * 一套解析完成的琅嬛阁配色。
 *
 * - [accentFill] 大面积填充用的可见主色（接近页面底色时自动换辅助色）
 * - [accent] 文字/图标用色，已按 4.5:1 对比度校正
 * - [companion] 辅助色，用于书脊、底栏下划线等小面积标记
 */
data class LanghuanPalette(
    val dark: Boolean,
    val accentFill: Color,
    val accent: Color,
    val companion: Color,
    val background: Color,
    val surface: Color,
    val paper: Color,
    val paperDeep: Color,
    val line: Color,
    val ink: Color,
    val muted: Color,
)

/** 按当前皮肤与日夜解析整套配色。 */
fun langhuanPalette(
    dark: Boolean,
    presetIndex: Int = LanghuanThemes.currentIndex(),
): LanghuanPalette {
    val preset = LanghuanThemes.all[presetIndex.coerceIn(0, LanghuanThemes.all.lastIndex)]
    val fill = langhuanThemeAccent(preset.accent, preset.secondary, dark)
    return LanghuanPalette(
        dark = dark,
        accentFill = fill,
        accent = langhuanReadable(fill, dark),
        companion = langhuanCompanion(preset.accent, preset.secondary, dark),
        background = if (dark) DarkPage else LightPage,
        surface = if (dark) DarkSurface else Color.White,
        paper = if (dark) DarkSurface else PaperWhite,
        paperDeep = if (dark) Color(0xFF2A2A2A) else PaperCream,
        line = if (dark) DarkLine else LightLine,
        ink = if (dark) Color(0xFFF5F5F5) else Color(0xFF141414),
        muted = if (dark) Color(0xFFB3B3B3) else Color(0xFF6E6E6E),
    )
}

// ---------------------------------------------------------------- 色彩计算

/** WCAG 对比度。 */
fun langhuanContrast(a: Color, b: Color): Float {
    val la = a.luminance()
    val lb = b.luminance()
    val hi = if (la > lb) la else lb
    val lo = if (la > lb) lb else la
    return (hi + 0.05f) / (lo + 0.05f)
}

/**
 * 把颜色沿亮度轴向页面底色推，直到达到 [minRatio]。
 * 色相与饱和度保持不变，金色主题不会变成灰色。
 */
fun langhuanReadable(color: Color, dark: Boolean, minRatio: Float = 4.5f): Color {
    val target = if (dark) Color.Black else Color.White
    val hsl = color.toHsl()
    var lightness = hsl[2]
    var out = color
    val step = if (dark) 0.05f else -0.05f
    repeat(20) {
        if (langhuanContrast(out, target) >= minRatio) return out
        val next = (lightness + step).coerceIn(0f, 1f)
        if (next == lightness) return out
        lightness = next
        out = hslToColor(hsl[0], hsl[1], lightness)
    }
    return out
}

/**
 * 页面主色：与页面底色的对比度不足 1.6 时改用辅助色，
 * 两者都贴近页面时才做可读性校正，避免主题色「消失」。
 *
 * 只比对比度、不加亮度差条件：纯黄在白底上亮度差很大但对比度只有 1.07，
 * 若放过它，分组竖线、书脊这类小块标记会看不见。
 */
fun langhuanThemeAccent(primary: Color, secondary: Color, dark: Boolean): Color {
    val page = if (dark) DarkPage else LightPage
    val nearPage = langhuanContrast(primary, page) < 1.6f
    if (!nearPage) return primary

    val secondaryNearPage = langhuanContrast(secondary, page) < 1.6f
    if (!secondaryNearPage) return secondary

    return langhuanReadable(primary, dark)
}

/** 辅助色：可见就用原色；接近页面底色时退回可读的主色。 */
fun langhuanCompanion(primary: Color, secondary: Color, dark: Boolean): Color {
    val page = if (dark) DarkPage else LightPage
    if (langhuanContrast(secondary, page) >= 1.6f) return secondary
    return langhuanReadable(langhuanThemeAccent(primary, secondary, dark), dark)
}

/** 填充色上该用黑字还是白字——直接比对比度，避免临界色取错。 */
fun langhuanOnColor(color: Color): Color {
    val white = Color.White
    val black = Color.Black
    return if (langhuanContrast(color, white) >= langhuanContrast(color, black)) white else black
}

private fun Color.toHsl(): FloatArray {
    val r = red
    val g = green
    val b = blue
    val max = maxOf(r, g, b)
    val min = minOf(r, g, b)
    val lightness = (max + min) / 2f
    if (max == min) return floatArrayOf(0f, 0f, lightness)

    val delta = max - min
    val saturation = if (lightness > 0.5f) {
        delta / (2f - max - min)
    } else {
        delta / (max + min)
    }
    val hue = when (max) {
        r -> ((g - b) / delta + if (g < b) 6f else 0f)
        g -> ((b - r) / delta + 2f)
        else -> ((r - g) / delta + 4f)
    } * 60f
    return floatArrayOf(hue, saturation, lightness)
}

private fun hslToColor(hue: Float, saturation: Float, lightness: Float): Color {
    if (saturation <= 0f) return Color(lightness, lightness, lightness)
    val q = if (lightness < 0.5f) {
        lightness * (1f + saturation)
    } else {
        lightness + saturation - lightness * saturation
    }
    val p = 2f * lightness - q

    fun channel(t: Float): Float {
        var value = t
        if (value < 0f) value += 1f
        if (value > 1f) value -= 1f
        return when {
            value < 1f / 6f -> p + (q - p) * 6f * value
            value < 1f / 2f -> q
            value < 2f / 3f -> p + (q - p) * (2f / 3f - value) * 6f
            else -> p
        }
    }

    val h = hue / 360f
    return Color(channel(h + 1f / 3f), channel(h), channel(h - 1f / 3f))
}

/** 琅嬛阁字体：页面标题与章节标题用衬线，正文沿用界面无衬线。 */
object LanghuanType {
    val serif: FontFamily = FontFamily.Serif

    /** 每页唯一的一行标题（22sp 衬线） */
    val pageTitle: TextStyle = TextStyle(
        fontFamily = serif,
        fontSize = 22.sp,
        lineHeight = 27.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 1.sp,
    )

    /** 区块标题（分组名、书架名） */
    val sectionTitle: TextStyle = TextStyle(
        fontFamily = serif,
        fontSize = 17.sp,
        lineHeight = 22.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = 0.5.sp,
    )

    /** 书名（书架当前书、目录章节） */
    val bookTitle: TextStyle = TextStyle(
        fontFamily = serif,
        fontSize = 15.sp,
        lineHeight = 20.sp,
        fontWeight = FontWeight.SemiBold,
    )
}
