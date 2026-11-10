package com.langhuan.reader.ui.about

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.langhuan.reader.ui.compose.component.AlertButton
import com.langhuan.reader.ui.compose.component.AppAlertDialogContent
import com.langhuan.reader.ui.compose.component.AppDialog
import com.langhuan.reader.ui.compose.component.AppDialogSizes
import com.langhuan.reader.ui.compose.component.appDialogSize
import org.jetbrains.compose.resources.stringResource
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.no
import com.langhuan.reader.ui.generated.resources.yes

/**
 * 崩溃后重启提示对话框 (对照原版 `MainActivity.notifyAppCrash` 的 `alert`:
 * 标题 `R.string.draw`、正文为原版硬编码文案、"是" 打开崩溃日志、"否" 仅关闭)。
 *
 * 由 [notifyAppCrash] 经 Overlay key `crash_notice` 拉起。
 *
 * @param title 对话框标题 (调用方取 `draw` 串)
 * @param message 对话框正文
 * @param onConfirm "是" (对照原版 yesButton: 打开崩溃日志列表)
 * @param onDismiss "否" / 点击外部关闭
 */
@Composable
fun CrashNoticeDialog(
    title: String,
    message: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AppDialog(
        onDismissRequest = onDismiss,
        properties = AppDialogSizes.properties(),
    ) {
        AppAlertDialogContent(
            onDismissRequest = onDismiss,
            title = title,
            message = message,
            okButton = AlertButton(text = stringResource(Res.string.yes), onClick = onConfirm),
            cancelButton = AlertButton(text = stringResource(Res.string.no)),
            modifier = Modifier.appDialogSize(),
        )
    }
}
