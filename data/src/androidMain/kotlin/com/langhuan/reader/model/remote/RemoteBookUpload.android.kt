package com.langhuan.reader.model.remote

import android.net.Uri
import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.lib.webdav.WebDav
import com.langhuan.reader.lib.webdav.WebDavException
import com.langhuan.reader.ui.platform.sharedAppContext
import com.langhuan.reader.utils.isContentScheme
import kotlinx.coroutines.Dispatchers.IO
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext

/**
 * 对照原 app 端 `RemoteBookWebDav.upload` + `WebDav.upload(uri)` (WebDavAndroidExt):
 * content scheme 读流成字节后上传, 否则取 `Uri.path` 走本地路径上传。
 */
internal actual suspend fun WebDav.uploadLocalBook(bookUrl: String) {
    if (!bookUrl.isContentScheme()) {
        upload(Uri.parse(bookUrl).path!!)
        return
    }
    runCatching {
        withContext(IO) {
            val resolver = sharedAppContext?.contentResolver
                ?: throw WebDavException("WebDav上传失败\nApplicationContext 未注册")
            val byteArray = resolver.openInputStream(Uri.parse(bookUrl))
                ?.use { it.readBytes() }
                ?: throw WebDavException("WebDav上传失败\n未获取到文件")
            upload(byteArray)
        }
    }.onFailure {
        currentCoroutineContext().ensureActive()
        AppLog.put("WebDav上传失败\n${it.localizedMessage}", it)
        throw WebDavException("WebDav上传失败\n${it.localizedMessage}")
    }
}
