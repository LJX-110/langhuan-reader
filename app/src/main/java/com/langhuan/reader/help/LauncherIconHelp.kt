package com.langhuan.reader.help

import android.content.ComponentName
import android.content.pm.PackageManager
import com.langhuan.reader.App
import com.langhuan.reader.ui.welcome.Launcher1
import com.langhuan.reader.ui.welcome.Launcher4
import com.langhuan.reader.ui.welcome.Launcher5
import com.langhuan.reader.ui.welcome.WelcomeActivity

/**
 * Created by GKF on 2018/2/27.
 * 更换图标
 */
object LauncherIconHelp {
    private val packageManager: PackageManager = App.instance.packageManager
    private val componentNames = arrayListOf(
        ComponentName(App.instance, Launcher1::class.java.name),
        ComponentName(App.instance, Launcher4::class.java.name),
        ComponentName(App.instance, Launcher5::class.java.name)
    )

    fun changeIcon(icon: String?) {
        if (icon.isNullOrEmpty()) return
        var hasEnabled = false
        componentNames.forEach {
            if (icon.equals(it.className.substringAfterLast("."), true)) {
                hasEnabled = true
                //启用
                packageManager.setComponentEnabledSetting(
                    it,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
            } else {
                //禁用
                packageManager.setComponentEnabledSetting(
                    it,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        }
        if (hasEnabled) {
            packageManager.setComponentEnabledSetting(
                ComponentName(App.instance, WelcomeActivity::class.java.name),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        } else {
            packageManager.setComponentEnabledSetting(
                ComponentName(App.instance, WelcomeActivity::class.java.name),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
        }
    }
}