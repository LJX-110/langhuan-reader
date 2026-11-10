package com.langhuan.reader.ui.book.group

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.BookGroup
import com.langhuan.reader.help.coroutine.IoDispatcher
import com.langhuan.reader.ui.compose.component.AppCheckbox
import com.langhuan.reader.ui.compose.component.AppDialogScaffold
import com.langhuan.reader.ui.compose.component.AppDialogSizes
import com.langhuan.reader.ui.compose.component.AppTextButton
import com.langhuan.reader.ui.compose.component.RuleManageScaffold
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.edit
import com.langhuan.reader.ui.generated.resources.group_add
import com.langhuan.reader.ui.generated.resources.group_select
import com.langhuan.reader.ui.generated.resources.ic_add
import com.langhuan.reader.ui.generated.resources.ok
import kotlinx.coroutines.flow.conflate
import kotlinx.coroutines.flow.flowOn
import org.jetbrains.compose.resources.painterResource
import org.jetbrains.compose.resources.stringResource
import sh.calvin.reorderable.ReorderableCollectionItemScope

/**
 * 分组选择对话框。
 *
 * 布局与 Android 原版保持一致：标题栏添加入口、可拖拽列表、行内编辑以及底部取消/确定栏。
 */
@Composable
fun GroupSelectDialog(
    initialGroupId: Long,
    onConfirm: (Long) -> Unit,
    onDismiss: () -> Unit,
    onPersistOrder: (List<BookGroup>) -> Unit,
    onAddGroup: () -> Unit,
    onEditGroup: (BookGroup) -> Unit,
) {
    val colors = AppTheme.colors
    var groupId by remember(initialGroupId) { mutableLongStateOf(initialGroupId) }
    // 分组数据由对话框自取 flowSelect (仅 groupId >= 0 的用户分组): 管理页的 flowAll 含
    // "全部/本地/未分组/更新失败" 等负 id 行, 参与位掩码勾选会污染 groupId
    var groups by remember { mutableStateOf<List<BookGroup>>(emptyList()) }
    var displayGroups by remember(groups) { mutableStateOf(groups) }

    LaunchedEffect(Unit) {
        AppDbProviders.get().bookGroupDao.flowSelect().conflate().flowOn(IoDispatcher).collect {
            groups = it
        }
    }

    AppDialogScaffold(
        onDismissRequest = onDismiss,
        title = stringResource(Res.string.group_select),
        titleActions = {
            IconButton(onClick = onAddGroup) {
                Icon(
                    painter = painterResource(Res.drawable.ic_add),
                    contentDescription = stringResource(Res.string.group_add),
                    tint = colors.primaryText,
                )
            }
        },
        bottomBar = {
            Spacer(Modifier.weight(1f))
            AppTextButton(
                text = stringResource(Res.string.cancel),
                color = colors.secondaryText,
                onClick = onDismiss,
            )
            AppTextButton(text = stringResource(Res.string.ok)) {
                onConfirm(groupId)
            }
        },
        contentPadding = PaddingValues(0.dp),
        properties = AppDialogSizes.properties(),
    ) {
        RuleManageScaffold(
            items = displayGroups,
            itemKey = { it.groupId },
            fillMaxHeight = false,
            // 列表高度自适应内容: 分组少时对话框随内容收缩, 多时由 appDialogSize 的
            // heightIn(max=0.7×锚点高) 封顶且列表可滚动 (复刻原版 AutoShrinkLinearLayout 语义)
            wrapContentHeight = true,
            onMove = { from, to ->
                displayGroups = displayGroups.toMutableList().apply {
                    add(to, removeAt(from))
                }
            },
        ) { item ->
            GroupItem(
                item = item,
                checked = (groupId and item.groupId) > 0,
                onCheckedChange = { checked ->
                    groupId = if (checked) {
                        groupId or item.groupId
                    } else {
                        groupId and item.groupId.inv()
                    }
                },
                onEdit = { onEditGroup(item) },
                onPersistOrder = {
                    val ordered = displayGroups.mapIndexed { index, group ->
                        group.copy(order = index + 1)
                    }
                    displayGroups = ordered
                    onPersistOrder(ordered)
                },
            )
        }
    }
}

@Composable
private fun ReorderableCollectionItemScope.GroupItem(
    item: BookGroup,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    onEdit: () -> Unit,
    onPersistOrder: () -> Unit,
) {
    val colors = AppTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .longPressDraggableHandle(onDragStopped = onPersistOrder)
            .clickable { onCheckedChange(!checked) }
            // 垂直 padding 去掉: 行高由 M2 Checkbox 48dp 交互区决定 (原版 Material CheckBox
            // 40dp 触摸区 + 8×2 padding ≈ 56dp; 此处去 padding 后 48dp 视觉密度相当)
            .padding(horizontal = DesignTokens.spacingDefault),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AppCheckbox(
            checked = checked,
            onCheckedChange = onCheckedChange,
        )
        Text(
            text = item.groupName,
            color = colors.primaryText,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(DesignTokens.spacingDefault))
        Text(
            text = stringResource(Res.string.edit),
            color = colors.primaryText,
            modifier = Modifier
                .clickable(onClick = onEdit)
                .padding(DesignTokens.spacingDefault),
        )
    }
}
