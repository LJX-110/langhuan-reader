package com.langhuan.reader.uimodel

/**
 * 发现页行条目 (书源) 的展示模型。只保留行渲染与菜单判定需要的字段,
 * 菜单动作需要的完整书源实体由页面边界按 [bookSourceUrl] 回查。
 */
data class SourceItemUi(
    val bookSourceUrl: String,
    val bookSourceName: String,
    val bookSourceGroup: String? = null,
    val hasLoginUrl: Boolean = false,
)

/** 发现页收藏项 (书源 + 分类) 的展示模型。 */
data class PinnedItemUi(
    val sourceUrl: String,
    val sourceName: String,
    val categoryName: String,
    val categoryUrl: String,
    val searchKey: String? = null,
) {
    /** 收藏按钮文案: "书源名-分类名" */
    val label: String get() = "$sourceName-$categoryName"
}

/**
 * 发现页展开后的分类项展示模型。
 *
 * [colSpan] / [rowSpan] 已按 FlexChildStyle 规则预计算, 页面直接映射到 GridPackSpec;
 * [isError] 对应标题 "ERROR:" 前缀, [isButton] 对应 button 类型分类。
 */
data class KindItemUi(
    val title: String,
    val url: String? = null,
    val isError: Boolean = false,
    val isButton: Boolean = false,
    val colSpan: Int = 4,
    val rowSpan: Int = 1,
)
