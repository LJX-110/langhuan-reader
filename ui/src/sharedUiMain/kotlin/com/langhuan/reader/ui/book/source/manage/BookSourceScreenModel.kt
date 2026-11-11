package com.langhuan.reader.ui.book.source.manage

import com.langhuan.reader.constant.AppLog
import com.langhuan.reader.constant.PreferKey
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.BookSourcePart
import com.langhuan.reader.help.config.PreferenceProviders
import com.langhuan.reader.help.coroutine.IoDispatcher
import com.langhuan.reader.help.source.SourceHelp
import com.langhuan.reader.model.Debug
import com.langhuan.reader.ui.book.source.BookSourceListState
import com.langhuan.reader.ui.book.source.BookSourceSort
import com.langhuan.reader.ui.book.source.ShowSourceIconDefault
import com.langhuan.reader.ui.book.source.SourceFilter
import com.langhuan.reader.ui.root.ScreenModel
import com.langhuan.reader.ui.root.screenModelScope
import com.langhuan.reader.utils.NetworkUtils
import com.langhuan.reader.utils.cnCompare
import com.langhuan.reader.utils.throttleLatest
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/**
 * 书源管理页 ScreenModel (KMP 版, sharedUiMain 共享)。
 *
 * 持有 [BookSourceListState] 并订阅 DAO flow, 通过 [dispatch] 处理 UI 事件。
 * 宿主 Activity 只负责平台专属行为 (对话框/文件/帮助/校验服务),
 * 状态与数据操作全部在本类完成。
 *
 * @param resolveFilter 平台专属: 把 searchKey 字面串映射为 [SourceFilter]
 *   (app 端用 `getString(R.string.enabled)` 等比对)
 */
