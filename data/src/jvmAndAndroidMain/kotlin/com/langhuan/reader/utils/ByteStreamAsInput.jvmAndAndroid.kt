package com.langhuan.reader.utils

import okhttp3.ResponseBody
import com.langhuan.reader.utils.InputStream

/**
 * KmpResponseBody → InputStream 转换 (data 层专用, 见 commonMain ByteStreamAsInput.kt expect)。
 * jvm/android: KmpResponseBody 经 KmpHttpTypes actual typealias 等价 okhttp3.ResponseBody。
 */
actual fun Any.byteStreamAsInput(): InputStream = (this as ResponseBody).byteStream()
