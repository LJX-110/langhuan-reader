package com.langhuan.reader.desktop.help

import com.sun.jna.Platform
import com.sun.jna.platform.win32.Advapi32Util
import com.sun.jna.platform.win32.WinReg
import com.langhuan.reader.constant.AppLog
import java.io.File

/**
 * 桌面端 langhuan:// / yuedu:// 系统级 URL protocol 的运行时注册 (幂等, 后台执行)。
 *
 * 让浏览器/系统把 `langhuan://...` / `yuedu://...` 链接唤起桌面版
 * (对照 app 端 AndroidManifest intent-filter 与 iosApp CFBundleURLTypes)。
 *
 * # 各 OS 方案
 *
 * - **Windows**: 写 `HKCU\Software\Classes\<scheme>` (per-user, 无需管理员权限), 含
 *   `URL Protocol` 空值 + `shell\open\command` 默认值 `"<exe>" "%1"`。jpackage MSI /
 *   便携 zip 产物布局 `<app>/langhuan.exe` + `<app>/runtime/`, 由 `java.home` 反推 exe。
 * - **Linux**: 写 `~/.local/share/applications/langhuan.desktop`
 *   (`MimeType=x-scheme-handler/langhuan;x-scheme-handler/yuedu;` + `Exec="<launcher>" %u`),
 *   仅对 scheme 跑 `xdg-mime default`。jpackage 产物布局
 *   `<app>/bin/langhuan` + `<app>/lib/runtime`, 由 `java.home` 反推 launcher。
 * - **macOS**: 打包期注入 Info.plist `CFBundleURLTypes` (见 desktop/build.gradle.kts
 *   `nativeDistributions.macOS.infoPlist`), LaunchServices 安装 .app 时即关联;
 *   运行时回调走 Main.kt 的 `Desktop.setOpenURIHandler` (Apple Event), 无需运行时注册。
 *
 * 视频播放已移除, 各端都不再申报视频文件类型。
 *
 * # 幂等性
 *
 * 每次启动后台跑一次: Windows 的 scheme 分支先读现有 command, 相同则跳过 (避免无谓写注册表);
 * Linux 仅当 .desktop 内容变化才重写, xdg-mime default 本身幂等。
 *
 * # 开发期 (:desktop:run)
 *
 * 没有打包产物的可执行入口 (java.home 是 JDK, 反推路径不存在), 直接跳过, 不影响开发。
 */
object DesktopUrlProtocol {

    private const val TAG = "url-protocol"
    private const val LINUX_DESKTOP_FILE = "langhuan.desktop"
    private val winSchemes = listOf("langhuan", "legado", "yuedu")

    /** 只拿 scheme 当默认 handler 的 MIME (视频类型只申报候选, 不抢默认程序) */
    private val schemeMimes = listOf(
        "x-scheme-handler/langhuan",
        "x-scheme-handler/legado",
        "x-scheme-handler/yuedu",
    )

    /** 后台线程注册, 不阻塞首窗口; 幂等, 失败仅记日志。 */
    fun ensureRegisteredAsync() {
        // 只对打包产物有意义 (需要可执行入口反推路径); 开发期 java.home 是 JDK, 直接跳过
        val launcher = resolveLauncher() ?: return
        Thread({
            try {
                when {
                    Platform.isWindows() -> registerWindows(launcher)
                    Platform.isLinux() -> registerLinux(launcher)
                    // macOS: Info.plist 已在打包期注入, 无运行时注册
                }
            } catch (t: Throwable) {
                AppLog.put("URL protocol 注册失败", t, tag = TAG)
            }
        }, "langhuan-url-protocol").apply {
            isDaemon = true
            start()
        }
    }

    /**
     * 反推打包产物的可执行入口 (jpackage app image / 便携 zip 同布局)。
     * - Windows: `java.home` = `<app>/runtime` → exe = `<app>/langhuan.exe`
     * - Linux: `java.home` = `<app>/lib/runtime` → launcher = `<app>/bin/langhuan`
     * 开发期 (:desktop:run) java.home 是 JDK, 反推路径不存在 → 返回 null。
     */
    private fun resolveLauncher(): File? {
        val javaHome = File(System.getProperty("java.home") ?: return null)
        val launcher = when {
            Platform.isWindows() -> javaHome.parentFile.resolve("langhuan.exe")
            Platform.isLinux() -> javaHome.parentFile.parentFile.resolve("bin/langhuan")
            else -> return null
        }
        return launcher.takeIf { it.isFile }
    }

    // ==================== Windows: HKCU 注册表 (JNA, Unicode 安全) ====================

