package com.langhuan.reader.ui.config

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.ui.compose.component.AppDialogScaffold
import com.langhuan.reader.ui.compose.component.AppTextButton
import com.langhuan.reader.ui.compose.component.LanghuanDivider
import com.langhuan.reader.ui.compose.platform.LocalEventBusProvider
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.compose.theme.LanghuanThemePreset
import com.langhuan.reader.ui.compose.theme.LanghuanThemes
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.langhuan_skin
import com.langhuan.reader.ui.generated.resources.langhuan_skin_summary
import com.langhuan.reader.ui.generated.resources.ok
import org.jetbrains.compose.resources.stringResource

/**
 * 皮肤选择：12 套双色主题，点「确定」后写库并重建主题生效（点选行只改选中态）。
 *
 * 只写入皮肤下标并触发主题重建，不碰读者的正文纸张设置——
 * 换肤永远不应该改变正在读的那一页的颜色。
 */
@Composable
fun LanghuanSkinDialog(onDismiss: () -> Unit) {
    val colors = AppTheme.colors
    val eventBus = LocalEventBusProvider.current
    var selected by remember { mutableIntStateOf(LanghuanThemes.currentIndex()) }

    AppDialogScaffold(
        onDismissRequest = onDismiss,
        title = stringResource(Res.string.langhuan_skin),
        subtitle = stringResource(Res.string.langhuan_skin_summary),
        bottomBar = {
            Spacer(Modifier.weight(1f))
            AppTextButton(
                text = stringResource(Res.string.cancel),
                color = colors.secondaryText,
                onClick = onDismiss,
            )
            Spacer(Modifier.width(DesignTokens.spacingDefault))
            AppTextButton(text = stringResource(Res.string.ok)) {
                LanghuanThemes.select(selected)
                // 主题色在 AppTheme 读取层解析，写库后广播重建才能即时换肤
                eventBus.emitRecreate()
                onDismiss()
            }
        },
    ) {
        LazyColumn(Modifier.fillMaxWidth().weight(1f, fill = false)) {
            itemsIndexed(LanghuanThemes.all) { index, preset ->
                SkinRow(
                    preset = preset,
                    selected = selected == index,
                    onClick = { selected = index },
                )
                LanghuanDivider()
            }
        }
    }
}

@Composable
private fun SkinRow(
    preset: LanghuanThemePreset,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val colors = AppTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = DesignTokens.viewHeightMax)
            .clickable(onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // 主色实心圆 + 辅助色实心圆：一眼看出这套皮肤的两色关系
        Box(
            Modifier
                .size(26.dp)
                .background(preset.accent, CircleShape)
                .border(0.5.dp, colors.line, CircleShape)
        )
        Spacer(Modifier.width(6.dp))
        Box(
            Modifier
                .size(26.dp)
                .background(preset.secondary, CircleShape)
                .border(0.5.dp, colors.line, CircleShape)
        )
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(
                text = preset.name,
                color = colors.primaryText,
                fontSize = 15.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = if (selected) "当前使用" else "点按预览",
                color = if (selected) colors.accent else colors.summaryText,
                fontSize = 11.sp,
            )
        }
        // 选中标记用辅助色小方块，不用勾选图标——和书脊上的标记同一语言
        Box(
            Modifier
                .size(if (selected) 10.dp else 6.dp)
                .clip(CircleShape)
                .background(if (selected) colors.companion else colors.line)
        )
    }
}
