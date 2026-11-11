// 桌面集成测试运行时: 需要真实启动序列 (数据目录/数据库/JS 引擎/HTTP 栈/平台 provider) 的用例
// 先调 [bootstrap]。与桌面端入口同一套注册顺序, 逐项手工注册必漏。
package com.langhuan.reader.desktop

import com.langhuan.reader.help.coroutine.registerJvmDebugState
import kotlinx.coroutines.runBlocking
import java.io.File

object DesktopTestRuntime {

    /** 测试数据根 (桌面 build/test-ext 内, 与真实用户数据目录隔离)。 */
    private val dataRoot = File("build/test-ext/desktop-test-data").absoluteFile

    private var booted = false

    fun bootstrap() {
        if (booted) return
        booted = true
        System.setProperty("java.awt.headless", "true")
        registerJvmDebugState(true)
        DesktopCore.initRuntimeEnvironment(dataRoot, null)
        DesktopCore.registerCoreProviders()
        runBlocking { DesktopCore.registerSecondaryCoreProviders() }
    }
}
