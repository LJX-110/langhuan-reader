package com.langhuan.reader.ui.config

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.constant.BottomNavTag
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.help.config.AppConfigConstants
import com.langhuan.reader.help.config.AppConfigRanges
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.ui.compose.component.AppDialogScaffold
import com.langhuan.reader.ui.compose.component.AppDialogSizes
import com.langhuan.reader.ui.compose.component.AppRadioButton
import com.langhuan.reader.ui.compose.component.AppSlider
import com.langhuan.reader.ui.compose.component.AppTextButton
import com.langhuan.reader.ui.compose.platform.LocalEventBusProvider
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.main.DockIcon
import com.langhuan.reader.ui.main.rememberMainNavColors
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.bookshelf
import com.langhuan.reader.ui.generated.resources.bottom_bar_height
import com.langhuan.reader.ui.generated.resources.bottom_bar_icon_size
import com.langhuan.reader.ui.generated.resources.bottom_bar_icons
import com.langhuan.reader.ui.generated.resources.bottom_bar_label_auto
import com.langhuan.reader.ui.generated.resources.bottom_bar_label_labeled
import com.langhuan.reader.ui.generated.resources.bottom_bar_label_mode
import com.langhuan.reader.ui.generated.resources.bottom_bar_label_selected
import com.langhuan.reader.ui.generated.resources.bottom_bar_label_unlabeled
import com.langhuan.reader.ui.generated.resources.bottom_nav_config
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.discovery
import com.langhuan.reader.ui.generated.resources.home
import com.langhuan.reader.ui.generated.resources.my
import com.langhuan.reader.ui.generated.resources.ok
import com.langhuan.reader.ui.generated.resources.reset
import org.jetbrains.compose.resources.stringResource

/**
 * 底栏配置对话框：静态图标预览 + 高度 / 图标大小 / 标签模式。
 *
 * 主界面固定书架 / 发现 / 本地 / 我四页签，不再提供隐藏与换序，避免设置页写入了
 * 实际不生效的配置。预览图标必须与底栏一致：统一用未选中态的空心资源。
 */
@Composable
fun BottomNavConfigDialog(onDismiss: () -> Unit) {
    val controller = remember { BottomNavConfigController() }
    val height = controller.height
    val iconSize = controller.iconSize
    val labelMode = controller.labelMode
    val colors = AppTheme.colors
    val navColors = rememberMainNavColors()
    val eventBus = LocalEventBusProvider.current

    AppDialogScaffold(
        onDismissRequest = onDismiss,
        title = stringResource(Res.string.bottom_nav_config),
        bottomBar = {
            AppTextButton(text = stringResource(Res.string.reset)) {
                controller.reset()
            }
            Spacer(Modifier.weight(1f))
            AppTextButton(
                text = stringResource(Res.string.cancel),
                color = colors.secondaryText,
                onClick = onDismiss,
            )
            Spacer(Modifier.width(DesignTokens.spacingDefault))
            AppTextButton(text = stringResource(Res.string.ok)) {
                onDismiss()
                if (controller.save()) eventBus.emitRecreate()
            }
        },
        contentPadding = PaddingValues(0.dp),
        properties = AppDialogSizes.properties(),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .weight(1f, fill = false)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = DesignTokens.spacingDefault, vertical = DesignTokens.spacingDefault),
        ) {
            Text(
                stringResource(Res.string.bottom_bar_icons),
                color = colors.primaryText,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
            )
            Spacer(Modifier.height(DesignTokens.spacingDefault))
            // 静态预览: 与 MainBottomBar 同一套图标 key + 未选中态颜色
            Row(Modifier.fillMaxWidth()) {
                bottomNavPreviewTags.forEach { tag ->
                    Column(
                        Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        DockIcon(
                            tag = tag,
                            color = navColors.item,
                            modifier = Modifier.size(iconSize.intValue.dp),
                        )
                        Text(
                            text = stringResource(bottomNavNameRes(tag)),
                            color = navColors.item,
                            fontSize = 11.sp,
                            maxLines = 1,
                        )
                    }
                }
            }
            Spacer(Modifier.height(DesignTokens.spacingDefault))
            // 高度滑条 (对照 sb_height: 36..80)
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(Res.string.bottom_bar_height),
                    color = colors.primaryText,
                    modifier = Modifier.weight(1f),
                )
                Text("${height.intValue}dp", color = colors.primaryText)
            }
            AppSlider(
                value = height.intValue - AppConfigRanges.bottomBarHeight.first,
                max = AppConfigRanges.bottomBarHeight.last - AppConfigRanges.bottomBarHeight.first,
                onValueChange = {
                    height.intValue = it + AppConfigRanges.bottomBarHeight.first
                },
            )
            // 图标大小滑条 (对照 sb_icon: 18..36)
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(Res.string.bottom_bar_icon_size),
                    color = colors.primaryText,
                    modifier = Modifier.weight(1f),
                )
                Text("${iconSize.intValue}dp", color = colors.primaryText)
            }
            AppSlider(
                value = iconSize.intValue - AppConfigRanges.bottomBarIconSize.first,
                max = AppConfigRanges.bottomBarIconSize.last - AppConfigRanges.bottomBarIconSize.first,
                onValueChange = {
                    iconSize.intValue = it + AppConfigRanges.bottomBarIconSize.first
                },
            )
            // 标签模式单选 (对照 rg_label_mode: 0=隐藏 1=常显 2=仅选中 3=自动)
            Text(
                stringResource(Res.string.bottom_bar_label_mode),
                color = colors.primaryText,
                modifier = Modifier.padding(top = DesignTokens.spacingXs),
            )
            Row(
                Modifier
                    .fillMaxWidth()
                    .selectableGroup(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                val labelRes = listOf(
                    Res.string.bottom_bar_label_unlabeled,
                    Res.string.bottom_bar_label_labeled,
                    Res.string.bottom_bar_label_selected,
                    Res.string.bottom_bar_label_auto,
                )
                labelRes.forEachIndexed { i, res ->
                    Row(
                        Modifier
                            .selectable(
                                selected = labelMode.intValue == i,
                                onClick = { labelMode.intValue = i },
                            )
                            .padding(horizontal = DesignTokens.spacingXs, vertical = DesignTokens.spacingXs),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        AppRadioButton(selected = labelMode.intValue == i, onClick = null)
                        Text(stringResource(res), color = colors.primaryText)
                    }
                }
            }
        }
    }
}

