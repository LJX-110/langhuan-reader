package com.langhuan.reader.ui.compose.platform

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.input.key.Key

/**
 * 音量键翻页快捷键 (2026-08 用户拍板: TRIGGER 长按连翻, 不放行系统音量)。
 *
 * TRIGGER 策略: 系统 repeat (长按) 每次触发; 抬起由 [dispatchShortcut] KeyUp 分支消费。
 */
val volumePageTurnKeys = listOf(
    AppShortcut(Key.VolumeUp, repeatPolicy = KeyRepeatPolicy.TRIGGER),
    AppShortcut(Key.VolumeDown, repeatPolicy = KeyRepeatPolicy.TRIGGER),
)

/**
 * 音量键翻页完整接线 (ReaderRoute 使用): TRIGGER 策略 + 200ms 节流连翻。
 *
 * - 单击音量键 = 翻页 (首次立即触发, leading 语义)
 * - 长按 (repeat 每次触发) 经 [PageTurnThrottle] 200ms 节流 → 约 5 页/秒, 避免连翻过快
 * - 快速连按 200ms 内合并/忽略
 *
 * @param enabled 生效条件 (由调用方提供: 非栈顶路由不响应; 另加菜单守卫, 对照原版
 *        menuLayoutIsVisible; 恒生效无开关)
 * @param throttle 节流窗口; 调用方传入本页翻页共用实例 (方向键/自定义键/音量键同窗口,
 *        对照原版小说 nextPageDebounce 由各键共用同一实例)
 * @param onTurnPage 翻页回调 (volumeUp = true → VolumeUp/上一页, false → VolumeDown/下一页),
 *        调用方完成方向映射与翻页执行
 */
@Composable
fun VolumeKeyPageTurnHandler(
    enabled: () -> Boolean,
    throttle: PageTurnThrottle = remember { PageTurnThrottle() },
    onTurnPage: (volumeUp: Boolean) -> Unit,
) {
    AppShortcutHandler(
        shortcuts = volumePageTurnKeys,
        enabled = enabled,
    ) { shortcut ->
        throttle.tryTurn {
            onTurnPage(shortcut.key == Key.VolumeUp)
        }
    }
}
