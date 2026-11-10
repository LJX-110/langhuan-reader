package com.langhuan.reader.ui.root

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.ui.dialog.TextInputDialog
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.import_file_name
import org.jetbrains.compose.resources.stringResource

/**
 * 按文件名导入编辑框的 Overlay 渲染实现。
 *
 * 对照 app 端原命令式对话框基类(已删除) 的 alertImportFileName:
 * 确认后写 PreferKey.bookImportFileName。六种内容导入的对话框已统一走
 * DeepLinkImportTarget + ImportItemsDialog 一条链 (勾选六型经 LanghuanDeepLinkHandler
 * 分发, 规则订阅走 RuleOverlayDialogs), 不再有独立的通用导入 Overlay。
 */

// 按文件名导入 js 编辑框 (key="import_file_name", 对照 app 端 alertImportFileName):
// 鸿蒙无命令式文本输入宿主, 经共享 Overlay 弹 [TextInputDialog]; 确认写 PreferKey.bookImportFileName
@Composable
internal fun ImportFileNameOverlayDialogContent(overlay: AppOverlay.Dialog, navigator: AppNavigator) {
    val prefs = remember { PreferenceProviders.get() }
    TextInputDialog(
        title = stringResource(Res.string.import_file_name),
        message = "使用js处理文件名变量src，将书名作者分别赋值到变量name author",
        initialValue = prefs.getString(PreferKey.bookImportFileName, ""),
        hint = "js",
        onConfirm = { text ->
            prefs.putString(PreferKey.bookImportFileName, text)
            navigator.dismissOverlay(overlay.key)
        },
        onDismiss = { navigator.dismissOverlay(overlay.key) },
    )
}
