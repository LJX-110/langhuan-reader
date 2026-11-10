package com.langhuan.reader.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import com.langhuan.reader.constant.EventBus
import com.langhuan.reader.help.LifecycleHelp
import com.langhuan.reader.help.config.AppConfig
import com.langhuan.reader.model.AudioPlay
import com.langhuan.reader.model.ReadAloud
import com.langhuan.reader.service.AudioPlayService
import com.langhuan.reader.service.BaseReadAloudService
import com.langhuan.reader.ui.book.read.HeadlessReadAloud
import com.langhuan.reader.ui.book.read.ReadBookEvents
import com.langhuan.reader.ui.root.AppNavigatorProviders
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.utils.LogUtils
import com.langhuan.reader.utils.postEvent


/**
 * Created by GKF on 2018/1/6.
 * 监听耳机键
 */
class MediaButtonReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (handleIntent(context, intent) && isOrderedBroadcast) {
            abortBroadcast()
        }
    }

    companion object {

        private const val TAG = "MediaButtonReceiver"

        fun handleIntent(context: Context, intent: Intent): Boolean {
            val intentAction = intent.action
            if (Intent.ACTION_MEDIA_BUTTON == intentAction) {
                @Suppress("DEPRECATION")
                val keyEvent = intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)
                    ?: return false
                val keycode: Int = keyEvent.keyCode
                val action: Int = keyEvent.action
                if (action == KeyEvent.ACTION_DOWN) {
                    LogUtils.d(TAG, "Receive mediaButton event, keycode:$keycode")
                    when (keycode) {
                        KeyEvent.KEYCODE_MEDIA_PREVIOUS -> {
                            when {
                                AudioPlayService.isRun -> AudioPlay.prev()
                                BaseReadAloudService.isRun -> {
                                    if (AppConfig.mediaButtonPerNext) {
                                        ReadAloud.prevChapter(context)
                                    } else {
                                        ReadAloud.prevParagraph(context)
                                    }
                                }
                                else -> readAloud(context)
                            }
                        }

                        KeyEvent.KEYCODE_MEDIA_NEXT -> {
                            when {
                                AudioPlayService.isRun -> AudioPlay.next()
                                BaseReadAloudService.isRun -> {
                                    if (AppConfig.mediaButtonPerNext) {
                                        ReadAloud.nextChapter(context)
                                    } else {
                                        ReadAloud.nextParagraph(context)
                                    }
                                }
                                else -> readAloud(context)
                            }
                        }

                        KeyEvent.KEYCODE_MEDIA_STOP -> {
                            when {
                                AudioPlayService.isRun -> AudioPlay.stop()
                                BaseReadAloudService.isRun -> ReadAloud.stop(context)
                            }
                        }

                        else -> readAloud(context)
                    }
                }
            }
            return true
        }

        fun readAloud(context: Context, isMediaKey: Boolean = true) {
            when {
                BaseReadAloudService.isRun -> {
                    if (BaseReadAloudService.isPlay()) {
                        ReadAloud.pause(context)
                        AudioPlay.pause()
                    } else {
                        ReadAloud.resume(context)
                        AudioPlay.resume()
                    }
                }

                AudioPlayService.isRun -> {
                    if (AudioPlayService.pause) {
                        AudioPlay.resume()
                    } else {
                        AudioPlay.pause()
                    }
                }

                isMediaKey && !AppConfig.readAloudByMediaButton -> {
                    // break
                }

                // AudioPlay 已下沉为共享路由, 栈顶为该路由时由页面响应媒体键事件
                // getOrNull: 广播接收器在无界面 (仅前台服务) 时也会收到媒体键
                AppNavigatorProviders.getOrNull()?.currentRoute is AppRoute.AudioPlay ->
                    postEvent(EventBus.MEDIA_BUTTON, true)

                // Reader 阅读页在栈顶时由页面响应媒体键事件 (对照原版 ReadBookActivity 分支
                // postEvent(EventBus.MEDIA_BUTTON, true) 语义, 桥接到 shared 阅读层处理)
                AppNavigatorProviders.getOrNull()?.currentRoute is AppRoute.Reader ->
                    ReadBookEvents.postMediaButton(true)

                else -> if (AppConfig.mediaButtonOnExit || LifecycleHelp.activitySize() > 0 || !isMediaKey) {
                    ReadAloud.upReadAloudClass()
                    // 无活动阅读页时从最近阅读的书无头准备正文并起朗读 (对照原版 else 分支的
                    // lastReadBook → initData + clearTextChapter + loadContent{readAloud}, 不打开阅读页);
                    // 阅读实例已挂接时由它接手开播/交页面切换
                    HeadlessReadAloud.start()
                }
            }
        }
    }

}
