package com.langhuan.reader.model.script

import android.provider.Settings
import com.langhuan.reader.App
import com.langhuan.reader.constant.AndroidIdHolder
import com.langhuan.reader.help.CacheManager
import com.langhuan.reader.help.ExploreKindsCacheProvider
import com.langhuan.reader.help.ExploreKindsCacheProviders
import com.langhuan.reader.help.JsCryptoProviderJvm
import com.langhuan.reader.help.JsCryptoProviders
import com.langhuan.reader.help.RuleBigDataHelp
import com.langhuan.reader.help.RuleBigDataProviders
import com.langhuan.reader.help.UserAgentProvider
import com.langhuan.reader.help.UserAgentProviders
import com.langhuan.reader.help.config.AppConfig
import com.langhuan.reader.help.http.CookieStore
import com.langhuan.reader.help.http.OkHttpProxyClientProvider
import com.langhuan.reader.help.http.OkHttpProxyClientProviders
import com.langhuan.reader.help.image.BitmapImageOps
import com.langhuan.reader.help.registerComposeDefaultDataResourceProvider
import com.langhuan.reader.help.source.SourceCacheProvider
import com.langhuan.reader.help.source.SourceCacheProviders
import com.langhuan.reader.help.source.SourceDebugLogger
import com.langhuan.reader.help.source.SourceDebugLoggers
import com.langhuan.reader.help.source.SourceNetworkProvider
import com.langhuan.reader.help.source.SourceNetworkProviders
import com.langhuan.reader.model.Debug
import com.langhuan.reader.model.SharedJsScope
import com.langhuan.reader.model.analyzeRule.AnalyzeRule
import com.langhuan.reader.model.analyzeRule.AnalyzeRuleFactories
import com.langhuan.reader.model.analyzeRule.AnalyzeUrl
import com.langhuan.reader.model.analyzeRule.AnalyzeUrlFactories
import com.langhuan.reader.model.script.quickjs.QuickJsJsEngine
import com.langhuan.reader.model.script.quickjs.QuickJsSharedJsScopeProvider
import com.langhuan.reader.utils.ACache
import com.langhuan.reader.utils.registerAndroidChineseUtils

/**
 * JS 引擎面的安卓绑定注册（引擎实现/共享 scope 缓存/image 实现留 app，抽象面在 shared）。
 *
 * shared 侧 [JsEngines]/[SharedJsScope]/[JsBindingInjector] 走 provider 注入（非 expect/actual），
 * 宿主启动早期 App.onCreate 调 [registerAndroidJsEngines]（任何 JS eval 之前）。
 *
 * 引擎固定 quickjs（rhino 已弃用，模块及适配层已删除）。
 */
