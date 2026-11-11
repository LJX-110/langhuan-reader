package com.langhuan.reader.ui.about

import com.langhuan.reader.ui.root.ScreenModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

// ===== state / actions =====

/**
 * 关于页 UI 状态 (immutable)。
 *
 * @param appVersion 版本号原文（点按复制的内容；取不到版本号时为空串）
 * @param showCheckUpdate 是否显示「检查更新」入口（未接入更新能力的端隐藏）
 * @param checkingUpdate 正在检查更新（入口置灰）
 */
data class AboutUiState(
    val appVersion: String = "",
    val showCheckUpdate: Boolean = true,
    val checkingUpdate: Boolean = false,
)

/**
 * 关于页用户交互回调。
 *
 * - [onCopyVersion]: 复制当前版本号
 * - [onCheckUpdate]: 检查更新
 */
interface AboutUiActions {
    fun onCopyVersion()
    fun onCheckUpdate()
}

// ===== ScreenModel =====

/**
 * 关于页 shared ScreenModel: 托管 [AboutUiState]。
 *
 * 平台资源（版本号）由宿主在 Composition 时调用 [updateState] 推入。
 */
class AboutScreenModel : ScreenModel {

    private val _state = MutableStateFlow(AboutUiState())
    val state: StateFlow<AboutUiState> = _state.asStateFlow()

    fun updateState(state: AboutUiState) {
        _state.value = state
    }

    /**
     * 检查更新: 四端同一条链 ([checkUpdateAndPrompt]), 进行中置灰入口
     * (对照原版 AppUpdate.check 的 WaitDialog: 本端用条目置灰代替转圈弹窗)。
     */
    suspend fun checkUpdate(latestText: String, failedLabel: String) {
        if (_state.value.checkingUpdate) return
        _state.value = _state.value.copy(checkingUpdate = true)
        try {
            checkUpdateAndPrompt(silent = false, latestText = latestText, failedLabel = failedLabel)
        } finally {
            _state.value = _state.value.copy(checkingUpdate = false)
        }
    }
}
