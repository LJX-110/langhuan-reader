package com.langhuan.reader.ui.about

import com.langhuan.reader.help.config.LocalConfigShared
import com.langhuan.reader.help.config.PreferenceProviders

/** 保存的版本号存储 key (与 app 端 LocalConfig 的 versionCodeKey 同名)。 */
private const val SAVED_VERSION_CODE_KEY = "appVersionCode"

/**
 * 版本号存储面 (对照 app 端 LocalConfig.versionCode/isFirstOpenApp 语义)。
 *
 * app 端实现包装 LocalConfig (`appVersionCode` 同时供 DefaultData.upVersion 做默认数据
 * 版本推进判断, 必须写回同一处); 桌面/iOS/鸿蒙用 [preferenceAppVersionStore]。
 */
interface AppVersionStore {
    fun getSavedVersionCode(): Long

    fun saveVersionCode(versionCode: Long)

    /** 读取并消费首次打开标志 (读即置 false, 算法见 [LocalConfigShared.isFirstOpen])。 */
    fun consumeFirstOpen(): Boolean
}

/** [AppVersionStore] 的 PreferenceProviders 实现 (桌面/iOS/鸿蒙共用)。 */
fun preferenceAppVersionStore(): AppVersionStore = object : AppVersionStore {
    private val prefs get() = PreferenceProviders.get()

    override fun getSavedVersionCode(): Long = prefs.getLong(SAVED_VERSION_CODE_KEY, 0L)

    override fun saveVersionCode(versionCode: Long) {
        prefs.putLong(SAVED_VERSION_CODE_KEY, versionCode)
    }

    override fun consumeFirstOpen(): Boolean = LocalConfigShared.isFirstOpen(
        getBoolean = prefs::getBoolean,
        putBoolean = prefs::putBoolean,
    )
}

/**
 * 记录本次运行的版本号 (四端共用)。
 *
 * `appVersionCode` 是默认数据补种的版本门, 每次启动都要写回; 同版本运行不重复写。
 */
fun recordAppVersion(currentVersionCode: Long, store: AppVersionStore) {
    if (store.getSavedVersionCode() == currentVersionCode) return
    store.saveVersionCode(currentVersionCode)
    store.consumeFirstOpen()
}
