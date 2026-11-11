package com.langhuan.reader.ui.compose.component

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.LanghuanType
import com.langhuan.reader.ui.compose.theme.langhuanOnColor
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.ic_arrow_right
import com.langhuan.reader.ui.generated.resources.ic_search
import org.jetbrains.compose.resources.painterResource

/**
 * 琅嬛阁页面标题：左侧一道主题色细竖线 + 22sp 衬线标题，右侧留给操作。
 *
 * 每页只保留这一行标题——不再叠加品牌顶栏、英文副题或档案编号。
 */
@Composable
fun LanghuanPageHeader(
    title: String,
    modifier: Modifier = Modifier,
    actions: @Composable RowScope.() -> Unit = {},
) {
    val colors = AppTheme.colors
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 8.dp, top = 8.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .width(3.dp)
                .height(18.dp)
                .clip(RoundedCornerShape(1.5.dp))
                .background(colors.accentFill)
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text = title,
            style = LanghuanType.pageTitle,
            color = colors.accent,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Spacer(Modifier.weight(1f))
        actions()
    }
}

/** 书架 / 发现页顶部的安静搜索入口：细描边胶囊，无阴影。 */
@Composable
fun LanghuanSearchEntry(
    hint: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(34.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(colors.fillet)
            .border(0.5.dp, colors.line, RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            painter = painterResource(Res.drawable.ic_search),
            contentDescription = null,
            tint = colors.summaryText,
            modifier = Modifier.size(16.dp),
        )
        Spacer(Modifier.width(7.dp))
        Text(
            text = hint,
            color = colors.summaryText,
            fontSize = 12.5.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** 区块标题（分组名、书架名）：衬线，字距略松。 */
@Composable
fun LanghuanSectionTitle(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        style = LanghuanType.sectionTitle,
        color = AppTheme.colors.primaryText,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier,
    )
}

/** 细边线：默认白底 0.5dp 浅灰、黑底深灰；设置面板传辅助色以区分层级。 */
@Composable
fun LanghuanDivider(
    modifier: Modifier = Modifier,
    color: Color = AppTheme.colors.line,
) {
    Box(
        modifier
            .fillMaxWidth()
            .height(0.5.dp)
            .background(color)
    )
}

/**
 * 设置分组面板：衬线分组标题 + 行，行之间由调用方插入 [LanghuanSettingsDivider]。
 *
 * 不画卡片、不叠描边，靠留白与字重分组；左右 20dp 与页面标题同一条竖线。
 */
@Composable
fun LanghuanSettingsGroup(
    title: String,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, top = 20.dp)
    ) {
        Row(
            Modifier.padding(bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .width(3.dp)
                    .height(14.dp)
                    .clip(RoundedCornerShape(1.5.dp))
                    .background(AppTheme.colors.accentFill)
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = title,
                style = LanghuanType.sectionTitle,
                color = AppTheme.colors.primaryText,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        content()
    }
}

/** 分组内的行间分隔线：辅助色淡线，只在设置面板里出现。 */
@Composable
fun LanghuanSettingsDivider() {
    LanghuanDivider(color = AppTheme.colors.companion.copy(alpha = 0.35f))
}

/**
 * 设置行：左侧辅助色图标、中间标题、右侧值/箭头。
 *
 * 不写解释性小字；[value] 只放当前值（字体大小、版本号），不是说明。
 */
@Composable
fun LanghuanSettingsRow(
    title: String,
    icon: Painter,
    modifier: Modifier = Modifier,
    value: String? = null,
    showArrow: Boolean = true,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    val colors = AppTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .then(if (enabled) Modifier.listItemFocus().clickable(onClick = onClick) else Modifier)
            .then(if (enabled) Modifier else Modifier.alpha(0.38f))
            .heightIn(min = 56.dp)
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            painter = icon,
            contentDescription = null,
            tint = colors.accent,
            modifier = Modifier.size(22.dp),
        )
        Spacer(Modifier.width(14.dp))
        Text(
            text = title,
            color = colors.primaryText,
            fontSize = 16.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (!value.isNullOrEmpty()) {
            Text(
                text = value,
                color = colors.secondaryText,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (showArrow) {
            Spacer(Modifier.width(6.dp))
            Icon(
                painter = painterResource(Res.drawable.ic_arrow_right),
                contentDescription = null,
                tint = colors.companion.copy(alpha = 0.75f),
                modifier = Modifier.size(16.dp),
            )
        }
    }
}

/** 三段切换：跟随系统 / 浅色 / 深色。选中段用主色填充，其余透明。 */
@Composable
fun LanghuanSegmentedControl(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AppTheme.colors
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(colors.companion.copy(alpha = 0.10f))
            .padding(3.dp),
    ) {
        options.forEachIndexed { index, label ->
            val selected = index == selectedIndex
            Box(
                Modifier
                    .weight(1f)
                    .height(34.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .then(
                        if (selected) Modifier.background(colors.accentFill)
                        else Modifier.clickable { onSelect(index) }
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    color = if (selected) langhuanOnColor(colors.accentFill) else colors.secondaryText,
                    fontSize = 14.sp,
                    maxLines = 1,
                )
            }
        }
    }
}
