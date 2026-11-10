package com.langhuan.reader.web.utils

import com.langhuan.reader.web.utils.WebStrings
import com.langhuan.reader.web.utils.WebStringsProviders

/**
 * [WebStrings] 的桌面 JVM actual 实现。
 *
 * 桌面端暂用硬编码中文 (与 app 端 values-zh/strings.xml `cannot_empty` 文案一致),
 * 后续接入 i18n 资源 (compose.components.resources) 后替换为资源读取。
 */
class DesktopWebStrings : WebStrings {

    override val cannotEmpty: String = "输入不能为空"
}

/**
 * 桌面宿主启动早期注册 [WebStrings] 的 actual 实现。
 *
 * 模式参考 `registerDesktopServiceLauncher`。
 */
fun registerDesktopWebStrings() {
    WebStringsProviders.register(DesktopWebStrings())
}
