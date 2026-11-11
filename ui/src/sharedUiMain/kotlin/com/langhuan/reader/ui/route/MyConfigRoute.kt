package com.langhuan.reader.ui.route

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.langhuan.reader.ui.compose.component.AppTitleBar
import com.langhuan.reader.ui.main.my.MyConfigContent
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.RouteEntry
import com.langhuan.reader.ui.root.ScreenModelStore
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.my
import org.jetbrains.compose.resources.stringResource

/**
 * 「我的」push 路由入口：顶栏 + 与 tab 共用的 [MyConfigContent]。
 *
 * 页面内容、弹窗与平台回调都在 [MyConfigContent]，这里只补返回按钮。
 */
@Composable
fun MyConfigRoute(
    entry: RouteEntry,
    navigator: AppNavigator,
    screenModelStore: ScreenModelStore,
) {
    Column(Modifier.fillMaxSize()) {
        AppTitleBar(
            title = stringResource(Res.string.my),
            onBack = { navigator.pop() },
        )
        MyConfigContent(navigator = navigator)
    }
}
