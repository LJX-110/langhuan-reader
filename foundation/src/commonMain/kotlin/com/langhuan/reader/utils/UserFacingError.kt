package com.langhuan.reader.utils

import com.langhuan.reader.ui.compose.platform.syncGetString

/**
 * 把异常翻译成可直接展示给用户的原因。
 *
 * 网络库与解析器抛出的 message 多为英文原文 (Failed to connect / timeout / Unexpected JSON …),
 * 直接 toast 会让中文界面冒出英文。这里只按常见失败归因到固定文案, 原始 message 仍进日志。
 *
 * 文案缺失时 [syncGetString] 返回 key 名, 不会崩。
 */
fun Throwable.toUserFacingReason(): String {
    val raw = "${this::class.simpleName.orEmpty()} ${message.orEmpty()}".lowercase()
    val key = when {
        raw.contains("timeout") || raw.contains("timed out") -> "error_reason_timeout"
        raw.contains("unknownhost") || raw.contains("unable to resolve host") ||
            raw.contains("no address associated") || raw.contains("nodename nor servname") -> "error_reason_network"
        raw.contains("connect") || raw.contains("refused") ||
            raw.contains("unreachable") || raw.contains("econnreset") || raw.contains("broken pipe") -> "error_reason_connect"
        raw.contains("json") || raw.contains("parse") ||
            raw.contains("syntax") || raw.contains("deserialize") -> "error_reason_parse"
        else -> "error_reason_unknown"
    }
    return syncGetString(key)
}
