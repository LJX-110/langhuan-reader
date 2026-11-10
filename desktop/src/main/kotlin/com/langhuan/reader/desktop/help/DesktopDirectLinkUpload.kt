package com.langhuan.reader.desktop.help

import com.langhuan.reader.exception.NoStackTraceException
import com.langhuan.reader.help.DefaultDataResourceProviders
import com.langhuan.reader.help.DirectLinkUploadDefaultsProvider
import com.langhuan.reader.help.DirectLinkUploadDefaultsProviders
import com.langhuan.reader.help.DirectLinkUploadJvmPrimitives
import com.langhuan.reader.help.DirectLinkUploadRule
import com.langhuan.reader.help.DirectLinkUploadStoreProvider
import com.langhuan.reader.help.DirectLinkUploadStoreProviders
import com.langhuan.reader.help.ruleFileName
import com.langhuan.reader.help.upLoadToDirectLink
import com.langhuan.reader.utils.GSON
import com.langhuan.reader.utils.fromJsonArray
import com.langhuan.reader.utils.fromJsonObject
import com.langhuan.reader.utils.toJson
import java.util.prefs.Preferences

/**
 * 直链上传 desktop 实现 (与 shared [DirectLinkUploadStoreProvider] / [DirectLinkUploadDefaultsProvider] 配套)。
 *
 * 对照 app 端 [com.langhuan.reader.help.DirectLinkUpload] object, 上传编排下沉
 * [upLoadToDirectLink] (commonMain, 压缩/上传/解析直链四端同一份), 桌面端保留:
 * - [upLoad]: 薄壳注入 JVM 平台原语 ([DirectLinkUploadJvmPrimitives])
 * - [getConfig] / [putConfig]: 不依赖 Android ACache, 改用 [java.util.prefs.Preferences]
 *   (参考 [com.langhuan.reader.desktop.config.DesktopPreferenceProvider]), 配置落用户注册表 (Win) /
 *   ~/.java/.userPrefs (Linux/macOS), 重启仍可读。
 * - [defaultRulesCache]: 不依赖 appCtx.assets, 走 [com.langhuan.reader.help.DefaultDataResourceProviders] 读
 *   composeResources 单一数据源 (`commonMain/composeResources/files/defaultData/`)。
 *
 * 本 object 实现两个 provider 接口, 宿主启动早期通过 [registerDesktopDirectLinkUploadProviders]
 * 注册到 shared, 供 shared 端 (如 BackupShared/RestoreShared) 跨平台访问直链上传配置。
 *
 * # 类型映射 (与 app 端对齐)
 * - app 端 `DirectLinkUpload.Rule` → shared [DirectLinkUploadRule] (直接引用)
 * - app 端 `DirectLinkUpload.ruleFileName` → shared [ruleFileName] (top-level 常量)
 */
object DesktopDirectLinkUpload : DirectLinkUploadStoreProvider, DirectLinkUploadDefaultsProvider {

    // 配置存储: java.util.prefs.Preferences (参考 DesktopPreferenceProvider)
    // 落用户注册表 (Win) / ~/.java/.userPrefs (Linux/macOS), 重启仍可读
    private val prefs: Preferences =
        Preferences.userNodeForPackage(DesktopDirectLinkUpload::class.java)

    @Throws(NoStackTraceException::class)
    suspend fun upLoad(
        fileName: String,
        file: Any,
        contentType: String,
        rule: DirectLinkUploadRule = getRule()
    ): String {
        return upLoadToDirectLink(
            DirectLinkUploadJvmPrimitives,
            fileName, file, contentType, rule
        )
    }

    // 命名为 defaultRulesCache 避免与 override fun getDefaultRules() 的 JVM 签名冲突
    // (与 app 端命名一致)
    private val defaultRulesCache: List<DirectLinkUploadRule> by lazy {
        // 走 DefaultDataResourceProviders 单一数据源
        // (composeResources/files/defaultData/directLinkUpload.json)
        val json = DefaultDataResourceProviders.get().readResource("directLinkUpload.json")
        GSON.fromJsonArray<DirectLinkUploadRule>(json).getOrThrow()
    }

    fun getRule(): DirectLinkUploadRule {
        return getConfig() ?: defaultRulesCache[0]
    }

    override fun getConfig(): DirectLinkUploadRule? {
        val json = prefs.get(ruleFileName, null) ?: return null
        return GSON.fromJsonObject<DirectLinkUploadRule>(json).getOrNull()
    }

    override fun putConfig(rule: DirectLinkUploadRule) {
        prefs.put(ruleFileName, GSON.toJson(rule))
    }

    override fun getDefaultRules(): List<DirectLinkUploadRule> = defaultRulesCache

}

/**
 * 桌面端宿主启动早期注册 [DirectLinkUploadStoreProvider] + [DirectLinkUploadDefaultsProvider]。
 *
 * [DesktopDirectLinkUpload] object 已实现这两个接口, 注册后 shared/commonMain 内可通过
 * [DirectLinkUploadStoreProviders.get] / [DirectLinkUploadDefaultsProviders.get]
 * 跨平台访问直链上传配置 (如 BackupShared/RestoreShared 备份恢复 directLinkUploadRule.json)。
 *
 * 调用时机: desktop main 入口早期, 在 [com.langhuan.reader.desktop.config.registerDesktopConfig]
 * (Preferences 就绪) 之后, 任何 shared 模块备份/恢复之前。
 *
 * 模式参考 app 端 [com.langhuan.reader.help.registerAndroidDirectLinkUploadProviders] /
 * [com.langhuan.reader.desktop.help.config.registerDesktopPasswordProvider]。
 */
fun registerDesktopDirectLinkUploadProviders() {
    DirectLinkUploadStoreProviders.register(DesktopDirectLinkUpload)
    DirectLinkUploadDefaultsProviders.register(DesktopDirectLinkUpload)
}
