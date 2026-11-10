package com.langhuan.reader.ui.route

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import com.langhuan.reader.ui.replace.ReplaceEditScreen
import com.langhuan.reader.ui.replace.edit.ReplaceEditViewModelShared
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppOverlay
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.root.RouteEntry
import com.langhuan.reader.ui.root.RouteResultPayload
import com.langhuan.reader.ui.root.ScreenModelStore
import com.langhuan.reader.utils.GSON
import com.langhuan.reader.utils.toJson
import kotlinx.coroutines.flow.MutableSharedFlow

/**
 * 替换规则编辑 shared 路由入口。
 *
 * [ReplaceEditViewModelShared] 非 [com.langhuan.reader.ui.root.ScreenModel] (组合委托模式,
 * scope/clipTextProvider 由宿主注入), 故用 [remember] 而非 [ScreenModelStore.getOrCreateTyped]。
 * 剪贴板通过 [PlatformCapabilityProviders] 访问。
 * 键盘辅助条由 Screen 内部共享 [com.langhuan.reader.ui.compose.component.code.KeyboardToolbar]
 * 直接渲染, 与 [com.langhuan.reader.ui.route.BookSourceEditRoute] 一致 (Android 15+ edge-to-edge
 * ime 避让在根, navbar 由 Screen 内滚动容器 contentPadding 承担)。
 */
@Composable
fun ReplaceEditRoute(
    entry: RouteEntry,
    navigator: AppNavigator,
    screenModelStore: ScreenModelStore,
) {
    val route = entry.route as AppRoute.ReplaceEdit
    val scope = rememberCoroutineScope()
    // 剪贴板走平台能力注入 (替代 app 端 getClipText/sendToClip)
    val clipTextProvider: () -> String? = {
        PlatformCapabilityProviders.get().getClipboardText()
    }
    val viewModel = remember(route.ruleId, scope) {
        ReplaceEditViewModelShared(scope = scope, clipTextProvider = clipTextProvider)
    }

    // 加载规则 (id > 0 编辑已有, id <= 0 新增模板), 完成后 Screen 用 collectAsState 触发回填
    // pattern/isRegex/scope 由阅读页/替换管理页传入 (对照 app 端 startIntent 4 参数)
    LaunchedEffect(route.ruleId) {
        viewModel.initData(
            id = route.ruleId,
            pattern = route.pattern,
            isRegex = route.isRegex,
            scope = route.scope,
        ) { }
    }

    // 回到栈顶 (如从其它页面返回) 时重新请求根节点持焦: 页面全程留在 Composition,
    // 进入时的 requestFocus 只在首次组合执行, 返回后焦点已空, 需重新请求保证 ESC 可用
    val backStack by navigator.backStack.collectAsState()
    val isTopEntry = backStack.lastOrNull()?.id == entry.id
    val refocusSignal = remember { MutableSharedFlow<Unit>(extraBufferCapacity = 1) }
    LaunchedEffect(isTopEntry) {
        if (isTopEntry) refocusSignal.tryEmit(Unit)
    }

    ReplaceEditScreen(
        viewModel = viewModel,
        onBack = { navigator.pop() },
        onSaved = { navigator.pop(RouteResultPayload.Ok) },
        onCopyRule = { rule ->
            PlatformCapabilityProviders.get().copyToClipboard(GSON.toJson(rule))
        },
        onPasteRule = { success ->
            viewModel.pasteRule(success)
        },
        requestFocusSignal = refocusSignal,
        // 键盘辅助键条 ⚙️ (对照原版 showDialogFragment<KeyboardAssistsConfig>)
        onShowKeyboardConfig = {
            navigator.showOverlay(AppOverlay.Dialog("keyboardAssistsConfig"))
        },
    )
}
