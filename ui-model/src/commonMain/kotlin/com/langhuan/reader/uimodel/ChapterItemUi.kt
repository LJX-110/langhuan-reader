package com.langhuan.reader.uimodel

/**
 * 章节条目的展示模型 (目录 / 正文)。
 *
 * [index] 是章节在目录中的序号 (0 起), 同时作为跳转与进度定位的稳定标识。
 */
data class ChapterItemUi(
    val index: Int,
    val title: String,
    val url: String = "",
    val isVip: Boolean = false,
    val isPay: Boolean = false,
    /** 卷名行 (非正文章节) 标记 */
    val isVolume: Boolean = false,
)
