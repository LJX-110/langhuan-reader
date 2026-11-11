package com.langhuan.reader.ui.about

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.app_name
import com.langhuan.reader.ui.generated.resources.version
import org.jetbrains.compose.resources.stringResource

/**
 * 顶部卡片：应用名 + 版本号，整卡点按复制版本号。
 *
 * 只保留身份信息，不再放简介、彩蛋或外链。
 */
@Composable
fun AboutHeaderCard(
    version: String,
    onCopyVersion: () -> Unit,
) {
    val colors = AppTheme.colors
    Column(
        Modifier
            .fillMaxWidth()
            .padding(DesignTokens.spacingLg)
            .clip(DesignTokens.shapeDefault)
            .background(colors.bottomBackground)
            .clickable(onClick = onCopyVersion)
            .padding(DesignTokens.spacingLg),
    ) {
        Text(
            text = stringResource(Res.string.app_name),
            color = colors.primaryText,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.align(Alignment.CenterHorizontally),
        )
        Spacer(Modifier.height(DesignTokens.spacingDefault))
        Text(
            text = if (version.isEmpty()) {
                stringResource(Res.string.version)
            } else {
                "${stringResource(Res.string.version)} $version"
            },
            color = colors.secondaryText,
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
