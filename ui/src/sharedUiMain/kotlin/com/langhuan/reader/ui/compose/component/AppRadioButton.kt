package com.langhuan.reader.ui.compose.component

import androidx.compose.material.RadioButton
import androidx.compose.material.RadioButtonDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.langhuan.reader.ui.compose.theme.AppTheme

/** 单选钮：选中色取辅助色 (companion)，形态与 MD2 一致 */
@Composable
fun AppRadioButton(
    selected: Boolean,
    onClick: (() -> Unit)?,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val colors = AppTheme.colors
    RadioButton(
        selected = selected,
        onClick = onClick,
        modifier = modifier,
        enabled = enabled,
        colors = RadioButtonDefaults.colors(
            selectedColor = colors.companion,
            unselectedColor = colors.secondaryText,
        ),
    )
}
