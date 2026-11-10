package com.langhuan.reader.model

import android.content.Context
import android.content.Intent
import com.langhuan.reader.App
import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.constant.IntentAction
import com.langhuan.reader.data.appDb
import com.langhuan.reader.data.entities.HttpTTS
import com.langhuan.reader.help.config.AppConfig
import com.langhuan.reader.service.BaseReadAloudService
import com.langhuan.reader.service.HttpReadAloudService
import com.langhuan.reader.service.TTSReadAloudService
import com.langhuan.reader.utils.LogUtils
import com.langhuan.reader.utils.StringUtils
import com.langhuan.reader.utils.startForegroundServiceCompat
import com.langhuan.reader.utils.toastOnUi
import kotlinx.coroutines.runBlocking

object ReadAloud {
    // 延迟到首次真正需要时再查 DAO, 避免类加载期 runBlocking 阻塞主线程
    // (原版是同步 DAO 调用, 下沉后 DAO 仅剩 suspend, Room KMP 禁止 commonMain 声明非 suspend 查询)
    private var aloudClassOrNull: Class<*>? = null
    private val aloudClass: Class<*>
        get() = aloudClassOrNull ?: getReadAloudClass().also { aloudClassOrNull = it }
    // 书内 TTS 引擎设置取活动阅读实例 (app 端 ReadBook 单例与 Compose 阅读器非同一实例)
    val ttsEngine
        get() = ActiveReadBookRegistry.current?.bookValue?.config?.ttsEngine ?: AppConfig.ttsEngine
    var httpTTS: HttpTTS? = null

    private fun getReadAloudClass(): Class<*> {
        val ttsEngine = ttsEngine
        if (ttsEngine.isNullOrBlank()) return TTSReadAloudService::class.java
        if (StringUtils.isNumeric(ttsEngine)) {
            httpTTS = runBlocking { appDb.httpTTSDao.get(ttsEngine.toLong()) }
            if (httpTTS != null) return HttpReadAloudService::class.java
        }
        return TTSReadAloudService::class.java
    }

    /**
     * 按当前引擎配置重取服务类与引擎实体, 不停正在运行的朗读。
     *
     * 正在使用的在线引擎被编辑后调用: 服务类不变, 但下载与缓存键读的是实体里的
     * url/请求头, 不重取则重载后仍走旧配置。
     */
    fun refreshAloudClass() {
        aloudClassOrNull = getReadAloudClass()
    }

    fun upReadAloudClass() {
        stop(App.instance)
        aloudClassOrNull = getReadAloudClass()
    }

    fun play(
        context: Context,
        play: Boolean = true,
        pageIndex: Int = ActiveReadBookRegistry.current?.durPageIndexValue ?: 0,
        startPos: Int = 0
    ) {
        val intent = Intent(context, aloudClass).apply {
            action = IntentAction.play
            putExtra("play", play)
            putExtra("pageIndex", pageIndex)
            putExtra("startPos", startPos)
        }
        LogUtils.d("ReadAloud", intent.toString())
        try {
            context.startForegroundServiceCompat(intent)
        } catch (e: Exception) {
            val msg = "启动朗读服务出错\n${e.localizedMessage}"
            AppLog.put(msg, e)
            context.toastOnUi(msg)
        }
    }

    private inline fun sendAction(
        context: Context,
        action: String,
        extras: Intent.() -> Unit = {}
    ) {
        if (!BaseReadAloudService.isRun) return
        val intent = Intent(context, aloudClass).apply {
            this.action = action
            extras()
        }
        context.startForegroundServiceCompat(intent)
    }

    fun pause(context: Context) = sendAction(context, IntentAction.pause)

    fun resume(context: Context) = sendAction(context, IntentAction.resume)

    fun stop(context: Context) = sendAction(context, IntentAction.stop)

    fun prevParagraph(context: Context) = sendAction(context, IntentAction.prevParagraph)

    fun nextParagraph(context: Context) = sendAction(context, IntentAction.nextParagraph)

    fun prevChapter(context: Context) = sendAction(context, IntentAction.prev)

    fun nextChapter(context: Context) = sendAction(context, IntentAction.next)

    fun upTtsSpeechRate(context: Context) = sendAction(context, IntentAction.upTtsSpeechRate)

    fun setTimer(context: Context, minute: Int) =
        sendAction(context, IntentAction.setTimer) { putExtra("minute", minute) }
}
