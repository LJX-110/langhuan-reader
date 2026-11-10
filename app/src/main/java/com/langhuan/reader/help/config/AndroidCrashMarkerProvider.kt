package com.langhuan.reader.help.config

import android.content.Context
import com.langhuan.reader.constant.LOG_DIR_NAME
import com.langhuan.reader.help.crash.CrashMarkerProviders
import com.langhuan.reader.help.crash.LocalConfigCrashMarkerProvider
import com.langhuan.reader.utils.getFile

/**
 * 安卓宿主启动早期注册 [com.langhuan.reader.help.crash.CrashMarkerProvider] (须在启动期崩溃提示读取之前)。
 *
 * 走共用的"偏好存储 + 标记文件"实现 ([LocalConfigCrashMarkerProvider]): 偏好覆盖 Java 异常
 * 路径, 标记文件覆盖原生信号路径 (信号上下文内不能写偏好)。候选目录与崩溃日志同处 (外部缓存的
 * 日志目录)。
 *
 * 书籍保存位置 (SAF) 下的日志目录不参与: 能写到那里的只有 Java 异常路径, 而那条路径已写偏好键;
 * 文件标记只为信号路径存在, 信号处理器又写不了 SAF。
 */
fun registerAndroidCrashMarkerProvider(context: Context) {
    CrashMarkerProviders.register(
        LocalConfigCrashMarkerProvider {
            listOfNotNull(context.externalCacheDir?.getFile(LOG_DIR_NAME)?.absolutePath)
        }
    )
}