class BookSourceScreenModel(
    private val resolveFilter: (String) -> SourceFilter,
) : ScreenModel {

    private val appDb get() = AppDbProviders.get()

    private val scope = screenModelScope("书源管理")

    private val _state = MutableStateFlow(
        BookSourceListState(
            showSourceIcon = PreferenceProviders.get()
                .getBoolean(PreferKey.showSourceIcon, ShowSourceIconDefault),
        )
    )
    val state: StateFlow<BookSourceListState> = _state.asStateFlow()

    private var sourceFlowJob: Job? = null
    private var groupsJob: Job? = null

    // 域名缓存, 不随数据变化失效
    private val hostMap = hashMapOf<String, String>()

    init {
        upBookSource(_state.value.searchKey)
        observeGroups()
    }

    fun getSourceHost(origin: String): String =
        hostMap.getOrPut(origin) { NetworkUtils.getSubDomainOrNull(origin) ?: "#" }

    fun selection(): List<BookSourcePart> =
        _state.value.sources.filter {
            _state.value.selected.contains(it.bookSourceUrl)
        }

    private fun observeGroups() {
        groupsJob?.cancel()
        groupsJob = scope.launch {
            appDb.bookSourceDao.flowGroups()
                .catch { AppLog.put("书源界面获取分组出错", it) }
                .flowOn(IoDispatcher)
                .throttleLatest(500)
                .collect { groups ->
                    _state.value = _state.value.copy(groups = groups)
                }
        }
    }

    private fun upBookSource(searchKey: String) {
        sourceFlowJob?.cancel()
        sourceFlowJob = scope.launch {
            val filter = resolveFilter(searchKey)
            val base = when (filter) {
                SourceFilter.All -> appDb.bookSourceDao.flowAll()
                SourceFilter.Enabled -> appDb.bookSourceDao.flowEnabled()
                SourceFilter.Disabled -> appDb.bookSourceDao.flowEnabled(false)
                SourceFilter.NeedLogin -> appDb.bookSourceDao.flowLogin()
                SourceFilter.NoGroup -> appDb.bookSourceDao.flowNoGroup()
                SourceFilter.EnabledExplore -> appDb.bookSourceDao.flowExplore()
                SourceFilter.DisabledExplore -> appDb.bookSourceDao.flowExplore(false)
                is SourceFilter.Group -> appDb.bookSourceDao.flowGroupSearch(filter.name)
                is SourceFilter.Search -> appDb.bookSourceDao.flowSearch(filter.key)
            }
            base.map { data ->
                sortedSources(data)
            }
                .catch { AppLog.put("书源界面更新书源出错", it) }
                .flowOn(IoDispatcher)
                .throttleLatest(500)
                .collect { data ->
                    val selected = _state.value.selected
                        .intersect(data.map { it.bookSourceUrl }.toSet())
                    _state.value = _state.value.copy(sources = data, selected = selected)
                }
        }
    }

    // 每次数据发射都按当前排序口径全量重排: 分组开启时按域名排, 同域名必须连续, 否则同一域名会分成多段标题
    private fun sortedSources(data: List<BookSourcePart>): List<BookSourcePart> {
        val cur = _state.value
        return if (cur.groupSourcesByDomain) {
            data.sortedWith(
                compareBy<BookSourcePart> { getSourceHost(it.bookSourceUrl) == "#" }
                    .thenBy { getSourceHost(it.bookSourceUrl) }
                    .thenByDescending { it.lastUpdateTime })
        } else {
            val tmp = when (cur.sort) {
                BookSourceSort.Weight -> data.sortedBy { it.weight }
                BookSourceSort.Name -> data.sortedWith { o1, o2 ->
                    o1.bookSourceName.cnCompare(o2.bookSourceName)
                }

                BookSourceSort.Url -> data.sortedBy { it.bookSourceUrl }
                BookSourceSort.Update -> data.sortedByDescending { it.lastUpdateTime }
                BookSourceSort.Respond -> data.sortedBy { it.respondTime }
                BookSourceSort.Enable -> data.sortedWith { o1, o2 ->
                    var sortNum = -o1.enabled.compareTo(o2.enabled)
                    if (sortNum == 0) {
                        sortNum = o1.bookSourceName.cnCompare(o2.bookSourceName)
                    }
                    sortNum
                }

                else -> data.sortedBy { it.customOrder }
            }
            if (!cur.sortAscending) tmp.reversed() else tmp
        }
    }

    fun dispatch(event: BookSourceUiEvent) {
        when (event) {
            is BookSourceUiEvent.Search -> {
                _state.value = _state.value.copy(searchKey = event.key)
                upBookSource(event.key)
            }

            is BookSourceUiEvent.SortChange -> {
                _state.value = _state.value.copy(sort = event.sort)
                upBookSource(_state.value.searchKey)
            }

            BookSourceUiEvent.ToggleSortDesc -> {
                _state.value = _state.value.copy(sortAscending = !_state.value.sortAscending)
                upBookSource(_state.value.searchKey)
            }

            BookSourceUiEvent.ToggleGroupByDomain -> {
                _state.value = _state.value.copy(
                    groupSourcesByDomain = !_state.value.groupSourcesByDomain
                )
                upBookSource(_state.value.searchKey)
            }

            BookSourceUiEvent.ToggleShowSourceIcon -> {
                val showSourceIcon = !_state.value.showSourceIcon
                PreferenceProviders.get().putBoolean(PreferKey.showSourceIcon, showSourceIcon)
                _state.value = _state.value.copy(showSourceIcon = showSourceIcon)
                // 只切渲染档位: 行数据 (含插件源图标字段) 与列表顺序均不受该开关影响。
            }

            is BookSourceUiEvent.Toggle -> {
                val cur = _state.value.selected
                _state.value = _state.value.copy(
                    selected = if (event.checked) cur + event.item.bookSourceUrl
                    else cur - event.item.bookSourceUrl
                )
            }

            is BookSourceUiEvent.SelectAll -> {
                val selectable = _state.value.sources.map { it.bookSourceUrl }.toSet()
                _state.value = _state.value.copy(
                    selected = if (event.all) selectable else emptySet()
                )
            }

            BookSourceUiEvent.RevertSelection -> {
                val all = _state.value.sources.map { it.bookSourceUrl }.toSet()
                _state.value = _state.value.copy(selected = all - _state.value.selected)
            }

            BookSourceUiEvent.CheckSelectedInterval -> {
                val sources = _state.value.sources
                val positions = sources.mapIndexedNotNull { index, part ->
                    index.takeIf { _state.value.selected.contains(part.bookSourceUrl) }
                }
                if (positions.isNotEmpty()) {
                    val range = positions.min()..positions.max()
                    _state.value = _state.value.copy(
                        selected = _state.value.selected +
                            range.map { sources[it].bookSourceUrl }
                    )
                }
            }

            is BookSourceUiEvent.Move -> {
                val moved = _state.value.sources.toMutableList()
                    .apply { add(event.to, removeAt(event.from)) }
                _state.value = _state.value.copy(sources = moved)
            }

            BookSourceUiEvent.PersistOrder -> {
                val ascending = _state.value.sortAscending
                val items = _state.value.sources
                    .mapIndexed { index, part ->
                        part.copy(customOrder = if (ascending) index else -index)
                    }
                scope.launch(IoDispatcher) { appDb.bookSourceDao.upOrder(items) }
            }

            is BookSourceUiEvent.Del -> {
                scope.launch(IoDispatcher) {
                    SourceHelp.deleteBookSourceParts(listOf(event.item))
                }
            }

            BookSourceUiEvent.DelSelection -> {
                scope.launch(IoDispatcher) {
                    SourceHelp.deleteBookSourceParts(selection())
                }
            }

            is BookSourceUiEvent.Enable -> {
                scope.launch(IoDispatcher) {
                    appDb.bookSourceDao.enable(event.enabled, listOf(event.item))
                }
            }

            is BookSourceUiEvent.EnableExplore -> {
                scope.launch(IoDispatcher) {
                    appDb.bookSourceDao.enableExplore(event.enabled, listOf(event.item))
                }
            }

            is BookSourceUiEvent.ToTop -> {
                // 升序时小 customOrder 在前, topSource; 降序时反序显示, bottomSource 才是顶部
                val ascending = _state.value.sortAscending
                scope.launch(IoDispatcher) {
                    if (ascending) {
                        val minOrder = appDb.bookSourceDao.minOrder() - 1
                        appDb.bookSourceDao.upOrder(event.item.copy(customOrder = minOrder))
                    } else {
                        val maxOrder = appDb.bookSourceDao.maxOrder() + 1
                        appDb.bookSourceDao.upOrder(event.item.copy(customOrder = maxOrder))
                    }
                }
            }

            is BookSourceUiEvent.ToBottom -> {
                val ascending = _state.value.sortAscending
                scope.launch(IoDispatcher) {
                    if (ascending) {
                        val maxOrder = appDb.bookSourceDao.maxOrder() + 1
                        appDb.bookSourceDao.upOrder(event.item.copy(customOrder = maxOrder))
                    } else {
                        val minOrder = appDb.bookSourceDao.minOrder() - 1
                        appDb.bookSourceDao.upOrder(event.item.copy(customOrder = minOrder))
                    }
                }
            }

            is BookSourceUiEvent.EnableSelection -> {
                val selection = selection()
                scope.launch(IoDispatcher) {
                    appDb.bookSourceDao.enable(event.enabled, selection)
                }
            }

            BookSourceUiEvent.EnableSelectExplore -> {
                val selection = selection()
                scope.launch(IoDispatcher) {
                    appDb.bookSourceDao.enableExplore(true, selection)
                }
            }

            BookSourceUiEvent.DisableSelectExplore -> {
                val selection = selection()
                scope.launch(IoDispatcher) {
                    appDb.bookSourceDao.enableExplore(false, selection)
                }
            }

            BookSourceUiEvent.SelectionToTop -> {
                var selection = selection()
                scope.launch(IoDispatcher) {
                    selection = selection.sortedBy { it.customOrder }
                    val minOrder = appDb.bookSourceDao.minOrder() - 1
                    val array = selection.mapIndexed { index, it ->
                        it.copy(customOrder = minOrder - index)
                    }
                    appDb.bookSourceDao.upOrder(array)
                }
            }

            BookSourceUiEvent.SelectionToBottom -> {
                var selection = selection()
                scope.launch(IoDispatcher) {
                    selection = selection.sortedBy { it.customOrder }
                    val maxOrder = appDb.bookSourceDao.maxOrder() + 1
                    val array = selection.mapIndexed { index, it ->
                        it.copy(customOrder = maxOrder + index)
                    }
                    appDb.bookSourceDao.upOrder(array)
                }
            }

            is BookSourceUiEvent.SelectionAddToGroups -> {
                val selection = selection()
                scope.launch(IoDispatcher) {
                    val array = selection.map { it.copy().apply { addGroup(event.groups) } }
                    appDb.bookSourceDao.upGroup(array)
                }
            }

            is BookSourceUiEvent.SelectionRemoveFromGroups -> {
                val selection = selection()
                scope.launch(IoDispatcher) {
                    val array = selection.map { it.copy().apply { removeGroup(event.groups) } }
                    appDb.bookSourceDao.upGroup(array)
                }
            }

            is BookSourceUiEvent.UpdateCheckSourceMsg -> {
                _state.value =
                    _state.value.copy(checkSourceMsg = event.msg, checkSourceVisible = true)
            }

            BookSourceUiEvent.HideCheckSource -> {
                _state.value = _state.value.copy(checkSourceVisible = false)
            }
        }
    }

    override fun onCleared() {
        scope.cancel()
        // 对照 app 端 BookSourceActivity.onDestroy: 非校验中时清理校验消息
        if (!Debug.isChecking) {
            Debug.clearCheckMessages()
        }
    }
}

