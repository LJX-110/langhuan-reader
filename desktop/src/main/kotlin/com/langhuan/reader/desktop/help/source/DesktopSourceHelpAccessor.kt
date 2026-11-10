package com.langhuan.reader.desktop.help.source

import com.langhuan.reader.data.entities.BookSource
import com.langhuan.reader.help.AppCacheManager
import com.langhuan.reader.help.config.SourceConfig
import com.langhuan.reader.help.source.SourceHelpAccessor
import com.langhuan.reader.model.ActiveReadBookRegistry
import com.langhuan.reader.model.AudioPlayShared

/**
 * 桌面端 [SourceHelpAccessor] 实现, 供 shared commonMain 中下沉的
 * SourceHelp.saveSource / deleteBookSource / deleteBookSourcesByKeys 通过
 * [com.langhuan.reader.help.source.SourceHelpAccessors] 间接调用, 避免未注册时
 * `SourceHelpAccessors.get()` 抛 IllegalStateException 导致书源删除流程被
 * runCatching 静默吞掉、副作用不执行。
 *
 * # 注册时机
 * desktop `main()` 中在 `AppDbProviders.register(DesktopAppDbAccessor())` 之后注册
 * (本文件依赖 SourceConfig + AppCacheManager, 两者已下沉 commonMain;
 * 顺序紧跟 AppDbAccessor 便于维护), 见 [com.langhuan.reader.desktop.Main]。
 *
 * # 与 app 端 [com.langhuan.reader.help.source.SourceHelpAccessorImpl] 区别
 * - app 端 `getCachedReadingBookSource` 走 `ReadBook.bookSource`, 桌面端走
 *   [com.langhuan.reader.model.ActiveReadBookRegistry] (阅读页 attach 的活动 ReadBookShared)
 * - app 端 `getCachedAudioBookSource` 走 `AudioPlay.bookSource`, 桌面端走已下沉的 AudioPlayShared
 * - `onBookSourceDeleted` / `onBookSourcesDeleted` 走 `SourceConfig.removeSource(s)`
 *   + `AppCacheManager.clearSourceVariables()` 清缓存副作用
 *   (SourceConfig / AppCacheManager 已下沉 commonMain, 桌面端可直接调用, 行为与 app 端等价)
 *
 * 模式参考 app 端 SourceHelpAccessorImpl 的实现段。
 */
class DesktopSourceHelpAccessor : SourceHelpAccessor {

    /**
     * 对应 app 端 `ReadBook.bookSource?.takeIf { it.bookSourceUrl == key }`。
     * 桌面端无 ReadBook 单例, 走 [ActiveReadBookRegistry.current] (阅读页 attach 的活动状态)。
     */
    override fun getCachedReadingBookSource(key: String?): BookSource? =
        ActiveReadBookRegistry.current?.bookSource?.value?.takeIf { it.bookSourceUrl == key }

    /** 对应 app 端 `AudioPlay.bookSource?.takeIf { it.bookSourceUrl == key }` (AudioPlayShared 已下沉)。 */
    override fun getCachedAudioBookSource(key: String?): BookSource? =
        AudioPlayShared.bookSource?.takeIf { it.bookSourceUrl == key }

    /**
     * 对应原 app 端 `SourceConfig.removeSource(key)` + `AppCacheManager.clearSourceVariables()`。
     *
     * SourceConfig 已下沉 commonMain (走 PreferenceProviders, 桌面端 java.util.prefs),
     * AppCacheManager 已下沉 commonMain (内存 LruCache), 直接调用, 行为与 app 端等价。
     */
    override fun onBookSourceDeleted(key: String) {
        SourceConfig.removeSource(key)
        AppCacheManager.clearSourceVariables()
    }

    /**
     * 对应原 app 端 `SourceConfig.removeSources(keys)` + `AppCacheManager.clearSourceVariables()`。
     *
     * 同 [onBookSourceDeleted], 批量版本。
     */
    override fun onBookSourcesDeleted(keys: List<String>) {
        SourceConfig.removeSources(keys)
        AppCacheManager.clearSourceVariables()
    }
}
