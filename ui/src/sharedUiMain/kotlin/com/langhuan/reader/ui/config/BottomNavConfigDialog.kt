package com.langhuan.reader.ui.config

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
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
import com.langhuan.reader.ui.compose.platform.rememberPainter
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.bookshelf
import com.langhuan.reader.ui.generated.resources.bottom_bar_height
import com.langhuan.reader.ui.generated.resources.bottom_bar_icon_size
import com.langhuan.reader.ui.generated.resources.bottom_bar_items_order
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
import sh.calvin.reorderable.ReorderableCollectionItemScope
import sh.calvin.reorderable.ReorderableItem
import sh.calvin.reorderable.rememberReorderableLazyListState


/**
 * 底栏配置对话框 (shared Compose 重建, 对照 app 端 ThemeConfigHost.configBottomNav
 * + dialog_bottom_nav_config.xml)。各平台复用同一 controller 与 Compose 内容。
 *
 * 顺序网格: 点按开关启用, 横向拖拽换序 (对照 rv_nav_items + ItemTouchHelper);
 * 高度/图标大小滑条 (对照 sb_height/sb_icon); 标签模式单选 (对照 rg_label_mode)。
 */
@Composable
fun BottomNavConfigDialog(onDismiss: () -> Unit) {
    val controller = remember { BottomNavConfigController() }
    val navItems = controller.items
    val height = controller.height
    val iconSize = controller.iconSize
    val labelMode = controller.labelMode
    val colors = AppTheme.colors
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
                stringResource(Res.string.bottom_bar_items_order),
                color = colors.primaryText,
                fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
            )
            Spacer(Modifier.height(DesignTokens.spacingDefault))
            // 复用 ReorderableLazyListState + LazyRow 实现跟手拖拽排序
            // 底栏是横向列表 (LazyRow), 方向由库按布局自动判定
            val navListState = rememberLazyListState()
            val navReorderState =
                rememberReorderableLazyListState(navListState) { from, to ->
                    controller.move(from.index, to.index)
                }
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val cellWidth = maxWidth / navItems.size
                LazyRow(
                    state = navListState,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    items(navItems, key = { it.tag }) { item ->
                        ReorderableItem(navReorderState, key = item.tag) {
                            NavConfigItem(
                                item = item,
                                iconSize = iconSize.intValue,
                                cellWidth = cellWidth,
                                onToggle = { controller.toggle(item.tag) },
                            )
                        }
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
                    .horizontalScroll(rememberScrollState())
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

/** 底栏配置业务状态；默认值、顺序校验、保存和重置由各平台共用。 */
class BottomNavConfigController {
    private val prefs = PreferenceProviders.get()
    private val appConfig = com.langhuan.reader.help.config.AppConfigProviders.get()
    private val defaults = listOf(
        BottomNavConfigItem(BottomNavTag.HOME, appConfig.showHome),
        BottomNavConfigItem(BottomNavTag.BOOKSHELF, true),
        BottomNavConfigItem(BottomNavTag.DISCOVERY, appConfig.showDiscovery),
        BottomNavConfigItem(BottomNavTag.MY, true),
    )

    val items = SnapshotStateList<BottomNavConfigItem>().apply {
        val saved = appConfig.bottomNavItemOrder.split(",").filter(String::isNotEmpty)
        val validTags = defaults.map { it.tag }.toSet()
        addAll(
            if (saved.size == defaults.size && saved.toSet() == validTags) {
                saved.mapNotNull { tag -> defaults.find { it.tag == tag } }
            } else {
                defaults
            }
        )
    }
    val height = mutableIntStateOf(appConfig.bottomBarHeight)
    val iconSize = mutableIntStateOf(appConfig.bottomBarIconSize)
    val labelMode = mutableIntStateOf(appConfig.bottomBarLabelMode)

    fun toggle(tag: String) {
        val index = items.indexOfFirst { it.tag == tag }
        if (index >= 0 && !items[index].locked) {
            items[index] = items[index].copy(enabled = !items[index].enabled)
        }
    }

    fun move(from: Int, to: Int) {
        val item = items[from]
        items[from] = items[to]
        items[to] = item
    }

    fun reset() {
        items.clear()
        items.addAll(defaults.map { it.copy(enabled = true) })
        height.intValue = AppConfigConstants.BOTTOM_BAR_HEIGHT_DEFAULT
        iconSize.intValue = AppConfigConstants.BOTTOM_BAR_ICON_DEFAULT
        labelMode.intValue = AppConfigConstants.BOTTOM_BAR_LABEL_DEFAULT
    }

    fun save(): Boolean {
        val showHome = items.find { it.tag == BottomNavTag.HOME }?.enabled ?: true
        val showDiscovery = items.find { it.tag == BottomNavTag.DISCOVERY }?.enabled ?: true
        val order = items.joinToString(",") { it.tag }
        val changed = appConfig.showHome != showHome ||
            appConfig.showDiscovery != showDiscovery ||
            appConfig.bottomNavItemOrder != order ||
            appConfig.bottomBarHeight != height.intValue ||
            appConfig.bottomBarIconSize != iconSize.intValue ||
            appConfig.bottomBarLabelMode != labelMode.intValue
        prefs.putBoolean(PreferKey.showHome, showHome)
        prefs.putBoolean(PreferKey.showDiscovery, showDiscovery)
        prefs.putString(PreferKey.bottomNavItemOrder, order)
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

/** 底栏配置条目，书架/我的不可隐藏。 */
data class BottomNavConfigItem(
    val tag: String,
    val enabled: Boolean,
) {
    val locked get() = tag == BottomNavTag.BOOKSHELF || tag == BottomNavTag.MY
}

private fun bottomNavNameRes(tag: String) = when (tag) {
    BottomNavTag.HOME -> Res.string.home
    BottomNavTag.BOOKSHELF -> Res.string.bookshelf
    BottomNavTag.DISCOVERY -> Res.string.discovery
    else -> Res.string.my
}

/** 对照 MainNavItem.iconKey: 启用取实心, 禁用取空心 */
private fun bottomNavIconKey(tag: String, enabled: Boolean): String = when (tag) {
    BottomNavTag.HOME -> if (enabled) "ic_bottom_home_s" else "ic_bottom_home_e"
    BottomNavTag.BOOKSHELF -> if (enabled) "ic_bottom_books_s" else "ic_bottom_books_e"
    BottomNavTag.DISCOVERY -> if (enabled) "ic_bottom_explore_s" else "ic_bottom_explore_e"
    else -> if (enabled) "ic_bottom_person_s" else "ic_bottom_person_e"
}

/**
 * 底栏配置单项: 长按拖拽换序 + 点击切换启用 (对照 rv_nav_items item)。
 * 用 longPressDraggableHandle 复用 ReorderableLazyListState 跟手拖拽。
 */
@Composable
private fun ReorderableCollectionItemScope.NavConfigItem(
    item: BottomNavConfigItem,
    iconSize: Int,
    cellWidth: androidx.compose.ui.unit.Dp,
    onToggle: () -> Unit,
) {
    val colors = AppTheme.colors
    val tint = if (item.enabled) colors.accent else colors.primaryText
    Column(
        Modifier
            .width(cellWidth)
            .longPressDraggableHandle(enabled = true)
            .clickable(enabled = !item.locked, onClick = onToggle)
            .padding(vertical = DesignTokens.spacingXs),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            painter = rememberPainter(bottomNavIconKey(item.tag, item.enabled)),
            contentDescription = stringResource(bottomNavNameRes(item.tag)),
            tint = tint,
            modifier = Modifier.size(iconSize.dp),
        )
        Text(
            stringResource(bottomNavNameRes(item.tag)),
            color = tint,
            fontSize = 12.sp,
        )
    }
}
