package com.langhuan.reader.ui.book.source.health

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.data.entities.BookSourcePart
import com.langhuan.reader.ui.compose.component.AlertButton
import com.langhuan.reader.ui.compose.component.AppAlertDialog
import com.langhuan.reader.ui.compose.component.AppBottomSheetDialog
import com.langhuan.reader.ui.compose.component.AppOutlinedButton
import com.langhuan.reader.ui.compose.component.AppRadioButton
import com.langhuan.reader.ui.compose.component.AppSheetSurface
import com.langhuan.reader.ui.compose.component.AppSolidButton
import com.langhuan.reader.ui.compose.component.AppSwitchRow
import com.langhuan.reader.ui.compose.component.AppTextField
import com.langhuan.reader.ui.compose.component.AppTextButton
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.compose.theme.LanghuanType
import com.langhuan.reader.ui.compose.theme.LocalEInk
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.delete
import com.langhuan.reader.ui.generated.resources.keyword
import com.langhuan.reader.ui.generated.resources.ok
import com.langhuan.reader.ui.generated.resources.source_health_check
import com.langhuan.reader.ui.generated.resources.source_health_delete_confirm
import com.langhuan.reader.ui.generated.resources.source_health_delete_failed
import com.langhuan.reader.ui.generated.resources.source_health_disable_failed
import com.langhuan.reader.ui.generated.resources.source_health_export_failed
import com.langhuan.reader.ui.generated.resources.source_health_failed
import com.langhuan.reader.ui.generated.resources.source_health_full
import com.langhuan.reader.ui.generated.resources.source_health_full_desc
import com.langhuan.reader.ui.generated.resources.source_health_mode
import com.langhuan.reader.ui.generated.resources.source_health_only_enabled
import com.langhuan.reader.ui.generated.resources.source_health_quick
import com.langhuan.reader.ui.generated.resources.source_health_quick_desc
import com.langhuan.reader.ui.generated.resources.source_health_quick_note
import com.langhuan.reader.ui.generated.resources.source_health_reason_other
import com.langhuan.reader.ui.generated.resources.source_health_reasons
import com.langhuan.reader.ui.generated.resources.source_health_result
import com.langhuan.reader.ui.generated.resources.source_health_scope
import com.langhuan.reader.ui.generated.resources.source_health_scope_all
import com.langhuan.reader.ui.generated.resources.source_health_scope_current
import com.langhuan.reader.ui.generated.resources.source_health_start
import com.langhuan.reader.ui.generated.resources.source_health_total
import com.langhuan.reader.ui.generated.resources.source_health_usable
import com.langhuan.reader.ui.generated.resources.source_health_view_failed
import org.jetbrains.compose.resources.stringResource

/** 体检范围。当前筛选结果复用列表当前查询，全部书源直接查 DAO。 */
enum class SourceHealthScope { All, Current }

/** 一轮体检的结果。failed 只包含本轮实际参与校验、且仍带「失效」组的书源。 */
data class SourceHealthResult(
    val total: Int,
    val failed: List<BookSourcePart>,
    val quick: Boolean,
)

/** 失效原因优先级：越具体越靠前，避免同一条源同时进多个组时只显示笼统的「失效」。 */
private val failureReasonPriority = listOf(
    "校验超时",
    "js失效",
    "网站失效",
    "搜索失效",
    "发现失效",
    "搜索目录失效",
    "搜索正文失效",
    "发现目录失效",
    "发现正文失效",
    "搜索链接规则为空",
    "发现规则为空",
)

/** 与 [com.langhuan.reader.data.entities.BookSource.getInvalidGroupNames] 同口径: 含「失效」或「校验超时」。 */
fun BookSourcePart.isFailedSource(): Boolean =
    bookSourceGroup.orEmpty()
        .split(",", "，")
        .map { it.trim() }
        .any { "失效" in it || it == "校验超时" }

