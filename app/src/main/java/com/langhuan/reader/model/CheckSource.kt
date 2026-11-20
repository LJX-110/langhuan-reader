package com.langhuan.reader.model

import android.content.Context
import com.langhuan.reader.constant.IntentAction
import com.langhuan.reader.data.entities.BookSourcePart
import com.langhuan.reader.help.IntentData
import com.langhuan.reader.service.CheckSourceService
import com.langhuan.reader.utils.startService

/**
 * 书源校验入口 (app 端薄壳)。
 *
 * # 下沉说明
 *
 * 配置状态 (keyword/timeout/checkSearch/checkDiscovery/checkInfo/checkCategory/checkContent)
 * + `putConfig()` 已下沉到 shared commonMain [CheckSourceShared], 本 object 仅保留
 * var/get/set/putConfig 的委托 (保证 app 端调用方 `CheckSource.timeout` 等代码零改动)
 * 与 Android 特有的 Service 启动入口 (start/stop/resume)。
 *
 * - `start/stop/resume`: 依赖 Android `Context.startService<CheckSourceService>` + IntentAction,
 *   无法下沉 commonMain, 留 app 端。
 * - `CacheManager` 访问: shared 端通过 [com.langhuan.reader.help.SourceCacheProvider] 间接访问,
 *   app 端 JsEnginesAndroid 注册时委托给 CacheManager, 行为与原完全一致。
 *
 * 模式参考 [com.langhuan.reader.help.source.SourceHelp] (shared 下沉 + app 薄壳)。
 */
object CheckSource {

    var keyword: String
        get() = CheckSourceShared.keyword
        set(value) { CheckSourceShared.keyword = value }

    var timeout: Long
        get() = CheckSourceShared.timeout
        set(value) { CheckSourceShared.timeout = value }

    var checkSearch: Boolean
        get() = CheckSourceShared.checkSearch
        set(value) { CheckSourceShared.checkSearch = value }

    var checkDiscovery: Boolean
        get() = CheckSourceShared.checkDiscovery
        set(value) { CheckSourceShared.checkDiscovery = value }

    var checkInfo: Boolean
        get() = CheckSourceShared.checkInfo
        set(value) { CheckSourceShared.checkInfo = value }

    var checkCategory: Boolean
        get() = CheckSourceShared.checkCategory
        set(value) { CheckSourceShared.checkCategory = value }

    var checkContent: Boolean
        get() = CheckSourceShared.checkContent
        set(value) { CheckSourceShared.checkContent = value }

    fun putConfig() = CheckSourceShared.putConfig()

    fun start(context: Context, sources: List<BookSourcePart>) {
        startUrls(context, sources.map { it.bookSourceUrl })
    }

    /**
     * 按 URL 启动校验。服务只按 id 从库里取源, 体检与共享对话框都只拿得到 URL,
     * 不必为凑 [BookSourcePart] 再查一次库。
     */
    fun startUrls(context: Context, urls: List<String>) {
        IntentData.put("checkSourceSelectedIds", urls)
        context.startService<CheckSourceService> {
            action = IntentAction.start
        }
    }

    fun stop(context: Context) {
        context.startService<CheckSourceService> {
            action = IntentAction.stop
        }
    }

    fun resume(context: Context) {
        context.startService<CheckSourceService> {
            action = IntentAction.resume
        }
    }
}
