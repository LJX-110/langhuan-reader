package com.langhuan.reader.ui.main.my

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.help.config.ReadBookConfigProviders
import com.langhuan.reader.ui.book.read.ReadBookEvents
import com.langhuan.reader.ui.book.read.ReadConfigChange
import com.langhuan.reader.ui.compose.component.AppDialogScaffold
import com.langhuan.reader.ui.compose.component.AppTextButton
import com.langhuan.reader.ui.compose.component.LanghuanDivider
import com.langhuan.reader.ui.compose.component.LanghuanSegmentedControl
import com.langhuan.reader.ui.compose.component.LanghuanSettingsRow
import com.langhuan.reader.ui.compose.platform.LocalEventBusProvider
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.route.FontSelectDialogHost
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.btn_default_s
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.font_settings
import com.langhuan.reader.ui.generated.resources.font_weight
import com.langhuan.reader.ui.generated.resources.ic_add
import com.langhuan.reader.ui.generated.resources.ic_interface_setting
import com.langhuan.reader.ui.generated.resources.ic_reduce
import com.langhuan.reader.ui.generated.resources.interface_font_size
import com.langhuan.reader.ui.generated.resources.ok
import com.langhuan.reader.ui.generated.resources.system_font
import com.langhuan.reader.ui.generated.resources.text_font
import com.langhuan.reader.ui.generated.resources.text_font_weight
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringArrayResource
import org.jetbrains.compose.resources.stringResource

/**
 * 「字体」统一设置：字体族、字重、界面字号。
 *
 * 旧版我的页把字重与界面字号拆成两个同级入口；这里合并后只保留一个「字体」入口，
 * 三项在同一个弹层里按顺序排布，和设置页的行/分段控件保持同一套语言。
 */
@Composable
fun FontSettingsDialog(onDismiss: () -> Unit) {
    val readConfig = ReadBookConfigProviders.get()
    val pref = PreferenceProviders.get()
    val eventBus = LocalEventBusProvider.current
    val colors = AppTheme.colors
    val systemFont = stringResource(Res.string.system_font)
    val weightNames = stringArrayResource(Res.array.text_font_weight)

    var showFontPicker by remember { mutableStateOf(false) }
    var fontTick by remember { mutableIntStateOf(0) }
    var weight by remember { mutableIntStateOf(readConfig.textBold) }
    val initialScale = remember {
        pref.getInt(PreferKey.fontScale, 0).let { if (it == 0) DEFAULT_FONT_SCALE else it }
    }
    var scale by remember { mutableIntStateOf(initialScale) }

    fun applyWeight(index: Int) {
        if (weight == index) return
        weight = index
        readConfig.textBold = index
        readConfig.save()
        ReadBookEvents.postConfig(
            listOf(
                ReadConfigChange.CHAPTER_STYLE,
                ReadConfigChange.INVALIDATE_TEXT_PAGE,
                ReadConfigChange.UP_CONTENT,
            )
        )
    }

    fun applyScale() {
        if (scale != initialScale) {
            pref.putInt(PreferKey.fontScale, scale)
            eventBus.emitRecreate()
        }
        onDismiss()
    }

    AppDialogScaffold(
        onDismissRequest = onDismiss,
        title = stringResource(Res.string.font_settings),
        bottomBar = {
            Spacer(Modifier.weight(1f))
            AppTextButton(
                text = stringResource(Res.string.cancel),
                color = colors.secondaryText,
                onClick = onDismiss,
            )
            Spacer(Modifier.width(DesignTokens.spacingDefault))
            AppTextButton(text = stringResource(Res.string.ok)) { applyScale() }
        },
        contentPadding = PaddingValues(0.dp),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = DesignTokens.spacingDefault),
            verticalArrangement = Arrangement.spacedBy(DesignTokens.spacingDefault),
        ) {
            LanghuanSettingsRow(
                title = stringResource(Res.string.text_font),
                icon = painterResource(Res.drawable.ic_interface_setting),
                value = readConfig.textFont.substringAfterLast('/').ifEmpty { systemFont },
                onClick = { showFontPicker = true },
            )
            LanghuanDivider()
            Column(
                Modifier.padding(top = DesignTokens.spacingXs),
                verticalArrangement = Arrangement.spacedBy(DesignTokens.spacingXs),
            ) {
                Text(
                    text = stringResource(Res.string.font_weight),
                    color = colors.primaryText,
                    fontSize = 14.sp,
                )
                LanghuanSegmentedControl(
                    options = weightNames,
                    selectedIndex = weight,
                    onSelect = ::applyWeight,
                )
            }
            LanghuanDivider()
            Column(
                Modifier.padding(top = DesignTokens.spacingXs),
                verticalArrangement = Arrangement.spacedBy(DesignTokens.spacingXs),
            ) {
                Text(
                    text = stringResource(Res.string.interface_font_size),
                    color = colors.primaryText,
                    fontSize = 14.sp,
                )
                Row(
                    Modifier.fillMaxWidth().height(DesignTokens.viewHeightXl),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center,
                ) {
                    IconButton(
                        onClick = { if (scale > MIN_FONT_SCALE) scale-- },
                        enabled = scale > MIN_FONT_SCALE,
                    ) {
                        Icon(
                            painter = painterResource(Res.drawable.ic_reduce),
                            contentDescription = null,
                            tint = if (scale > MIN_FONT_SCALE) colors.primaryText else colors.textDisabled,
                        )
                    }
                    Text(
                        text = "%.1f×".format(scale / 10f),
                        color = colors.primaryText,
                        fontSize = 15.sp,
                        modifier = Modifier.padding(horizontal = DesignTokens.spacingLg),
                    )
                    IconButton(
                        onClick = { if (scale < MAX_FONT_SCALE) scale++ },
                        enabled = scale < MAX_FONT_SCALE,
                    ) {
                        Icon(
                            painter = painterResource(Res.drawable.ic_add),
                            contentDescription = null,
                            tint = if (scale < MAX_FONT_SCALE) colors.primaryText else colors.textDisabled,
                        )
                    }
                    AppTextButton(
                        text = stringResource(Res.string.btn_default_s),
                        color = colors.secondaryText,
                        onClick = { scale = DEFAULT_FONT_SCALE },
                    )
                }
            }
        }
    }

    if (showFontPicker) {
        FontSelectDialogHost(
            onDismiss = {
                showFontPicker = false
                fontTick++ // 触发父弹层重读字体名
            }
        )
    }
    // 读一次 tick，让字体选择返回后当前值立即更新
    fontTick
}

private const val MIN_FONT_SCALE = 8
private const val MAX_FONT_SCALE = 16
private const val DEFAULT_FONT_SCALE = 10