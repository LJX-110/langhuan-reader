package com.langhuan.reader.ui.compose.platform

import androidx.compose.ui.graphics.Color
import com.langhuan.reader.App
import com.langhuan.reader.constant.EventBus
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.help.config.AppConfig
import com.langhuan.reader.help.config.ThemeConfig
import com.langhuan.reader.lib.theme.ThemeStore
import com.langhuan.reader.utils.FlowBus
import com.langhuan.reader.utils.getPrefInt
import com.langhuan.reader.utils.postEvent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * Android 端 Provider 实现：包装 app 模块的 ThemeStore / AppConfig / FlowBus +
 * ThemeConfig.curBgImagePath，作为 [com.langhuan.reader.ui.compose.theme.AppTheme]（已下沉
 * commonMain）在 Android 端运行时的依赖注入源。
 *
 * 设计：shared androidMain 不能反向 import app 模块类（app 依赖 shared），故 actual
 * 实现下沉到 app 模块；在 Compose 入口用 CompositionLocalProvider 注入到
 * LocalThemeStoreProvider / LocalAppConfigProvider / LocalEventBusProvider。
 *
 * 颜色 Int→Color 转换在此完成，commonMain 侧消费 Color 不再依赖 Android ColorInt。
 */

/** 包装 [ThemeStore] 颜色字段 + [ThemeConfig.curBgImagePath] */
class AndroidThemeStoreProvider : ThemeStoreProvider {
    override val accentColor: Color
        get() = Color(ThemeStore.accentColor)
    override val backgroundColor: Color
        get() = Color(ThemeStore.backgroundColor)
    override val bottomBackground: Color
        get() = Color(ThemeStore.bottomBackground)
    override val statusBarColor: Color
        get() = Color(ThemeStore.statusBarColor)
    override val navigationBarColor: Color
        get() = Color(ThemeStore.navigationBarColor)
    override val bgImagePath: String?
        get() = ThemeConfig.curBgImagePath

    /** 按日/夜读背景图模糊键 (对照原版 bgImageBlurring, 页面级壁纸层共用) */
    override val bgImageBlur: Int
        get() = App.instance.getPrefInt(
            if (AppConfig.isNightTheme) PreferKey.bgImageNBlurring else PreferKey.bgImageBlurring,
            0,
        )
}

/** 包装 [AppConfig.isEInkMode] */
class AndroidAppConfigProvider : AppConfigProvider {
    override val isEInkMode: Boolean
        get() = AppConfig.isEInkMode
    override val isNightTheme: Boolean
        get() = AppConfig.isNightTheme
}

/** 包装 [FlowBus.with]`[EventBus.RECREATE]`，把 SharedFlow<Any> 投影为 Flow<Unit> */
class AndroidEventBusProvider : EventBusProvider {
    override val recreateEvent: Flow<Unit> =
        FlowBus.with(EventBus.RECREATE).map { Unit }

    /** 包装 postEvent(EventBus.RECREATE, "") */
    override fun emitRecreate() {
        postEvent(EventBus.RECREATE, "")
    }
}

