package com.langhuan.reader.ui.compose.platform

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.colorResource
import com.langhuan.reader.ui.compose.theme.LocalAppColors
import java.util.concurrent.ConcurrentHashMap

/**
 * 资源名→id 缓存: [android.content.res.Resources.getIdentifier] 是反射式 O(n) 扫资源表,
 * 列表滚动时每个可见项的 rememberColor 都会触发, 累计开销可观。
 * 进程级缓存, 首次 miss 才查, 后续 O(1) 命中 (跨 Composable 实例共享)。
 */
private val resourceIdCache = ConcurrentHashMap<String, Int>()

@Suppress("DiscouragedApi")
private fun resolveResourceId(context: android.content.Context, name: String, type: String): Int {
    val cacheKey = "$type:$name"
    return resourceIdCache.getOrPut(cacheKey) {
        context.resources.getIdentifier(name, type, context.packageName)
    }
}

@Composable
actual fun rememberColor(key: String): Color {
    val context = LocalContext.current
    val id = resolveResourceId(context, key, "color")
    if (id != 0) return colorResource(id)
    // 资源缺失 (getIdentifier 返回 0, 如被 lint 清理删除的颜色) 时回退共享色板
    // (ColorPalette.kt), 避免 colorResource(0) 抛 Resources$NotFoundException;
    // 仍存在的资源键 (background/arco_* 等) 不受影响, values-night 与动态主题照常走资源。
    return resolvePaletteColor(key, LocalAppColors.current.isDark)
}

