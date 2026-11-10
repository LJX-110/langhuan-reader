package com.langhuan.reader.model.analyzeRule

import androidx.annotation.Keep
import androidx.media3.common.MediaItem
import com.script.jsdispatch.JsApi
import com.langhuan.reader.constant.AppConst
import com.langhuan.reader.data.entities.BaseSource
import com.langhuan.reader.data.entities.BookChapterLike
import com.langhuan.reader.help.exoplayer.ExoPlayerHelper
import kotlin.coroutines.CoroutineContext
import kotlin.coroutines.EmptyCoroutineContext

/**
 * AnalyzeUrl app 端实现: 继承 shared 的 [AnalyzeUrlCore],
 * 添加 android-only 方法 (getMediaItem)。
 *
 * KSP @JsApi 分派表由本类生成, 通过 getAllFunctions() 继承链
 * 自动包含 AnalyzeUrlCore 的 public 方法, 方法名集合与原 AnalyzeUrl 完全一致 (零 diff)。
 *
 * Created by GKF on 2018/1/24.
 * 搜索URL规则解析
 */
@Keep
@JsApi
class AnalyzeUrl(
    rawUrl: String,
    baseUrl: String = "",
    source: BaseSource? = null,
    ruleData: RuleDataInterface? = null,
    chapter: BookChapterLike? = null,
    readTimeout: Long? = null,
    callTimeout: Long? = null,
    coroutineContext: CoroutineContext = EmptyCoroutineContext,
    headerMapF: Map<String, String>? = null,
    hasLoginHeader: Boolean = true,
    selectedOptions: Map<String, String>? = null,
    variables: Map<AppConst.JsVarName, Any>? = null,
    optionSelections: Map<String, com.langhuan.reader.model.webBook.ExploreOptionSelection>? = null
) : AnalyzeUrlCore(
    rawUrl, baseUrl, source, ruleData, chapter, readTimeout, callTimeout,
    coroutineContext, headerMapF, hasLoginHeader, selectedOptions, variables, optionSelections
) {

    companion object {
        fun AnalyzeUrl.getMediaItem(): MediaItem {
            setCookie()
            return ExoPlayerHelper.createMediaItem(url, headerMap)
        }
    }
}
