package com.langhuan.reader.ui.root

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.TxtTocRule
import com.langhuan.reader.help.coroutine.IoDispatcher
import com.langhuan.reader.help.storage.BackupFileOps
import com.langhuan.reader.ui.association.ImportItemsDialog
import com.langhuan.reader.ui.association.ImportTxtTocRuleItemsVm
import com.langhuan.reader.ui.association.ImportTxtTocRuleViewModelShared
import com.langhuan.reader.ui.book.toc.rule.TxtTocRuleEditDialog
import com.langhuan.reader.ui.widget.dialog.HelpDialog
import com.langhuan.reader.ui.widget.dialog.OnlineImportUrlDialog
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.help
import com.langhuan.reader.ui.generated.resources.import_txt_toc_rule
import com.langhuan.reader.ui.generated.resources.update_log
import com.langhuan.reader.ui.generated.resources.wrong_format
import org.jetbrains.compose.resources.stringResource

/**
 * 规则类 Overlay Dialog 的渲染实现 (TXT 目录规则的编辑、导入、帮助)。
 *
 * 由 LanghuanApp 的 DialogOverlayContent 按 key 分流调用。落库后各页 ScreenModel 订阅的
 * DAO flow 自动回推, 故无需经 overlayResults 回传结果。
 */

// TXT 目录规则编辑 (key="txtTocRuleEdit", payload=规则 id, null=新增)
@Composable
internal fun TxtTocRuleEditDialogContent(overlay: AppOverlay.Dialog, navigator: AppNavigator) {
    val scope = rememberCoroutineScope()
    var rule by remember(overlay.payload) { mutableStateOf<TxtTocRule?>(null) }
    var loaded by remember(overlay.payload) { mutableStateOf(overlay.payload == null) }
    // 对照 app 端 TxtTocRuleEditDialog.initData: 按 id 到达端重查最新 DB 行
    LaunchedEffect(overlay.payload) {
        val id = overlay.payload?.toLongOrNull() ?: return@LaunchedEffect
        rule = withContext(IoDispatcher) { AppDbProviders.get().txtTocRuleDao.get(id) }
        loaded = true
    }
    if (!loaded) return
    TxtTocRuleEditDialog(
        rule = rule,
        // 对照 app 端 TxtTocRuleActivity.saveTxtTocRule → viewModel.save (insert)
        onConfirm = { saved ->
            scope.launch(IoDispatcher) { AppDbProviders.get().txtTocRuleDao.insert(saved) }
        },
        onDismiss = { navigator.dismissOverlay(overlay.key) },
        clipTextProvider = { PlatformCapabilityProviders.get().getClipboardText() },
        clipTextSink = { PlatformCapabilityProviders.get().copyToClipboard(it) },
    )
}

// 帮助文档壳体 (供更新日志复用; 独立帮助弹层已移除, 只在 key="updateLog" 时进入)
@Composable
internal fun HelpDialogContent(
    overlay: AppOverlay.Dialog,
    navigator: AppNavigator,
    fileName: String,
    title: String = stringResource(Res.string.help),
) {
    if (fileName.isEmpty()) {
        LaunchedEffect(overlay.key) { navigator.dismissOverlay(overlay.key) }
        return
    }
    HelpDialog(fileName, title = title) { navigator.dismissOverlay(overlay.key) }
}

/** 升级更新日志 (key="updateLog", 对照原版 upVersion updateLog 分支)。 */
@Composable
internal fun UpdateLogOverlayDialogContent(
    overlay: AppOverlay.Dialog,
    navigator: AppNavigator,
) {
    HelpDialogContent(
        overlay = overlay,
        navigator = navigator,
        fileName = "updateLog",
        title = stringResource(Res.string.update_log),
    )
}

/** 在线导入历史 key (与 app 端 TxtTocRuleActivity 内常量一致)。 */
private const val TxtTocRuleImportRecordKey = "tocRuleUrl"

/** TXT 目录规则在线导入默认 URL (对照 app 端 TxtTocRuleActivity.showImportDialog)。 */
private const val TxtTocRuleDefaultImportUrl =
    "https://gitee.com/fisher52/YueDuJson/raw/master/myTxtChapterRule.json"