sealed interface BookSourceUiEvent {
    data class Search(val key: String) : BookSourceUiEvent
    data class SortChange(val sort: BookSourceSort) : BookSourceUiEvent
    object ToggleSortDesc : BookSourceUiEvent
    object ToggleGroupByDomain : BookSourceUiEvent
    object ToggleShowSourceIcon : BookSourceUiEvent
    data class Toggle(val item: BookSourcePart, val checked: Boolean) : BookSourceUiEvent
    data class SelectAll(val all: Boolean) : BookSourceUiEvent
    object RevertSelection : BookSourceUiEvent
    object CheckSelectedInterval : BookSourceUiEvent
    data class Move(val from: Int, val to: Int) : BookSourceUiEvent
    object PersistOrder : BookSourceUiEvent
    data class Del(val item: BookSourcePart) : BookSourceUiEvent
    object DelSelection : BookSourceUiEvent
    data class Enable(val item: BookSourcePart, val enabled: Boolean) : BookSourceUiEvent
    data class EnableExplore(val item: BookSourcePart, val enabled: Boolean) : BookSourceUiEvent
    data class ToTop(val item: BookSourcePart) : BookSourceUiEvent
    data class ToBottom(val item: BookSourcePart) : BookSourceUiEvent
    data class EnableSelection(val enabled: Boolean) : BookSourceUiEvent
    object EnableSelectExplore : BookSourceUiEvent
    object DisableSelectExplore : BookSourceUiEvent
    object SelectionToTop : BookSourceUiEvent
    object SelectionToBottom : BookSourceUiEvent
    data class SelectionAddToGroups(val groups: String) : BookSourceUiEvent
    data class SelectionRemoveFromGroups(val groups: String) : BookSourceUiEvent
    data class UpdateCheckSourceMsg(val msg: String) : BookSourceUiEvent
    object HideCheckSource : BookSourceUiEvent
}
