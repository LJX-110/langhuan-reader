package com.langhuan.reader.ui.about

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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.sp
import com.langhuan.reader.ui.compose.theme.AppTheme
import com.langhuan.reader.ui.compose.theme.AppTheme.DesignTokens
import com.langhuan.reader.ui.compose.theme.LanghuanType
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.app_name
import com.langhuan.reader.ui.generated.resources.version
import org.jetbrains.compose.resources.stringResource

/**
 * 顶部身份区：应用名 + 版本号，整块点按复制版本号。
 *
 * 平面排版，不做卡片与描边——层级只靠留白和衬线标题，与全站一致。
 */
@Composable
fun AboutHeader(
    version: String,
    onCopyVersion: () -> Unit,
) {
    val colors = AppTheme.colors
    Column(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onCopyVersion)
            .padding(
                start = DesignTokens.spacingXl,
                end = DesignTokens.spacingXl,
                top = DesignTokens.spacingXl,
                bottom = DesignTokens.spacingLg,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = stringResource(Res.string.app_name),
            style = LanghuanType.pageTitle,
            color = colors.primaryText,
        )
        Spacer(Modifier.height(DesignTokens.spacingDefault))
        Text(
            text = if (version.isEmpty()) {
                stringResource(Res.string.version)
            } else {
                "${stringResource(Res.string.version)} $version"
            },
            color = colors.summaryText,
            fontSize = 12.sp,
            letterSpacing = 0.5.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
