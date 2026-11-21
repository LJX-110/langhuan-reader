package com.langhuan.reader.ui.compose.platform

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue

/**
 * 外观刷新令牌：主题色 / 背景图等直读持久层的值不经过 Compose State，
 * 写入后调用 [bump]，让 AppTheme、壁纸层与底栏在下一帧重读。
 *
 * 与 EventBus.RECREATE 并存：事件负责跨 Activity/桌面窗口重建，本令牌保证同一
 * 组合内的设置页、弹窗与底栏不必等重建或手动刷新。
 */
object AppearanceRefresh {
    var version by mutableIntStateOf(0)
        private set

    fun bump() {
        version++
    }
}