    private fun registerWindows(exe: File) {
        val cmd = "\"${exe.absolutePath}\" \"%1\""
        winSchemes.forEach { scheme ->
            val base = "Software\\Classes\\$scheme"
            val commandKey = "$base\\shell\\open\\command"
            val current = runCatching {
                Advapi32Util.registryGetStringValue(WinReg.HKEY_CURRENT_USER, commandKey, "")
            }.getOrNull()
            if (current == cmd) {
                return@forEach
            }
            Advapi32Util.registryCreateKey(WinReg.HKEY_CURRENT_USER, base)
            Advapi32Util.registrySetStringValue(
                WinReg.HKEY_CURRENT_USER, base, "", "URL:$scheme protocol"
            )
            // URL Protocol 空值: 浏览器据此识别为可唤起协议 (与系统自带协议写法一致)
            Advapi32Util.registrySetStringValue(
                WinReg.HKEY_CURRENT_USER, base, "URL Protocol", ""
            )
            Advapi32Util.registryCreateKey(WinReg.HKEY_CURRENT_USER, commandKey)
            Advapi32Util.registrySetStringValue(
                WinReg.HKEY_CURRENT_USER, commandKey, "", cmd
            )
        }
        registerWindowsApplication(exe, cmd)
    }

    /**
     * 把本 exe 申报给系统 (per-user, 只用于 URL scheme 处理, 不再申报视频文件类型)。
     *
     * 写点 `HKCU\Software\Classes\Applications\<exe 文件名>` (键名与值形式按官方
     * Shell 应用注册页 https://learn.microsoft.com/en-us/windows/win32/shell/app-registration
     * 的示例形态):
     * - `FriendlyAppName`      “打开方式”列表里显示的名字
     * - `shell\open\command`   选中后的实际命令行
     *
     * 视频播放已移除, 这里不再写 `SupportedTypes`: 应用不应再出现在视频文件的
     * “打开方式”候选里。历史版本写过的值不会自动清除, 重装即自愈。
     */
    private fun registerWindowsApplication(exe: File, cmd: String) {
        val base = "Software\\Classes\\Applications\\${exe.name}"
        Advapi32Util.registryCreateKey(WinReg.HKEY_CURRENT_USER, base)
        Advapi32Util.registrySetStringValue(
            WinReg.HKEY_CURRENT_USER, base, "FriendlyAppName", "Langhuan"
        )
        val commandKey = "$base\\shell\\open\\command"
        Advapi32Util.registryCreateKey(WinReg.HKEY_CURRENT_USER, commandKey)
        Advapi32Util.registrySetStringValue(WinReg.HKEY_CURRENT_USER, commandKey, "", cmd)
    }

    // ==================== Linux: .desktop + xdg-mime ====================

    private fun registerLinux(launcher: File) {
        val appsDir = File(System.getProperty("user.home"), ".local/share/applications")
        appsDir.mkdirs()
        val desktopFile = File(appsDir, LINUX_DESKTOP_FILE)
        val content = buildString {
            appendLine("[Desktop Entry]")
            appendLine("Type=Application")
            appendLine("Version=1.0")
            appendLine("Name=Langhuan")
            appendLine("Comment=Langhuan desktop reader")
            appendLine("Exec=\"${launcher.absolutePath}\" %u")
            // 只声明 scheme handler; 视频播放已移除, 不再申报视频 MIME
            appendLine("MimeType=" + schemeMimes.joinToString(";") + ";")
            appendLine("Terminal=false")
            appendLine("Categories=Office;")
        }
        val old = runCatching { desktopFile.readText() }.getOrNull()
        if (old != content) {
            desktopFile.writeText(content)
        }
        runQuiet(
            "xdg-mime", "default", LINUX_DESKTOP_FILE,
            *schemeMimes.toTypedArray(),
        )
        // 通知桌面环境刷新菜单/关联 (无该命令时静默)
        runQuiet("update-desktop-database", appsDir.absolutePath)
    }

    /** 运行外部命令, 只记失败日志 (xdg-utils 可能缺失/非零退出, 不阻塞启动)。 */
    private fun runQuiet(vararg cmd: String) {
        runCatching {
            val result = DesktopCommandRunner.run(cmd.toList(), 10_000L)
            val cmdText = cmd.joinToString(" ")
            when {
                result.exitCode == null ->
                    AppLog.put("命令超时: $cmdText", tag = TAG)

                result.exitCode != 0 ->
                    AppLog.put("命令退出码 ${result.exitCode}: $cmdText", tag = TAG)
            }
        }.onFailure {
            AppLog.put("命令执行失败: ${cmd.joinToString(" ")}", it, tag = TAG)
        }
    }
}
