package com.langhuan.reader.help.source

import com.langhuan.reader.data.entities.BaseSource
import com.langhuan.reader.model.SharedJsScope
import com.langhuan.reader.model.script.JsScope
import kotlin.coroutines.CoroutineContext

/**
 * 获取书源对应的共享 JS scope。
 *
 * 返回 [JsScope]（app 侧统一类型），由 [SharedJsScope] 按当前引擎分派到
 * rhino [com.langhuan.reader.model.script.rhino.RhinoJsScope] 或
 * quickjs [com.langhuan.reader.model.script.quickjs.QuickJsJsScope]。
 */
fun BaseSource.getShareScope(coroutineContext: CoroutineContext? = null): JsScope? {
    return SharedJsScope.getScope(jsLib, enableDangerousApi == true, coroutineContext)
}
