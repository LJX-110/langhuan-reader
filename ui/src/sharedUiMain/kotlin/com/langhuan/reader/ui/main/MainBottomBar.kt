package com.langhuan.reader.ui.main

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.constant.BottomNavTag
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.LocalEInk

/**
 * 琅嬛阁四页签底栏：居中的悬浮实心胶囊。
 *
 * 结构 = 20dp 线性图标 + 3dp 间隙 + 11sp 标签 + 3dp 间隙 + 12x1.5dp 辅助色下划线。
 * 胶囊 54dp 高、整宽 64dp x 页签数、半圆端、0.5dp 细描边；实色，不使用模糊或玻璃效果。
 *
 * 页签固定为 书架 / 发现 / 本地 / 我（tag 顺序由 MainRoute 传入）。
 * 图标为 Canvas 自绘，不依赖上游 drawable 资源。
 */
@Composable
fun MainBottomBar(
    tags: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    onReselect: (String) -> Unit,
    iconSize: Int,
    barHeight: Int,
    labelMode: Int,
) {
    val colors = AppTheme.colors
    val eInk = LocalEInk.current
    // 尊重设置里的底栏高度 / 图标尺寸（app 端 AppConfig 三项），未设置时用设计默认值
    val dockHeight = (if (barHeight > 0) barHeight.dp else 54.dp)
    val iconDp = (if (iconSize > 0) iconSize.dp else 20.dp)
    val slotWidth = 64.dp
    val shape = RoundedCornerShape(dockHeight / 2)

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.background)
            .navigationBarsPadding()
            .padding(top = 4.dp, bottom = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(
            modifier = Modifier
                .width(slotWidth * tags.size)
                .height(dockHeight)
                .shadow(if (eInk) 0.dp else 6.dp, shape, clip = false)
                .clip(shape)
                .background(colors.fillet)
                .border(0.5.dp, colors.line, shape),
        ) {
            tags.forEachIndexed { index, tag ->
                val selected = index == selectedIndex
                // 0=无标签 / 1=恒显 / 2=仅选中 / 3=自动（按仅选中处理）
                val showLabel = when (labelMode) {
                    0 -> false
                    1 -> true
                    else -> selected
                }
                DockItem(
                    tag = tag,
                    selected = selected,
                    iconDp = iconDp,
                    showLabel = showLabel,
                    modifier = Modifier.weight(1f).fillMaxHeight(),
                    onClick = {
                        if (selected) onReselect(tag) else onSelect(index)
                    },
                )
            }
        }
    }
}

@Composable
private fun DockItem(
    tag: String,
    selected: Boolean,
    iconDp: androidx.compose.ui.unit.Dp,
    showLabel: Boolean,
    modifier: Modifier,
    onClick: () -> Unit,
) {
    val colors = AppTheme.colors
    // 选中态用辅助色，与强调色的按钮/标题形成层次
    val tint = if (selected) colors.companion else colors.summaryText
    val interaction = remember { MutableInteractionSource() }
    Column(
        modifier = modifier.clickable(
            interactionSource = interaction,
            indication = null,
            onClick = onClick,
        ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Canvas(Modifier.size(iconDp)) { drawDockIcon(tag, tint) }
        if (showLabel) {
            Spacer(Modifier.height(3.dp))
            Text(
                text = tag.dockLabel(),
                color = tint,
                fontSize = 11.sp,
                maxLines = 1,
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
            )
        }
        Spacer(Modifier.height(3.dp))
        Box(
            Modifier
                .width(if (selected) 12.dp else 0.dp)
                .height(1.5.dp)
                .background(colors.companion)
        )
    }
}

private fun String.dockLabel(): String = when (this) {
    BottomNavTag.BOOKSHELF -> "书架"
    BottomNavTag.DISCOVERY -> "发现"
    BottomNavTag.HOME -> "本地"
    else -> "我"
}

/** 四个页签的线性图标，路径与琅嬛阁 DockBar 的 CustomPainter 一致。 */
private fun DrawScope.drawDockIcon(tag: String, color: Color) {
    val w = size.width
    val h = size.height
    val stroke = Stroke(
        width = 1.35.dp.toPx(),
        cap = StrokeCap.Round,
        join = StrokeJoin.Round,
    )
    when (tag) {
        BottomNavTag.BOOKSHELF -> {
            drawRect(
                color = color,
                topLeft = Offset(w * .16f, h * .18f),
                size = Size(w * .68f, h * .68f),
                style = stroke,
            )
            drawLine(color, Offset(w * .35f, h * .18f), Offset(w * .35f, h * .86f), stroke.width, StrokeCap.Round)
            drawLine(color, Offset(w * .55f, h * .26f), Offset(w * .55f, h * .86f), stroke.width, StrokeCap.Round)
            drawLine(color, Offset(w * .72f, h * .18f), Offset(w * .72f, h * .86f), stroke.width, StrokeCap.Round)
            drawLine(color, Offset(w * .22f, h * .38f), Offset(w * .30f, h * .38f), stroke.width, StrokeCap.Round)
            drawLine(color, Offset(w * .60f, h * .52f), Offset(w * .68f, h * .52f), stroke.width, StrokeCap.Round)
        }

        BottomNavTag.DISCOVERY -> {
            drawCircle(color, radius = w * .35f, center = Offset(w * .5f, h * .5f), style = stroke)
            val needle = Path().apply {
                moveTo(w * .62f, h * .31f)
                lineTo(w * .54f, h * .54f)
                lineTo(w * .31f, h * .62f)
                lineTo(w * .39f, h * .39f)
                close()
            }
            drawPath(needle, color, style = stroke)
            drawCircle(color, radius = w * .035f, center = Offset(w * .5f, h * .5f), style = stroke)
        }

        BottomNavTag.HOME -> {
            val folder = Path().apply {
                moveTo(w * .16f, h * .28f)
                lineTo(w * .43f, h * .28f)
                lineTo(w * .51f, h * .38f)
                lineTo(w * .84f, h * .38f)
                lineTo(w * .84f, h * .80f)
                lineTo(w * .16f, h * .80f)
                close()
            }
            drawPath(folder, color, style = stroke)
            drawLine(color, Offset(w * .16f, h * .45f), Offset(w * .84f, h * .45f), stroke.width, StrokeCap.Round)
        }

        else -> {
            drawCircle(color, radius = w * .105f, center = Offset(w * .5f, h * .34f), style = stroke)
            val shoulders = Path().apply {
                moveTo(w * .25f, h * .79f)
                quadraticBezierTo(w * .29f, h * .54f, w * .5f, h * .54f)
                quadraticBezierTo(w * .71f, h * .54f, w * .75f, h * .79f)
            }
            drawPath(shoulders, color, style = stroke)
            drawLine(color, Offset(w * .38f, h * .79f), Offset(w * .62f, h * .79f), stroke.width, StrokeCap.Round)
        }
    }
}
