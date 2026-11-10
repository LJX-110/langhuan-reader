package com.langhuan.reader.ui.route

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import com.langhuan.reader.data.entities.BookSource
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppOverlay
import com.langhuan.reader.ui.root.RouteEntry
import com.langhuan.reader.ui.root.ScreenModelStore
import com.langhuan.reader.ui.toolbox.SourceToolboxScreen
import com.langhuan.reader.ui.toolbox.SourceToolboxScreenModel
import com.langhuan.reader.ui.toolbox.SourceToolboxUiActions
import com.langhuan.reader.ui.toolbox.ToolboxRuleMode
import com.langhuan.reader.ui.toolbox.ToolboxStage
import com.langhuan.reader.ui.toolbox.ToolboxUiEvent
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.toolbox_no_response
import com.langhuan.reader.ui.generated.resources.toolbox_source_cleared
import org.jetbrains.compose.resources.stringResource

@Composable
fun SourceToolboxRoute(
    entry: RouteEntry,
    navigator: AppNavigator,
    screenModelStore: ScreenModelStore,
) {
    val noResponseText = stringResource(Res.string.toolbox_no_response)
    val sourceClearedText = stringResource(Res.string.toolbox_source_cleared)

    val screenModel = screenModelStore.getOrCreateTyped(entry) {
        SourceToolboxScreenModel(
            toast = { Toasters.get().toast(it) },
            noResponseText = noResponseText,
            sourceClearedText = sourceClearedText,
        )
    }
    val state by screenModel.uiState.collectAsState()

    val actions = remember(screenModel, navigator) {
        object : SourceToolboxUiActions {
            override fun onBack() {
                navigator.pop()
            }

            override fun onShowKeyboardConfig() {
                navigator.showOverlay(AppOverlay.Dialog("keyboardAssistsConfig"))
            }

            override fun onSourceSelected(source: BookSource) {
                screenModel.dispatch(ToolboxUiEvent.SelectSource(source))
            }

            override fun onClearSource() {
                screenModel.dispatch(ToolboxUiEvent.ClearSource)
            }

            override fun onStageChange(stage: ToolboxStage) {
                screenModel.dispatch(ToolboxUiEvent.StageChange(stage))
            }

            override fun onUrlChange(text: String) {
                screenModel.dispatch(ToolboxUiEvent.UrlChange(text))
            }

            override fun onInputChange(text: String) {
                screenModel.dispatch(ToolboxUiEvent.InputChange(text))
            }

            override fun onRequest() {
                screenModel.dispatch(ToolboxUiEvent.Request)
            }

            override fun onRunRule(mode: ToolboxRuleMode) {
                screenModel.dispatch(ToolboxUiEvent.RunRule(mode))
            }

            override fun onRunJs() {
                screenModel.dispatch(ToolboxUiEvent.RunJs)
            }

            override fun onTreeMode(on: Boolean) {
                screenModel.dispatch(ToolboxUiEvent.ResTreeMode(on))
            }
        }
    }

    SourceToolboxScreen(state = state, actions = actions)
}
