package com.langhuan.reader.ui.about

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.langhuan.reader.ui.compose.preference.PreferenceScreen
import com.langhuan.reader.ui.compose.preference.preference
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.check_update
import org.jetbrains.compose.resources.stringResource

/**
 * 关于页条目：只保留「检查更新」，版本号在顶部卡片里点按复制。
 */
@Composable
fun AboutScreen(
    state: AboutUiState,
    actions: AboutUiActions,
    modifier: Modifier = Modifier,
) {
    val titleCheckUpdate = stringResource(Res.string.check_update)

    PreferenceScreen(modifier = modifier) {
        if (state.showCheckUpdate) {
            preference(
                title = titleCheckUpdate,
                enabled = !state.checkingUpdate,
                onClick = { actions.onCheckUpdate() },
            )
        }
    }
}