private val bottomNavPreviewTags = listOf(
    BottomNavTag.BOOKSHELF,
    BottomNavTag.DISCOVERY,
    BottomNavTag.HOME,
    BottomNavTag.MY,
)

private fun bottomNavNameRes(tag: String) = when (tag) {
    BottomNavTag.HOME -> Res.string.home
    BottomNavTag.BOOKSHELF -> Res.string.bookshelf
    BottomNavTag.DISCOVERY -> Res.string.discovery
    else -> Res.string.my
}

/** 底栏配置业务状态；固定四项，只保存高度、图标大小与标签模式。 */
class BottomNavConfigController {
    private val prefs = PreferenceProviders.get()
    private val appConfig = com.langhuan.reader.help.config.AppConfigProviders.get()

    val height = mutableIntStateOf(appConfig.bottomBarHeight)
    val iconSize = mutableIntStateOf(appConfig.bottomBarIconSize)
    val labelMode = mutableIntStateOf(appConfig.bottomBarLabelMode)

    fun reset() {
        height.intValue = AppConfigConstants.BOTTOM_BAR_HEIGHT_DEFAULT
        iconSize.intValue = AppConfigConstants.BOTTOM_BAR_ICON_DEFAULT
        labelMode.intValue = AppConfigConstants.BOTTOM_BAR_LABEL_DEFAULT
    }

    fun save(): Boolean {
        val changed = appConfig.bottomBarHeight != height.intValue ||
            appConfig.bottomBarIconSize != iconSize.intValue ||
            appConfig.bottomBarLabelMode != labelMode.intValue
        if (appConfig.bottomBarHeight != height.intValue) {
            prefs.putInt(PreferKey.bottomBarHeight, height.intValue)
        }
        if (appConfig.bottomBarIconSize != iconSize.intValue) {
            prefs.putInt(PreferKey.bottomBarIconSize, iconSize.intValue)
        }
        if (appConfig.bottomBarLabelMode != labelMode.intValue) {
            prefs.putInt(PreferKey.bottomBarLabelMode, labelMode.intValue)
        }
        return changed
    }
}