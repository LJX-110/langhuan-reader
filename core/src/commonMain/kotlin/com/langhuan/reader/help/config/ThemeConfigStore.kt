package com.langhuan.reader.help.config

import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.help.file.AppFilesDirs
import com.langhuan.reader.help.storage.BackupFileOps
import com.langhuan.reader.utils.ColorUtils
import com.langhuan.reader.utils.GSON
import com.langhuan.reader.utils.fromJsonArray
import com.langhuan.reader.utils.toJson
import kotlinx.atomicfu.locks.SynchronizedObject
import kotlinx.atomicfu.locks.synchronized

/**
 * themeConfig.json 的唯一读写实现 (下沉自 app 端 `ThemeConfig` 的
 * configFilePath / save / getConfigsFromDisk / validateConfig)。
 *
 * app 端 [com.langhuan.reader.help.config.ThemeConfig] 与 [FileThemeConfigProvider] 共用本对象,
 * 保证四端持久化路径/格式完全一致 (备份恢复互读)。
 */
object ThemeConfigStore {

    /** 主题修改的库级互斥: 包住“读取当前列表→合并→保存→发布”整个过程。 */
    private val modifyLock = SynchronizedObject()

    fun <T> withLock(block: () -> T): T = synchronized(modifyLock) { block() }

    const val configFileName = "themeConfig.json"

    /** 对照 app 端 `FileUtils.getPath(appCtx.filesDir, configFileName)` */
    val configFilePath: String
        get() = AppFilesDirs.get().filesDir + BackupFileOps.separator + configFileName

    /** 对照 app 端 getConfigsFromDisk: 文件不存在/解析失败返回空列表 (自带库锁) */
    fun load(): List<ThemeConfigData> = withLock { loadUnlocked() }

    /**
     * 调用方已持有 [withLock] 时使用; 读取失败保持原版空列表合同。
     *
     * 旧版主题文件没有 secondaryColor 字段，读入后一次性以强调色补齐并写回，
     * 之后各处按非空值使用，不再做运行期兜底。
     */
    fun loadUnlocked(): List<ThemeConfigData> = runCatching {
        val loaded = if (BackupFileOps.exists(configFilePath)) {
            GSON.fromJsonArray<ThemeConfigData>(BackupFileOps.readText(configFilePath)).getOrThrow()
        } else {
            emptyList()
        }
        var migrated = false
        val configs = loaded.map { config ->
            // Gson 对缺失字段给 null（不是默认值），这里一并按空处理
            if (config.secondaryColor.isNullOrBlank()) {
                migrated = true
                config.copy(secondaryColor = config.accentColor)
            } else {
                config
            }
        }
        if (migrated) {
            runCatching { saveOrThrowUnlocked(configs) }
                .onFailure { AppLog.putDebug("补齐主题辅助色失败\n${it.message}", it) }
        }
        configs
    }.getOrElse { e ->
        AppLog.putDebug("读取 themeConfig.json 出错\n${e.message}", e)
        emptyList()
    }

    /**
     * 整份原子替换写入 themeConfig.json。
     *
     * 写入失败抛出原始异常 (磁盘/授权/容量), 目标文件保持原内容; 不再吞成 Boolean。
     */
    fun save(configs: List<ThemeConfigData>) {
        withLock { saveOrThrowUnlocked(configs) }
    }

    /** 保存成功返回; 失败抛原始异常 (磁盘/授权/容量), 不丢弃原因。调用方已持有 [withLock]。 */
    fun saveOrThrowUnlocked(configs: List<ThemeConfigData>) {
        BackupFileOps.writeText(configFilePath, GSON.toJson(configs))
    }

    /** 锁外的直接保存入口: 保留原始异常。 */
    fun saveOrThrow(configs: List<ThemeConfigData>) = withLock {
        saveOrThrowUnlocked(configs)
    }

    /** 对照 app 端 validateConfig: 各色值按主题域合同可解析才有效 */
    fun validate(config: ThemeConfigData): Boolean = runCatching {
        ColorUtils.parseThemeColor(config.primaryColor)
        ColorUtils.parseThemeColor(config.accentColor)
        if (!config.secondaryColor.isNullOrBlank()) {
            ColorUtils.parseThemeColor(config.secondaryColor)
        }
        ColorUtils.parseThemeColor(config.backgroundColor)
        ColorUtils.parseThemeColor(config.bottomBackground)
    }.isSuccess
}
