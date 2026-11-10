package com.langhuan.reader.desktop.help.ui

import com.langhuan.reader.constant.AppConst
import com.langhuan.reader.help.UserAgentProvider
import com.langhuan.reader.help.UserAgentProviders

/**
 * [UserAgentProvider] 桌面端实现。
 *
 * desktop 无 WebView, 返回桌面 Chrome UA 替代 app 端 `WebSettings.getDefaultUserAgent`。
 * 在 main 入口经 [registerDesktopUserAgentProvider] 注册到 [UserAgentProviders]。
 */
object DesktopUserAgentProviderImpl : UserAgentProvider {

    // 合并后接口要求 get(); 本对象经 register() 注册进 WebView UA 槽位,
    // 容器 get() (HTTP 语义) 不会走到这里, 直接复用 WebView UA 作为兜底。
    override fun get(): String = getWebViewUA()

    override fun getWebViewUA(): String = AppConst.DEFAULT_USER_AGENT
}

/** 桌面端 main 入口早期注册一次, 任何 JsExtensionsCommon.getWebViewUA 调用之前。 */
fun registerDesktopUserAgentProvider() {
    UserAgentProviders.register(DesktopUserAgentProviderImpl)
}
