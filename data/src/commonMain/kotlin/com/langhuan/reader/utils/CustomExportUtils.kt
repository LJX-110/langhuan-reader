package com.langhuan.reader.utils

import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.help.config.PreferenceProviders

/**
 * 是否启用自定义导出 (开关打开 **且** 导出类型为 epub)
 *
 * @author Discut
 */
fun enableCustomExport(): Boolean {
    return PreferenceProviders.get().getBoolean(PreferKey.enableCustomExport, false) &&
        PreferenceProviders.get().getInt(PreferKey.exportType, 0) == 1
}
