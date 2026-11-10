@file:OptIn(org.jetbrains.compose.resources.InternalResourceApi::class)

package com.langhuan.reader.ui.compose.platform

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.toComposeImageBitmap
import com.langhuan.reader.utils.File
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.painterResource
import platform.Foundation.NSBundle

/**
 * iOS actual: 只读主图标 AppIcon.png (不再提供交替图标)。
 * 资源缺失时返回 null (与 Android 端资源缺失兜底一致)。
 */
@Composable
actual fun rememberLauncherIconPainters(iconValues: List<String>): List<Painter?> {
    return remember(iconValues) {
        iconValues.map { value ->
            if (value != "ic_launcher") return@map null
            val path = NSBundle.mainBundle.pathForResource("AppIcon", "png") ?: return@map null
            runCatching {
                BitmapPainter(
                    org.jetbrains.skia.Image.makeFromEncoded(File(path).readBytes())
                        .toComposeImageBitmap()
                )
            }.getOrNull()
        }
    }
}
