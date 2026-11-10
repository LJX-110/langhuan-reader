package com.langhuan.reader.help

import com.langhuan.reader.constant.EventBus
import com.langhuan.reader.data.entities.PinnedExplore
import com.langhuan.reader.help.PinnedExploreHelp.FILE_NAME
import com.langhuan.reader.help.storage.FilesJsonStore
import com.langhuan.reader.utils.GSON
import com.langhuan.reader.utils.fromJsonArray
import com.langhuan.reader.utils.postEvent
import com.langhuan.reader.utils.toJson

/**
 * 发现页置顶条目管理。
 *
 * 真身存 filesDir JSON 文件 [FILE_NAME] (桌面端 java.util.prefs value ≤ 8192
 * 超限抛异常), 备份/恢复经 config.json 走文件内容 (见 BackupShared/RestoreShared)。
 */
object PinnedExploreHelp {
    const val PREF_KEY = "exploreFavorites"
    const val FILE_NAME = "exploreFavorites.json"

    private var pinnedExplores: List<PinnedExplore>? = null

    fun getPinnedExplores(): List<PinnedExplore> {
        if (pinnedExplores == null) {
            pinnedExplores = GSON.fromJsonArray<PinnedExplore>(FilesJsonStore.readText(FILE_NAME))
                .getOrNull() ?: emptyList()
        }
        return pinnedExplores!!
    }

    fun addPinnedExplore(pinned: PinnedExplore) {
        val favorites = getPinnedExplores().toMutableList()
        favorites.add(pinned)
        pinnedExplores = favorites
        FilesJsonStore.writeText(FILE_NAME, GSON.toJson(favorites))
        postEvent(EventBus.UP_EXPLORE_PINNED, "add")
    }

    fun removePinnedExplore(pinned: PinnedExplore) {
        val favorites = getPinnedExplores().toMutableList()
        val index = favorites.indexOf(pinned)
        if (index != -1) {
            favorites.removeAt(index)
            pinnedExplores = favorites
            FilesJsonStore.writeText(FILE_NAME, GSON.toJson(favorites))
            postEvent(EventBus.UP_EXPLORE_PINNED, "remove:$index")
        }
    }

    /** 恢复备份写回文件后清内存缓存 (见 RestoreShared) */
    fun invalidate() {
        pinnedExplores = null
    }
}
