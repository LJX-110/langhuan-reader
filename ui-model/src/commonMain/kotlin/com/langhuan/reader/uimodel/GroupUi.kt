package com.langhuan.reader.uimodel

/**
 * 分组条目的展示模型。
 *
 * 字段与 `data.entities.BookGroup` 的展示面一一对应; [groupId] 的固定值
 * (见 [Companion]) 必须与 `BookGroup` 的同名常量保持一致。
 */
data class GroupUi(
    val groupId: Long = 0b1,
    val groupName: String = "",
    val cover: String? = null,
    val order: Int = 0,
    val show: Boolean = true,
    val bookSort: Int = -1,
    /** 分组是否参与自动/下拉刷新 */
    val enableRefresh: Boolean = true,
    /** 分组内书籍数量; null 表示尚未加载 (顶栏显示 "..") */
    val bookCount: Int? = null,
) {

    companion object {
        const val IdRoot = -100L
        const val IdAll = -1L
        const val IdLocal = -2L

        /** 未分组 (与原 BookGroup.IdUngrouped 一致) */
        const val IdUngrouped = -4L
        const val IdError = -11L
    }
}
