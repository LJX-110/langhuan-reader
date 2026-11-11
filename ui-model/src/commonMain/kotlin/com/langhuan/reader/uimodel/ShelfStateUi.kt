package com.langhuan.reader.uimodel

/**
 * 书架页面的完整展示状态。
 *
 * 页面只订阅这一份状态; 分组切换、刷新进度与书籍列表都由宿主层从数据库/领域层
 * 计算后填入, 页面不再直接接触 Room 实体或 DAO。
 */
data class ShelfStateUi(
    val groups: List<GroupUi> = emptyList(),
    val currentGroupId: Long = GroupUi.IdAll,
    /** 当前分组 (或根级) 的书籍 */
    val books: List<BookItemUi> = emptyList(),
    /** 各分组最近一次快照, 供分组页/样式2 首帧渲染 */
    val booksByGroup: Map<Long, List<BookItemUi>> = emptyMap(),
    val isRefreshing: Boolean = false,
    val progressText: String? = null,
    val refreshingBookUrls: Set<String> = emptySet(),
)
