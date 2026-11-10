package com.langhuan.reader.ui.main

import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.langhuan.reader.App
import com.langhuan.reader.R
import com.langhuan.reader.constant.AppConst
import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.constant.IntentAction
import com.langhuan.reader.constant.NotificationId
import com.langhuan.reader.help.NotificationHelp
import com.langhuan.reader.help.i18n.androidAppString
import com.langhuan.reader.help.service.UpdateBookCallback
import com.langhuan.reader.help.setLiveProgress
import com.langhuan.reader.service.UpdateBookService
import com.langhuan.reader.ui.main.AndroidUpdateBookCallback.onProgressCancel
import com.langhuan.reader.ui.main.AndroidUpdateBookCallback.onProgressUpdate
import com.langhuan.reader.ui.main.AndroidUpdateBookCallback.toastForceRefreshBusy
import com.langhuan.reader.ui.main.AndroidUpdateBookCallback.toastForceRefreshDone
import com.langhuan.reader.ui.main.AndroidUpdateBookCallback.toastForceRefreshStart
import com.langhuan.reader.utils.servicePendingIntent
import com.langhuan.reader.utils.startForegroundService
import com.langhuan.reader.utils.stopService
import com.langhuan.reader.utils.toastOnUi

/**
 * [UpdateBookCallback] 的 Android 实现 (单例, 由 [com.langhuan.reader.App] 注册为默认实现)。
 *
 * 供 shared [com.langhuan.reader.ui.bookshelf.BookshelfViewModel] 构造 UpdateBookShared 刷新引擎时
 * 经 [com.langhuan.reader.help.service.UpdateBookCallbacks.getDefault] 取用 (iOS/鸿蒙端对应
 * [com.langhuan.reader.help.service.NativeUpdateBookCallback], 桌面端对应
 * [com.langhuan.reader.help.service.DesktopUpdateBookCallback])。
 *
 * 桥接进度到 Android 通知栏 (逻辑与下沉前 MainViewModel.updateUpdateNotification 一致):
 * - [onProgressUpdate]: `startForegroundService<UpdateBookService>` + `NotificationManagerCompat.notify`
 *   (NotificationCompat.Builder 设置进度)
 * - [onProgressCancel]: `stopService<UpdateBookService>` (取消通知)
 * - [toastForceRefreshBusy]: `toastOnUi(androidAppString("force_refresh_busy"))`
 * - [toastForceRefreshStart] / [toastForceRefreshDone]: app 端原 MainViewModel 无此 toast
 *   (仅桌面端有), no-op
 *
 * # isActivityVisible 处理
 * 原 `updateUpdateNotification` 在 `isActivityVisible=true` 时直接 `stopService` 不显示通知
 * (避免 Activity 可见时打扰用户)。MainActivity 经 [MainViewModel.isActivityVisible] 维护本标志
 * (MainViewModel 与书架 VM 各自的引擎共用本单例, 通知行为一致)。
 */
object AndroidUpdateBookCallback : UpdateBookCallback {

    /** Activity 是否可见: 可见时不显示进度通知 (原 MainViewModel.isActivityVisible 语义) */
    @Volatile
    var isActivityVisible = true

    override fun onProgressUpdate(
        active: Boolean,
        title: String,
        content: String,
        count: Int,
        total: Int
    ) {
        // Activity 可见时不显示通知 (与原 updateUpdateNotification 一致)
        if (isActivityVisible) {
            App.instance.stopService<UpdateBookService>()
            return
        }
        App.instance.startForegroundService<UpdateBookService>()
        if (NotificationManagerCompat.from(App.instance).areNotificationsEnabled()) {
            // title/content 已由 UpdateBookShared 计算 (appString(AppStringKey.update_toc /
            // force_refresh_book) → "update_toc" / "force_refresh_book"
            // 多语言文案 + "count/total"), 这里直接用
            val notificationBuilder =
                NotificationCompat.Builder(App.instance, AppConst.channelIdDownload)
                    .setSmallIcon(R.drawable.ic_update)
                    .setOngoing(true)
                    .setOnlyAlertOnce(true)
                    .setContentTitle(title)
                    .setContentText(content)
                    .setLiveProgress(
                        count,
                        total,
                        shortText = if (total > 0) "$count/$total" else null
                    )
                    .addAction(
                        R.drawable.ic_stop_black_24dp,
                        androidAppString("cancel"),
                        App.instance.servicePendingIntent<UpdateBookService>(IntentAction.stop)
                    )
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            try {
                val notification = notificationBuilder.build()
                NotificationHelp.logPromotable(notification)
                NotificationManagerCompat.from(App.instance)
                    .notify(NotificationId.UpdateBookService, notification)
            } catch (e: Exception) {
                AppLog.put("更新通知失败\n${e.localizedMessage}", e)
            }
        }
    }

    override fun onProgressCancel() {
        App.instance.stopService<UpdateBookService>()
    }

    override fun toastForceRefreshBusy() {
        App.instance.toastOnUi(androidAppString("force_refresh_busy"))
    }

    override fun toastForceRefreshStart(count: Int) {
        // app 端原 MainViewModel 无此 toast (仅桌面端有), no-op
    }

    override fun toastForceRefreshDone() {
        // app 端原 MainViewModel 无此 toast (仅桌面端有), no-op
    }
}