fun registerAndroidJsEngines() {
    JsBindingInjector.registerImageOps(BitmapImageOps)
    JsEngines.registerProvider { type ->
        when (type) {
            JsEngineType.QUICKJS -> QuickJsJsEngine
        }
    }
    SharedJsScope.registerProviders { type ->
        when (type) {
            JsEngineType.QUICKJS -> QuickJsSharedJsScopeProvider
        }
    }
    // 简繁词典 tc 缓存定位器(含缺失后台拉取), shared ChineseUtils 走 provider 注入
    registerAndroidChineseUtils()

    // shared 侧实体类 (BaseBook/BookChapter) 通过此 provider 访问大变量存储;
    // 任何 shared 实体 putBigVariable/getBigVariable 调用之前必须已注册
    RuleBigDataProviders.impl = RuleBigDataHelp

    AndroidIdHolder.value = Settings.System.getString(
        App.instance.contentResolver, Settings.Secure.ANDROID_ID
    ) ?: "null"
    SourceCacheProviders.impl = object : SourceCacheProvider {
        override fun get(key: String) = CacheManager.get(key)
        override fun put(key: String, value: String) = CacheManager.put(key, value)
        override fun delete(key: String) = CacheManager.delete(key)
        override fun getFromMemory(key: String) = CacheManager.getFromMemory(key)
        override fun putMemory(key: String, value: Any) = CacheManager.putMemory(key, value)
        override fun deleteMemory(key: String) = CacheManager.deleteMemory(key)
        override fun asBinding(): Any = CacheManager
    }
    SourceNetworkProviders.impl = object : SourceNetworkProvider {
        override fun getCookie(tag: String) = CookieStore.getCookie(tag)
        override fun replaceCookie(tag: String, cookie: String) = CookieStore.replaceCookie(tag, cookie)
        override fun removeCookie(tag: String) = CookieStore.removeCookie(tag)
        override fun asBinding(): Any = CookieStore
    }
    // shared webBook 编排层创建 AnalyzeRule 走此工厂: 返回 app 端 AnalyzeRule 子类,
    // 补全 JsExtensions 面 (md5Encode/createSymmetricCrypto/get/post 等) 并命中 KSP @JsApi 分派表。
    AnalyzeRuleFactories.register { ruleData, source, preUpdateJs ->
        AnalyzeRule(ruleData, source, preUpdateJs)
    }
    // shared 各处创建 AnalyzeUrl 同理走工厂: url 内 <js>/{{}}/js 头等场景的 java 绑定
    // 恢复完整 JsExtensions 面 (createSymmetricCrypto 等) 并命中 KSP @JsApi 分派表。
    AnalyzeUrlFactories.register {
            rawUrl, baseUrl, source, ruleData, chapter, readTimeout, callTimeout,
            coroutineContext, headerMapF, hasLoginHeader, selectedOptions, variables,
            optionSelections ->
        AnalyzeUrl(
            rawUrl, baseUrl, source, ruleData, chapter, readTimeout, callTimeout,
            coroutineContext, headerMapF, hasLoginHeader, selectedOptions, variables,
            optionSelections
        )
    }
    SourceDebugLoggers.impl = object : SourceDebugLogger {
        override fun log(key: String, msg: String, print: Boolean, state: Int, showTime: Boolean) =
            Debug.log(key, msg, print = print, state = state, showTime = showTime)

        override fun log(msg: String) = Debug.log(msg)
    }
    // JS 加解密面 (JsExtensionsCommon 加解密默认方法) 的平台实现注册
    JsCryptoProviders.register(JsCryptoProviderJvm)
    // F2: BookSource 下沉后访问 ACache.get("explore").getAsString/put(...) 走 provider, 行为不变。
    // exploreKinds() 已下沉到 shared BookSourceExtensionsShared.kt, 写入侧 (JS 解析出 ruleStr 后 put)
    // 与读侧 (getAsString) 均经此 provider 转发到 ACache。
    // clearExploreKindsCache (shared) 清理 exploreKindsMap 内存缓存后调 remove, 此处仅清理 ACache 磁盘缓存。
    ExploreKindsCacheProviders.impl = object : ExploreKindsCacheProvider {
        override fun getAsString(key: String): String? = ACache.get("explore").getAsString(key)
        override fun put(key: String, value: String) = ACache.get("explore").put(key, value)
        override fun remove(key: String) {
            ACache.get("explore").remove(key)
        }
    }
    UserAgentProviders.impl = UserAgentProvider { AppConfig.userAgent }
    // shared 侧 OkHttp 代理客户端实现注入: 转发到 app 端 HttpHelper.getProxyClient
    OkHttpProxyClientProviders.impl = object : OkHttpProxyClientProvider {
        override fun getProxyClient(proxy: String?) = com.langhuan.reader.help.http.getProxyClient(proxy)
    }
    // DefaultData 资源读取走 provider 注入 (实现是 :ui 的 ComposeResourceDefaultDataProvider,
    // 经 Res.readBytes 取数, 打包前缀由资源生成器写进 Res)。
    // 必须在 registerAndroidWebBookProviders() 之前注册: appDb lazy 初始化触发 dbCallback.onCreate
    // 时会访问 DefaultData.keyboardAssists (经 DefaultDataShared 间接读资源)。
    // 注册时机: App.onCreate 中 registerAndroidJsEngines() 先于 registerAndroidWebBookProviders() 调用。
    registerComposeDefaultDataResourceProvider()
}