/**
 * 把失效书源按原因归并。
 *
 * 书源分组是逗号分隔的字符串，失败时 [com.langhuan.reader.model.CheckSourceShared] 会同时写入
 * 具体原因组与统一的「失效」组；这里优先取最具体的一条，统一「失效」组留给兜底。
 */
fun healthFailureReasons(
    failed: List<BookSourcePart>,
    otherLabel: String,
): List<Pair<String, Int>> {
    val counts = linkedMapOf<String, Int>()
    failed.forEach { part ->
        val groups = part.bookSourceGroup.orEmpty()
            .split(",", "，")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        val reason = failureReasonPriority.firstOrNull { it in groups }
            ?: groups.firstOrNull { "失效" in it }
            ?: otherLabel
        counts[reason] = (counts[reason] ?: 0) + 1
    }
    return counts.entries
        .sortedByDescending { it.value }
        .map { it.key to it.value }
}

/** 体检配置面板。范围、是否仅启用、快速/完整与关键词都在这里定。 */
@Composable
fun SourceHealthCheckSheet(
    allCount: Int,
    currentCount: Int,
    keyword: String,
    defaultScope: SourceHealthScope,
    onStart: (scope: SourceHealthScope, onlyEnabled: Boolean, quick: Boolean, keyword: String) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = AppTheme.colors
    var scope by remember(defaultScope) { mutableStateOf(defaultScope) }
    var onlyEnabled by remember { mutableStateOf(false) }
    var quick by remember { mutableStateOf(true) }
    var keywordText by remember(keyword) { mutableStateOf(keyword) }

    val strScopeAll = stringResource(Res.string.source_health_scope_all)
    val strScopeCurrent = stringResource(Res.string.source_health_scope_current)
    val strQuick = stringResource(Res.string.source_health_quick)
    val strQuickDesc = stringResource(Res.string.source_health_quick_desc)
    val strFull = stringResource(Res.string.source_health_full)
    val strFullDesc = stringResource(Res.string.source_health_full_desc)

    AppBottomSheetDialog(onDismissRequest = onDismiss) {
        AppSheetSurface(Modifier.fillMaxWidth()) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = DesignTokens.spacingLg),
            ) {
                Spacer(Modifier.height(DesignTokens.spacingLg))
                Text(
                    text = stringResource(Res.string.source_health_check),
                    color = colors.primaryText,
                    style = LanghuanType.pageTitle,
                )
                Spacer(Modifier.height(DesignTokens.spacingLg))

                SheetSectionLabel(stringResource(Res.string.source_health_scope))
                ScopeRow(
                    title = "$strScopeAll · $allCount",
                    selected = scope == SourceHealthScope.All,
                    onClick = { scope = SourceHealthScope.All },
                )
                ScopeRow(
                    title = "$strScopeCurrent · $currentCount",
                    selected = scope == SourceHealthScope.Current,
                    onClick = { scope = SourceHealthScope.Current },
                )
                AppSwitchRow(
                    label = stringResource(Res.string.source_health_only_enabled),
                    checked = onlyEnabled,
                    onCheckedChange = { onlyEnabled = it },
                )

                Spacer(Modifier.height(DesignTokens.spacingDefault))
                SheetSectionLabel(stringResource(Res.string.source_health_mode))
                ScopeRow(
                    title = strQuick,
                    description = strQuickDesc,
                    selected = quick,
                    onClick = { quick = true },
                )
                ScopeRow(
                    title = strFull,
                    description = strFullDesc,
                    selected = !quick,
                    onClick = { quick = false },
                )
                if (quick) {
                    Text(
                        text = stringResource(Res.string.source_health_quick_note),
                        color = colors.summaryText,
                        fontSize = 12.sp,
                        modifier = Modifier.padding(start = 48.dp, top = 2.dp),
                    )
                }

                Spacer(Modifier.height(DesignTokens.spacingDefault))
                AppTextField(
                    value = keywordText,
                    onValueChange = { keywordText = it },
                    label = stringResource(Res.string.keyword),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )

                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(vertical = DesignTokens.spacingLg),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    AppTextButton(
                        text = stringResource(Res.string.cancel),
                        color = colors.secondaryText,
                        onClick = onDismiss,
                    )
                    Spacer(Modifier.width(DesignTokens.spacingDefault))
                    AppSolidButton(
                        text = stringResource(Res.string.source_health_start),
                        modifier = Modifier.weight(1f),
                        enabled = keywordText.isNotBlank(),
                        onClick = {
                            onStart(scope, onlyEnabled, quick, keywordText.trim())
                        },
                    )
                }
            }
        }
    }
}

