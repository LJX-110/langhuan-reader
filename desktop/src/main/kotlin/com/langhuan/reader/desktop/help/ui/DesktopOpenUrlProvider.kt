package com.langhuan.reader.desktop.help.ui

import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.help.ui.OpenUrlProvider
import com.langhuan.reader.help.ui.OpenUrlProviders
import com.langhuan.reader.utils.browseUrl
import com.langhuan.reader.desktop.ui.DesktopDialogRequest
import com.langhuan.reader.desktop.ui.DesktopDialogs

/**
 * [OpenUrlProvider] 桌面端实现。
 *
 * 对照 app 端 `OpenUrlConfirmDialog.display`: 书源请求跳转外部链接/程序时先弹确认框
 * (含禁用/删除该源的出口), 用户确认后才交给系统默认浏览器, 防止恶意书源静默拉起外部程序。
 * 弹窗走命令式宿主 [DesktopDialogs] (由 Compose 根上的 DesktopDialogHost 消费)。
 */
object DesktopOpenUrlProviderImpl : OpenUrlProvider {

    override fun openUrl(
        url: String,
        mimeType: String?,
        sourceKey: String?,
        sourceTag: String?,
        sourceType: Int
    ) {
        DesktopDialogs.show(
            DesktopDialogRequest.OpenUrlConfirm(
                url = url,
                sourceKey = sourceKey,
                sourceName = sourceTag,
                sourceType = sourceType,
                onConfirm = { doOpenUrl(url) },
            )
        )
    }

    /** 用户确认后真正跳转 (桌面端无 Intent/mimeType 概念, 统一交给系统默认程序)。 */
    private fun doOpenUrl(url: String) {
        // 失败不再静默: 之前异常只写 AppLog, 用户看不到任何反馈 (书源 URL 未编码时
        // 单参 URI 构造抛 URISyntaxException, 表现就是"点了没反应")
        if (!browseUrl(url)) {
            runCatching {
                Toasters.get().toastLong("无法打开链接: $url")
            }
            AppLog.put("打开链接失败: $url")
        }
    }
}

/** 桌面端 main 入口早期注册一次, 任何 JsExtensionsCommon.openUrl 调用之前。 */
fun registerDesktopOpenUrlProvider() {
    OpenUrlProviders.register(DesktopOpenUrlProviderImpl)
}
