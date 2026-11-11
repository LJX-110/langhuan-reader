package com.langhuan.reader.uimodel

/**
 * 书籍条目的展示模型 (书架 / 发现 / 搜索 / 本地共用)。
 *
 * 只保留页面渲染与跳转需要的字段, 不携带 ReadConfig、书源规则等业务实体;
 * 需要完整实体时由宿主层按 [bookUrl] 回查。
 */
data class BookItemUi(
    val bookUrl: String,
    val name: String,
    val author: String = "",
    val coverUrl: String? = null,
    val origin: String = "",
    val originName: String = "",
    /** 书籍类型, 取值语义见 `constant.BookType` */
    val type: Int = 0,
    val groupId: Long = 0L,
    val intro: String? = null,
    val kind: String? = null,
    val latestChapterTitle: String? = null,
    val latestChapterTime: Long = 0L,
    val durChapterTitle: String? = null,
    val durChapterIndex: Int = 0,
    val durChapterPos: Int = 0,
    /** 最近阅读时间, 书架/本地页用来选定首次落点 */
    val durChapterTime: Long = 0L,
    val totalChapterNum: Int = 0,
    /** 未读章数, 已按阅读配置 (含模拟追读) 计算 */
    val unreadCount: Int = 0,
    /** 最近一次检查到的新章数, > 0 时未读徽标高亮 */
    val lastCheckCount: Int = 0,
    val wordCount: String? = null,
    val isLocal: Boolean = false,
    val isAudio: Boolean = false,
    val canUpdate: Boolean = true,
    val customCoverUrl: String? = null,
    val customTag: String? = null,
    val customIntro: String? = null,
)