/** 结果面板：先给结论，再给原因；清理动作默认只到「禁用」，删除必须再确认。 */
@Composable
fun SourceHealthResultSheet(
    result: SourceHealthResult,
    onDismiss: () -> Unit,
    onViewFailed: () -> Unit,
    onExportFailed: () -> Unit,
    onDisableFailed: () -> Unit,
    onDeleteFailed: () -> Unit,
) {
    val colors = AppTheme.colors
    val failedCount = result.failed.size
    val usableCount = (result.total - failedCount).coerceAtLeast(0)
    val reasons = healthFailureReasons(
        failed = result.failed,
        otherLabel = stringResource(Res.string.source_health_reason_other),
    )
    val maxReasonCount = reasons.maxOfOrNull { it.second } ?: 0
    val modeLabel = stringResource(
        if (result.quick) Res.string.source_health_quick else Res.string.source_health_full
    )

    AppBottomSheetDialog(onDismissRequest = onDismiss) {
        AppSheetSurface(Modifier.fillMaxWidth()) {
            Column(
                Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = DesignTokens.spacingLg),
            ) {
                Spacer(Modifier.height(DesignTokens.spacingLg))
                Text(
                    text = stringResource(Res.string.source_health_result),
                    color = colors.primaryText,
                    style = LanghuanType.pageTitle,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    text = stringResource(Res.string.source_health_total, result.total) + " · " + modeLabel,
                    color = colors.summaryText,
                    fontSize = 12.sp,
                )
                Spacer(Modifier.height(DesignTokens.spacingLg))

                Row(Modifier.fillMaxWidth()) {
                    ResultMetric(
                        value = usableCount,
                        label = stringResource(Res.string.source_health_usable),
                        color = colors.accent,
                        modifier = Modifier.weight(1f),
                    )
                    ResultMetric(
                        value = failedCount,
                        label = stringResource(Res.string.source_health_failed),
                        color = if (failedCount > 0) colors.danger else colors.secondaryText,
                        modifier = Modifier.weight(1f),
                    )
                }

                if (reasons.isNotEmpty()) {
                    Spacer(Modifier.height(DesignTokens.spacingLg))
                    Text(
                        text = stringResource(Res.string.source_health_reasons),
                        color = colors.primaryText,
                        fontSize = 13.sp,
                    )
                    Spacer(Modifier.height(DesignTokens.spacingXs))
                    reasons.forEach { (reason, count) ->
                        ReasonBar(
                            reason = reason,
                            count = count,
                            fraction = if (maxReasonCount == 0) 0f else count.toFloat() / maxReasonCount,
                        )
                    }
                }

                Row(
                    Modifier
                        .fillMaxWidth()
                        .padding(top = DesignTokens.spacingLg),
                    horizontalArrangement = Arrangement.spacedBy(DesignTokens.spacingDefault),
                ) {
                    if (failedCount > 0) {
                        AppOutlinedButton(
                            text = stringResource(Res.string.source_health_view_failed),
                            modifier = Modifier
                                .weight(1f)
                                .height(DesignTokens.viewHeightXl),
                            onClick = onViewFailed,
                        )
                        AppSolidButton(
                            text = stringResource(Res.string.source_health_disable_failed),
                            modifier = Modifier.weight(1f),
                            onClick = onDisableFailed,
                        )
                    } else {
                        AppSolidButton(
                            text = stringResource(Res.string.ok),
                            modifier = Modifier.weight(1f),
                            onClick = onDismiss,
                        )
                    }
                }
                if (failedCount > 0) {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(top = DesignTokens.spacingXs),
                        horizontalArrangement = Arrangement.Center,
                    ) {
                        AppTextButton(
                            text = stringResource(Res.string.source_health_export_failed),
                            color = colors.secondaryText,
                            onClick = onExportFailed,
                        )
                        Spacer(Modifier.width(DesignTokens.spacingDefault))
                        AppTextButton(
                            text = stringResource(Res.string.source_health_delete_failed),
                            color = colors.danger,
                            onClick = onDeleteFailed,
                        )
                    }
                }
                Spacer(Modifier.height(DesignTokens.spacingLg))
            }
        }
    }
}

