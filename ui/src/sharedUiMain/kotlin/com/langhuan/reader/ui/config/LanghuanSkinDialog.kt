package com.langhuan.reader.ui.config

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.ui.compose.component.AppDialogScaffold
import com.langhuan.reader.ui.compose.component.AppTextButton
import com.langhuan.reader.ui.compose.component.LanghuanDivider
import com.langhuan.reader.ui.compose.component.LanghuanSegmentedControl
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.compose.theme.LanghuanThemePreset
import com.langhuan.reader.ui.compose.theme.LanghuanThemes
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.langhuan_skin
import com.langhuan.reader.ui.generated.resources.ok
import com.langhuan.reader.ui.generated.resources.theme_mode_dark
import com.langhuan.reader.ui.generated.resources.theme_mode_follow
import com.langhuan.reader.ui.generated.resources.theme_mode_light
import org.jetbrains.compose.resources.stringResource

/**
 * 皮肤面板：顶部三段明暗档位，下方 12 套双色主题。
 *
 * 点「确定」后先写明暗档位与皮肤下标，再走平台 applyDayNight 重算主题并广播重建。
 * 只写入皮肤与明暗，不碰读者的正文纸张设置——换肤永远不应该改变正在读的那一页的颜色。
 */
@Composable
fun LanghuanSkinDialog(onDismiss: () -> Unit) {
    val colors = AppTheme.colors
    var selected by remember { mutableIntStateOf(LanghuanThemes.currentIndex()) }
    var selectedMode by remember {
        mutableIntStateOf(
            when (PreferenceProviders.get().getStringOrNull(PreferKey.themeMode)) {
                "0" -> 0
                "2" -> 2
                else -> 1
            }
        )
    }
    val modeOptions = listOf(
        stringResource(Res.string.theme_mode_follow),
        stringResource(Res.string.theme_mode_light),
        stringResource(Res.string.theme_mode_dark),
    )

    AppDialogScaffold(
        onDismissRequest = onDismiss,
        title = stringResource(Res.string.langhuan_skin),
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
                PreferenceProviders.get().putString(PreferKey.themeMode, selectedMode.toString())
                // 明暗档位与皮肤一起落库后重算主题并广播重建，避免两次重建
                PlatformCapabilityProviders.get().applyDayNight()
                onDismiss()
            }
        },
    ) {
        LanghuanSegmentedControl(
            options = modeOptions,
            selectedIndex = selectedMode,
            onSelect = { selectedMode = it },
            modifier = Modifier.padding(horizontal = DesignTokens.spacingDefault),
        )
        Spacer(Modifier.height(DesignTokens.spacingDefault))
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
