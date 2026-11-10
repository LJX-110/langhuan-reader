package com.langhuan.reader

import com.langhuan.reader.ui.association.LanghuanDeepLinkHandler

/**
 * iOS 端 langhuan:// deep link 入口 (Swift 侧调用: `LanghuanDeepLinkIosKt.handleLanghuanDeepLink(url:)`)。
 *
 * # 调用链
 *
 * ```
 * 系统打开 langhuan://import/bookSource?src=... (Info.plist CFBundleURLTypes 注册, 见 project.yml)
 *   └── iOSApp.swift WindowGroup.onOpenURL { url in ... }
 *         └── 本函数 → commonMain LanghuanDeepLinkHandler.handle(url)
 *               └── LanghuanDeepLink.parse 解析 (对照原版 FileAssociationFragment 的 scheme 分发)
 *                     └── LanghuanDeepLinkHandler.pending (StateFlow) 记录待导入请求
 * ```
 *
 * 消费侧: [com.langhuan.reader.MainViewController] 尾部挂 [com.langhuan.reader.ui.association.DeepLinkImportHost],
 * 空闲时接纳 `LanghuanDeepLinkHandler.pending` 的请求后按类型走 ImportXxxViewModelShared + ImportItemsDialog
 * (与手动网络导入同链), 完成/取消均按请求 id 结算 ([LanghuanDeepLinkHandler.consume])。
 * 冷启动先投递后组合也不丢 (pending 是 StateFlow)。
 *
 * @return true=已识别并记录; false=非 langhuan/yuedu scheme 或缺 src 参数 (调用方可透传给其他 handler)
 */
fun handleLanghuanDeepLink(url: String): Boolean = LanghuanDeepLinkHandler.handle(url)