/**
 * 本地文件导入 (key="txtTocRuleImportLocal"): 选文件 → 读文本 → 解析比对 → 勾选导入对话框。
 * 对照 app 端 `importDoc.launch { mode = FILE }` + ImportTxtTocRuleDialog(uri)。
 */
@Composable
internal fun TxtTocRuleImportLocalDialogContent(
    overlay: AppOverlay.Dialog,
    navigator: AppNavigator,
) {
    TxtTocRuleImportDialogContent(overlay, navigator, source = null)
}

/**
 * 在线导入 (key="txtTocRuleImportOnline"): 先弹 URL 输入框 (带 ACache 历史), 确认后走同一条解析链。
 * 对照 app 端 showImportDialog() + ImportTxtTocRuleDialog(url)。
 */
@Composable
internal fun TxtTocRuleImportOnlineDialogContent(
    overlay: AppOverlay.Dialog,
    navigator: AppNavigator,
) {
    var url by remember(overlay.key) { mutableStateOf<String?>(null) }
    var dismissRequested by remember(overlay.key) { mutableStateOf(false) }
    if (url == null) {
        if (!dismissRequested) {
            OnlineImportUrlDialog(
                recordKey = TxtTocRuleImportRecordKey,
                defaultUrl = TxtTocRuleDefaultImportUrl,
                onConfirm = { url = it },
                onDismiss = { dismissRequested = true },
            )
        }
        // OnlineImportUrlDialog 确定路径也会先调 onDismiss 再调 onConfirm,
        // 故延到重组后判断 url 是否已填, 只有真取消才关 overlay
        LaunchedEffect(dismissRequested) {
            if (dismissRequested && url == null) navigator.dismissOverlay(overlay.key)
        }
        return
    }
    TxtTocRuleImportDialogContent(overlay, navigator, source = url)
}

/**
 * TXT 目录规则导入链路: [source] 为 null 时先走文件选择器取文本, 否则直接用 URL;
 * 交 [ImportTxtTocRuleViewModelShared] 解析比对, 解析出结果或失败都弹 [ImportItemsDialog]
 * (失败时窗内显示错误)。
 */
@Composable
private fun TxtTocRuleImportDialogContent(
    overlay: AppOverlay.Dialog,
    navigator: AppNavigator,
    source: String?,
) {
    val scope = rememberCoroutineScope()
    val vm = remember(overlay.key, source) { ImportTxtTocRuleViewModelShared(scope) }
    val items = remember(vm) { ImportTxtTocRuleItemsVm(vm) }
    var showDialog by remember(overlay.key, source) { mutableStateOf(false) }
    // 导入失败 / 解析出 0 条的提示文案, 显示在对话框内且不关窗 (对照原版 ImportTxtTocRuleDialog 的 tv_msg)
    var importError by remember(overlay.key, source) { mutableStateOf<String?>(null) }
    val strWrongFormat = stringResource(Res.string.wrong_format)

    LaunchedEffect(vm) {
        launch {
            vm.successState.collect { count ->
                importError = if (count == 0) strWrongFormat else null
                showDialog = true
            }
        }
        launch {
            vm.errorState.collect { err ->
                importError = err
                showDialog = true
            }
        }
        // 文件分支: 平台文件选择器取路径后读文本 (对照 app 端 uri.readText); 取消选择即关闭
        val text = if (source != null) {
            source
        } else {
            val path = withContext(IoDispatcher) {
                PlatformServiceProviders.get().files.pickFile(FileFilter.Text)
            }
            if (path == null) {
                navigator.dismissOverlay(overlay.key)
                return@LaunchedEffect
            }
            withContext(IoDispatcher) { BackupFileOps.readText(path) }
        }
        vm.importSource(text)
    }

    if (!showDialog) return
    ImportItemsDialog(
        title = stringResource(Res.string.import_txt_toc_rule),
        vm = items,
        onDismiss = { navigator.dismissOverlay(overlay.key) },
        onImported = { navigator.dismissOverlay(overlay.key) },
        errorText = importError,
    )
}
