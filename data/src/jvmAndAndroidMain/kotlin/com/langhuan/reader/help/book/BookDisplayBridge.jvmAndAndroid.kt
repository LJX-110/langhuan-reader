package com.langhuan.reader.help.book

import com.langhuan.reader.utils.ChineseUtils

/**
 * BookDisplayBridge actual (jvmAndAndroidMain)。
 */
actual fun chineseT2S(content: String): String = ChineseUtils.t2s(content)

actual fun chineseS2T(content: String): String = ChineseUtils.s2t(content)
