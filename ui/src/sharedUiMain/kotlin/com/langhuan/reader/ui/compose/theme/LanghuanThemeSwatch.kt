package com.langhuan.reader.ui.compose.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * 一套主题的双色色块：左半主色、右半辅助色，选中时外圈再套一道主题色描边。
 *
 * 之前皮肤弹窗用两个并排的实心圆，浅色辅助色（流光白、米白）落在白底弹窗上
 * 只剩一圈 0.5dp 描边，看起来像“只有一种颜色”。改成同一个小圆里的左右两半后，
 * 两色永远同时可见，也不受弹窗底色影响。
 *
 * @param size 色块直径；选中态外圈会在此基础上再加 6dp
 */
@Composable
fun LanghuanThemeSwatch(
    preset: LanghuanThemePreset,
    selected: Boolean,
    modifier: Modifier = Modifier,
    size: Dp = 30.dp,
    /** 选中描边色；默认用页面强调色，落在阅读底栏等自绘背景上时由调用方传入已校正的颜色 */
    selectionColor: Color? = null,
) {
    val colors = AppTheme.colors
    val ringColor = selectionColor ?: colors.accent
    Box(
        modifier = modifier.size(size + if (selected) 6.dp else 0.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .size(size)
                .clip(CircleShape)
                .border(
                    width = if (selected) 2.dp else 1.dp,
                    color = if (selected) ringColor else colors.line,
                    shape = CircleShape,
                )
                .padding(2.dp)
                .clip(CircleShape),
        ) {
            Row(Modifier.fillMaxSize()) {
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .background(preset.accent),
                )
                // 两半之间留一道发丝线：浅色辅助色（流光白、米白）与白色弹窗同调时，
                // 靠这道线仍能看出左右分界，不会缩成一块单色圆
                Box(
                    Modifier
                        .fillMaxHeight()
                        .width(0.5.dp)
                        .background(colors.line),
                )
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .background(preset.secondary),
                )
            }
        }
    }
}