/** 删除确认：数量写进正文，避免在结果页里不看清就删。 */
@Composable
fun SourceHealthDeleteConfirmDialog(
    failedCount: Int,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AppAlertDialog(
        onDismissRequest = onDismiss,
        title = stringResource(Res.string.source_health_delete_failed),
        message = stringResource(Res.string.source_health_delete_confirm, failedCount),
        okButton = AlertButton(stringResource(Res.string.delete)) { onConfirm() },
        cancelButton = AlertButton(stringResource(Res.string.cancel)) { onDismiss() },
    )
}

@Composable
private fun SheetSectionLabel(text: String) {
    Text(
        text = text,
        color = AppTheme.colors.summaryText,
        style = LanghuanType.label,
        modifier = Modifier.padding(bottom = DesignTokens.spacingXs),
    )
}

@Composable
private fun ScopeRow(
    title: String,
    selected: Boolean,
    onClick: () -> Unit,
    description: String? = null,
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(DesignTokens.shapeDefault)
            .selectable(selected = selected, role = Role.RadioButton, onClick = onClick)
            .padding(vertical = DesignTokens.spacingXs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AppRadioButton(selected = selected, onClick = null)
        Spacer(Modifier.width(DesignTokens.spacingXs))
        Column(Modifier.weight(1f)) {
            Text(
                text = title,
                color = AppTheme.colors.primaryText,
                fontSize = 14.sp,
            )
            if (description != null) {
                Text(
                    text = description,
                    color = AppTheme.colors.summaryText,
                    fontSize = 12.sp,
                )
            }
        }
    }
}

@Composable
private fun ResultMetric(
    value: Int,
    label: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    val animated by animateIntAsState(
        targetValue = value,
        animationSpec = tween(durationMillis = 420),
        label = "sourceHealthMetric",
    )
    val shown = if (LocalEInk.current) value else animated
    Column(modifier) {
        Text(
            text = "$shown",
            color = color,
            style = LanghuanType.numeral,
        )
        Text(
            text = label,
            color = AppTheme.colors.summaryText,
            fontSize = 12.sp,
        )
    }
}

@Composable
private fun ReasonBar(
    reason: String,
    count: Int,
    fraction: Float,
) {
    val colors = AppTheme.colors
    val animatedFraction by animateFloatAsState(
        targetValue = fraction.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 420),
        label = "sourceHealthReasonBar",
    )
    val shownFraction = if (LocalEInk.current) fraction.coerceIn(0f, 1f) else animatedFraction
    Row(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = reason,
            color = colors.secondaryText,
            fontSize = 12.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.width(112.dp),
        )
        Box(
            Modifier
                .weight(1f)
                .height(4.dp)
                .clip(DesignTokens.shapeSm)
                .background(colors.accent.copy(alpha = 0.12f)),
        ) {
            Box(
                Modifier
                    .fillMaxWidth(shownFraction)
                    .height(4.dp)
                    .background(colors.accent.copy(alpha = 0.75f)),
            )
        }
        Spacer(Modifier.width(DesignTokens.spacingXs))
        Text(
            text = "$count",
            color = colors.summaryText,
            fontSize = 12.sp,
        )
    }
}
