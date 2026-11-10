package com.langhuan.reader.data

import com.langhuan.reader.constant.AppPattern
import com.langhuan.reader.utils.cnCompare
import com.langhuan.reader.utils.splitNotBlank

/*
 * DAO 接口下沉前置——dealGroups 由 app 端 DaoUtils.kt 迁入 shared。
 *
 * 公共逻辑放 commonMain (仅依赖 splitNotBlank + AppPattern.splitGroupRegex, 均 commonMain-ready);
 * 排序走已下沉的 [cnCompare] (commonMain expect/actual, 见 utils/StringCnCompare.kt)。
 *
 * 跨平台 dealGroups 仅供 shared 模块内 DAO 接口 (jvmAndAndroidMain) 调用, internal 跨模块不可见,
 * app 端历史调用方均经 DAO 间接访问, 无破坏。
 */
internal fun dealGroups(list: List<String>): List<String> {
    val groups = linkedSetOf<String>()
    list.forEach {
        it.splitNotBlank(AppPattern.splitGroupRegex).forEach { group ->
            groups.add(group)
        }
    }
    return groups.sortedWith { o1, o2 ->
        o1.cnCompare(o2)
    }
}
