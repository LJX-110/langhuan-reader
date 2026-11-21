package com.langhuan.reader.ui.route

import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.langhuan.reader.constant.EventBus
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.BookSourcePart
import com.langhuan.reader.help.coroutine.IoDispatcher
import com.langhuan.reader.help.showSourceLogin
import com.langhuan.reader.help.storage.BackupFileOps
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.model.CheckSourceShared
import com.langhuan.reader.model.Debug
import com.langhuan.reader.ui.association.ImportBookSourceItemsDialog
import com.langhuan.reader.ui.association.ImportBookSourceViewModelShared
import com.langhuan.reader.ui.book.search.SearchScope
import com.langhuan.reader.ui.book.source.BookSourceListCallbacks
import com.langhuan.reader.ui.book.source.BookSourceListScreen
import com.langhuan.reader.ui.book.source.SourceFilter
import com.langhuan.reader.ui.book.source.health.SourceHealthCheckSheet
import com.langhuan.reader.ui.book.source.health.SourceHealthDeleteConfirmDialog
import com.langhuan.reader.ui.book.source.health.SourceHealthResult
import com.langhuan.reader.ui.book.source.health.SourceHealthResultSheet
import com.langhuan.reader.ui.book.source.health.SourceHealthScope
import com.langhuan.reader.ui.book.source.health.isFailedSource
import com.langhuan.reader.ui.book.source.manage.BookSourceGroupManageDialog
import com.langhuan.reader.ui.book.source.manage.BookSourceScreenModel
import com.langhuan.reader.ui.book.source.manage.BookSourceUiEvent
import com.langhuan.reader.ui.compose.component.AlertButton
import com.langhuan.reader.ui.compose.component.AppAlertDialog
import com.langhuan.reader.ui.compose.component.SelectAction
import com.langhuan.reader.ui.compose.platform.AppBackHandler
import com.langhuan.reader.ui.root.AppNavigator
import com.langhuan.reader.ui.root.AppRoute
import com.langhuan.reader.ui.root.PlatformCapabilityProviders
import com.langhuan.reader.ui.root.PlatformServiceProviders
import com.langhuan.reader.ui.root.RouteEntry
import com.langhuan.reader.ui.root.RouteResults
import com.langhuan.reader.ui.root.ScreenModelStore
import com.langhuan.reader.ui.widget.dialog.OnlineImportUrlDialog
import com.langhuan.reader.utils.FlowBus
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import com.langhuan.reader.ui.generated.resources.Res
import com.langhuan.reader.ui.generated.resources.add_group
import com.langhuan.reader.ui.generated.resources.cancel
import com.langhuan.reader.ui.generated.resources.check_select_source
import com.langhuan.reader.ui.generated.resources.check_selected_interval
import com.langhuan.reader.ui.generated.resources.delete
import com.langhuan.reader.ui.generated.resources.delete_selected_source
import com.langhuan.reader.ui.generated.resources.delete_source
import com.langhuan.reader.ui.generated.resources.disable_explore
import com.langhuan.reader.ui.generated.resources.disable_selection
import com.langhuan.reader.ui.generated.resources.disabled
import com.langhuan.reader.ui.generated.resources.disabled_explore
import com.langhuan.reader.ui.generated.resources.draw
import com.langhuan.reader.ui.generated.resources.enable_explore
import com.langhuan.reader.ui.generated.resources.enable_selection
import com.langhuan.reader.ui.generated.resources.enabled
import com.langhuan.reader.ui.generated.resources.enabled_explore
import com.langhuan.reader.ui.generated.resources.export_selection
import com.langhuan.reader.ui.generated.resources.need_login
import com.langhuan.reader.ui.generated.resources.no
import com.langhuan.reader.ui.generated.resources.no_group
import com.langhuan.reader.ui.generated.resources.remove_group
import com.langhuan.reader.ui.generated.resources.selection_to_bottom
import com.langhuan.reader.ui.generated.resources.selection_to_top
import com.langhuan.reader.ui.generated.resources.share_selected_source
import com.langhuan.reader.ui.generated.resources.source_health_already_disabled
import com.langhuan.reader.ui.generated.resources.source_health_checking
import com.langhuan.reader.ui.generated.resources.source_health_deleted
import com.langhuan.reader.ui.generated.resources.source_health_disable_failed
import com.langhuan.reader.ui.generated.resources.source_health_disabled
import com.langhuan.reader.ui.generated.resources.source_health_empty_scope
import com.langhuan.reader.ui.generated.resources.source_health_restored
import com.langhuan.reader.ui.generated.resources.source_health_undo
import com.langhuan.reader.ui.generated.resources.sure_del
import com.langhuan.reader.ui.generated.resources.wrong_format
import com.langhuan.reader.ui.generated.resources.yes
import org.jetbrains.compose.resources.stringResource

/**
 * AppRoute.BookSourceManage 路由下沉入口: 桥接 [BookSourceScreenModel] 状态与 [BookSourceListScreen] 渲染。
 *
 * 平台字符串经 [rememberString] 注入 resolveFilter; 导航与 dispatch 回调接入 [AppNavigator]/ScreenModel;
 * 平台专属回调 (导入/分组/帮助/校验等) 通过 [PlatformCapabilityProviders] 委托或 shared 组件实现。
 */
@Composable
fun BookSourceManageRoute(
    entry: RouteEntry,
    navigator: AppNavigator,
    screenModelStore: ScreenModelStore,
) {
    // resolveFilter 所需平台字符串 (对齐 app 端 R.string 比对)
    val strEnabled = stringResource(Res.string.enabled)
    val strDisabled = stringResource(Res.string.disabled)
    val strNeedLogin = stringResource(Res.string.need_login)
    val strNoGroup = stringResource(Res.string.no_group)
    val strEnabledExplore = stringResource(Res.string.enabled_explore)
    val strDisabledExplore = stringResource(Res.string.disabled_explore)

    // 批量栏 SelectAction 文案 (预取, 供 onSelectActions 构建)
    val strEnableSelection = stringResource(Res.string.enable_selection)
    val strDisableSelection = stringResource(Res.string.disable_selection)
    val strAddGroup = stringResource(Res.string.add_group)
    val strRemoveGroup = stringResource(Res.string.remove_group)
    val strEnableExplore = stringResource(Res.string.enable_explore)
    val strDisableExplore = stringResource(Res.string.disable_explore)
    val strSelectionToTop = stringResource(Res.string.selection_to_top)
    val strSelectionToBottom = stringResource(Res.string.selection_to_bottom)
    val strExportSelection = stringResource(Res.string.export_selection)
    val strShareSelectedSource = stringResource(Res.string.share_selected_source)
    val strCheckSelectSource = stringResource(Res.string.check_select_source)
    val strCheckSelectedInterval = stringResource(Res.string.check_selected_interval)

    val screenModel = screenModelStore.getOrCreateTyped(entry) {
        BookSourceScreenModel(
            resolveFilter = { searchKey ->
                when {
                    searchKey.isEmpty() -> SourceFilter.All
                    searchKey == strEnabled -> SourceFilter.Enabled
                    searchKey == strDisabled -> SourceFilter.Disabled
                    searchKey == strNeedLogin -> SourceFilter.NeedLogin
                    searchKey == strNoGroup -> SourceFilter.NoGroup
                    searchKey == strEnabledExplore -> SourceFilter.EnabledExplore
                    searchKey == strDisabledExplore -> SourceFilter.DisabledExplore
                    searchKey.startsWith("group:") ->
                        SourceFilter.Group(searchKey.substringAfter("group:"))

                    else -> SourceFilter.Search(searchKey)
                }
            },
        )
    }

    val state by screenModel.state.collectAsState()
    val scope = rememberCoroutineScope()
    val listState = rememberLazyGridState()

    // 搜索态下返回先清空关键字 (对照 app 端 finish(): query 非空时 setQuery("", true));
    // 非栈顶时不拦截, 栈内页面全程留在 Composition
    val backStack by navigator.backStack.collectAsState()
    val isTopEntry = backStack.lastOrNull()?.id == entry.id
    AppBackHandler(enabled = isTopEntry && state.searchKey.isNotEmpty()) {
        screenModel.dispatch(BookSourceUiEvent.Search(""))
    }

    // 对话框状态 (对照 app 端 Activity 内 showDialogFragment 调用)
    var showUrlInput by remember { mutableStateOf(false) }
    var importVm by remember { mutableStateOf<ImportBookSourceViewModelShared?>(null) }
    var showImportDialog by remember { mutableStateOf(false) }
    // 导入失败 / 解析出 0 条的提示文案, 显示在对话框内 (对照原版 ImportBookSourceDialog 的 tv_msg)
    var importError by remember { mutableStateOf<String?>(null) }
    val strWrongFormat = stringResource(Res.string.wrong_format)
    // 删除确认对话框 (对照 app 端 del / delSelection 内 alert)
    var delTarget by remember { mutableStateOf<BookSourcePart?>(null) }
    var showDelSelection by remember { mutableStateOf(false) }
    // 书源分组管理对话框 (对照 app 端 GroupManageDialog; 管理 BookSource.bookSourceGroup, 非书架 BookGroup)
    var showGroupManage by remember { mutableStateOf(false) }

    // ---- 书源体检 ----
    // 配置面板 → 校验服务 → 结果面板。pendingCheckIds 只记本轮实际送检的源, 结果不掺历史失效源。
    var healthConfigVisible by remember { mutableStateOf(false) }
    var healthAllCount by remember { mutableStateOf(0) }
    var healthResult by remember { mutableStateOf<SourceHealthResult?>(null) }
    // 结果对象保留到下一轮体检, 面板显隐单独一份: 禁用后面板要关, 但 toast/撤销仍要用本轮数量
    var healthResultVisible by remember { mutableStateOf(false) }
    var pendingCheckIds by remember { mutableStateOf<Set<String>>(emptySet()) }
    var pendingCheckQuick by remember { mutableStateOf(false) }
    var showHealthDeleteConfirm by remember { mutableStateOf(false) }
    // 最近一次批量禁用中原本启用的源; 撤销只恢复这一批, 不碰本来就禁用的源
    var undoDisabledParts by remember { mutableStateOf<List<BookSourcePart>>(emptyList()) }

    val healthFailedCount = healthResult?.failed?.size ?: 0
    val strHealthEmptyScope = stringResource(Res.string.source_health_empty_scope)
    val strHealthDisabled = stringResource(Res.string.source_health_disabled, healthFailedCount)
    val strHealthDeleted = stringResource(Res.string.source_health_deleted, healthFailedCount)
    val strHealthRestored = stringResource(Res.string.source_health_restored, undoDisabledParts.size)
    val strHealthDisableFailed = stringResource(Res.string.source_health_disable_failed)
    val strHealthUndo = stringResource(Res.string.source_health_undo)
    val strHealthAlreadyDisabled = stringResource(Res.string.source_health_already_disabled)
    val strHealthChecking = stringResource(Res.string.source_health_checking)
    val strNo = stringResource(Res.string.no)

    // 校验进度文案 (对照 app 端 observeLiveBus: EventBus.CHECK_SOURCE)
    LaunchedEffect(Unit) {
        FlowBus.with(EventBus.CHECK_SOURCE).collect { event ->
            val msg = event as? String ?: return@collect
            screenModel.dispatch(BookSourceUiEvent.UpdateCheckSourceMsg(msg))
        }
    }

    // 校验期间保持屏幕常亮 (对照原版 checkSource okButton 首行 keepScreenOn(true) 与
    // observeEvent(CHECK_SOURCE_DONE) 的 keepScreenOn(false))。按 Debug.checkState.isChecking
    // 统一驱动: 四端该状态都由 CheckSourceShared 置位, 一处接线覆盖启动/完成/取消/重进恢复,
    // 不必各端自造释放时机 (安卓原先靠 CheckSourceService.onDestroy 发事件, 其余三端无该服务)
    val checking = Debug.checkState.collectAsState().value.isChecking
    LaunchedEffect(checking) {
        PlatformServiceProviders.get().window.setKeepScreenOn(checking)
    }

    // 校验完成 (对照 app 端 observeLiveBus: EventBus.CHECK_SOURCE_DONE)
    LaunchedEffect(Unit) {
        FlowBus.with(EventBus.CHECK_SOURCE_DONE).collect {
            screenModel.dispatch(BookSourceUiEvent.HideCheckSource)
            val checkedIds = pendingCheckIds
            val quick = pendingCheckQuick
            pendingCheckIds = emptySet()
            if (checkedIds.isNotEmpty()) {
                // 本轮参与校验的源从库里重新取: 校验过程中分组与启用态已落库, 直接读最新态
                scope.launch {
                    val all = withContext(IoDispatcher) {
                        AppDbProviders.get().bookSourceDao.flowAll().first()
                    }
                    val checked = all.filter { it.bookSourceUrl in checkedIds }
                    // 只统计本轮真正跑完的源: 中途取消时未排到的源没有终态文案, 不能算进"可用"
                    val messages = Debug.checkState.value.messages
                    val completed = checked.filter { part ->
                        messages[part.bookSourceUrl]?.let { msg ->
                            "校验成功" in msg || "校验失败" in msg
                        } == true
                    }
                    if (completed.isEmpty()) return@launch
                    healthResult = SourceHealthResult(
                        total = completed.size,
                        failed = completed.filter { it.isFailedSource() },
                        quick = quick,
                    )
                    healthResultVisible = true
                }
                return@collect
            }
            // 兜底: 校验不是本页发起的 (重进页面恢复/其它入口), 保留原有自动筛选行为
            val st = screenModel.state.value
            if (st.searchKey.isEmpty()) {
                // 失效源已统一带"失效"分组：用 group: 前缀按组精确筛选，避免模糊搜"失效"
                // 误命中名称/URL 含"失效"的源；筛选后全选+删除即可一次性清掉。
                // 判定必须与筛选动作严格一致 (精确"失效"组): 旧版存量源的"网站失效"等分组
                // 不含独立"失效" token, group:失效 筛不出 —— 重新校验后才归入"失效"组
                if (st.groups.any { it == "失效" }) {
                    screenModel.dispatch(BookSourceUiEvent.Search("group:失效"))
                    Toasters.get().toast("发现有失效书源，已为您自动筛选！")
                    return@collect
                }
            }
        }
    }

    // 校验中重进本页时恢复 (对照 app 端 onActivityCreated 末尾 resumeCheckSource:
    // if (!Debug.isChecking) return 后 keepScreenOn + CheckSource.resume)。
    // 必须排在上面两个 collect 之后: FlowBus replay=0, 订阅要先于 resume 重发的进度事件;
    // 进度条由该事件点亮 (对照原版 checkSourceProgressView 默认 gone, 由 CHECK_SOURCE 置 visible)
    LaunchedEffect(Unit) {
        if (Debug.isChecking) {
            PlatformCapabilityProviders.get().resumeCheckSource()
        }
    }

    // 监听导入 VM 的成功/错误状态 (对照 ImportTargetDialog: 两条都要收, 错误也要弹对话框)
    LaunchedEffect(importVm) {
        val vm = importVm ?: return@LaunchedEffect
        kotlinx.coroutines.coroutineScope {
            launch {
                vm.successState.collect { count ->
                    importError = if (count == 0) strWrongFormat else null
                    showImportDialog = true
                }
            }
            launch {
                vm.errorState.collect { err ->
                    importError = err
                    showImportDialog = true
                }
            }
        }
    }

    // 书源编辑返回: 重新触发查询刷新源列表 (DB flow 本身响应式, 此处兜底)
    LaunchedEffect(Unit) {
        navigator.resultsFor(entry.id).filter { it.key == RouteResults.BOOK_SOURCE_EDIT }.collect {
            val key = screenModel.state.value.searchKey
            screenModel.dispatch(BookSourceUiEvent.Search(key))
        }
    }

    // dispatch 类接入 ScreenModel; 导航类走 navigator; 平台专属委托 PlatformCapabilityProviders
    val callbacks = remember(navigator, screenModel) {
        BookSourceListCallbacks(
            onBack = {
                // 对照 app 端 finish(): searchKey 非空时清空搜索, 空时退出
                val st = screenModel.state.value
                if (st.searchKey.isEmpty()) navigator.pop()
                else screenModel.dispatch(BookSourceUiEvent.Search(""))
            },
            onQueryChange = { screenModel.dispatch(BookSourceUiEvent.Search(it)) },
            onSortChange = { screenModel.dispatch(BookSourceUiEvent.SortChange(it)) },
            onToggleSortDesc = { screenModel.dispatch(BookSourceUiEvent.ToggleSortDesc) },
            onToggleGroupByDomain = { screenModel.dispatch(BookSourceUiEvent.ToggleGroupByDomain) },
            onToggleShowSourceIcon = { screenModel.dispatch(BookSourceUiEvent.ToggleShowSourceIcon) },
            onToggle = { item, checked ->
                screenModel.dispatch(BookSourceUiEvent.Toggle(item, checked))
            },
            onSelectAll = { screenModel.dispatch(BookSourceUiEvent.SelectAll(it)) },
            onRevertSelection = { screenModel.dispatch(BookSourceUiEvent.RevertSelection) },
            onMove = { from, to -> screenModel.dispatch(BookSourceUiEvent.Move(from, to)) },
            onPersistOrder = { screenModel.dispatch(BookSourceUiEvent.PersistOrder) },
            onEdit = { part ->
                navigator.push(
                    AppRoute.BookSourceEdit(part.bookSourceUrl),
                    RouteResults.BOOK_SOURCE_EDIT
                )
            },
            onEnable = { enabled, item ->
                screenModel.dispatch(
                    BookSourceUiEvent.Enable(
                        item,
                        enabled
                    )
                )
            },
            onEnableExplore = { enabled, item ->
                screenModel.dispatch(
                    BookSourceUiEvent.EnableExplore(
                        item,
                        enabled
                    )
                )
            },
            onToTop = { screenModel.dispatch(BookSourceUiEvent.ToTop(it)) },
            onToBottom = { screenModel.dispatch(BookSourceUiEvent.ToBottom(it)) },
            // 对齐原版 searchBook: 带 SearchScope(part) 源范围进搜索页
            onSearchBook = { part ->
                navigator.push(AppRoute.Search(searchScope = SearchScope(part).toString()))
            },
            onLogin = { part ->
                // 统一登录入口 (对照原 BookSourceAdapter: getBookSource()?.showLoginDialog()):
                // 源对象由 showSourceLogin 内部按 url 查库, URL 登录直开全屏 WebView;
                // 插件虚拟源在 dispatchSourceLogin 内部分流: 登录 = 归属扩展自带设置
                showSourceLogin(part.bookSourceUrl)
            },
            onDel = { delTarget = it },
            onDelSelection = { showDelSelection = true },
            onCancelCheckSource = { PlatformCapabilityProviders.get().cancelCheckSource() },
            onSourceHealthCheck = {
                scope.launch {
                    healthAllCount = withContext(IoDispatcher) {
                        AppDbProviders.get().bookSourceDao.flowAll().first().size
                    }
                    healthConfigVisible = true
                }
            },
            onAddBookSource = { PlatformCapabilityProviders.get().addBookSource() },
            onImportLocal = {
                // 对照 ReplaceRuleRoute onImportLocal: 文件选择器 + ImportBookSourceViewModelShared
                val services = PlatformServiceProviders.get()
                scope.launch {
                    val path = withContext(IoDispatcher) {
                        services.files.pickFile(com.langhuan.reader.ui.root.FileFilter.Text)
                    } ?: return@launch
                    val text = withContext(IoDispatcher) { BackupFileOps.readText(path) }
                    val vm = ImportBookSourceViewModelShared(scope)
                    importVm = vm
                    vm.importSource(text)
                }
            },
            onImportOnline = { showUrlInput = true },
            onGroupManage = { showGroupManage = true },
            onSelectActions = {
                // 对照 app 端 selectActions(): 12 个 SelectAction
                listOf(
                    SelectAction(strEnableSelection) {
                        screenModel.dispatch(BookSourceUiEvent.EnableSelection(true))
                    },
                    SelectAction(strDisableSelection) {
                        screenModel.dispatch(BookSourceUiEvent.EnableSelection(false))
                    },
                    SelectAction(strAddGroup) {
                        PlatformCapabilityProviders.get()
                            .selectionAddToGroups(screenModel.selection())
                    },
                    SelectAction(strRemoveGroup) {
                        PlatformCapabilityProviders.get()
                            .selectionRemoveFromGroups(screenModel.selection())
                    },
                    SelectAction(strEnableExplore) {
                        screenModel.dispatch(BookSourceUiEvent.EnableSelectExplore)
                    },
                    SelectAction(strDisableExplore) {
                        screenModel.dispatch(BookSourceUiEvent.DisableSelectExplore)
                    },
                    SelectAction(strSelectionToTop) {
                        screenModel.dispatch(BookSourceUiEvent.SelectionToTop)
                    },
                    SelectAction(strSelectionToBottom) {
                        screenModel.dispatch(BookSourceUiEvent.SelectionToBottom)
                    },
                    SelectAction(strExportSelection) {
                        PlatformCapabilityProviders.get().exportBookSourceSelection(
                            selection = screenModel.selection(),
                            allCount = screenModel.state.value.sources.size,
                            sortAscending = screenModel.state.value.sortAscending,
                            sort = screenModel.state.value.sort,
                        )
                    },
                    SelectAction(strShareSelectedSource) {
                        PlatformCapabilityProviders.get().shareBookSourceSelection(
                            selection = screenModel.selection(),
                            allCount = screenModel.state.value.sources.size,
                            sortAscending = screenModel.state.value.sortAscending,
                            sort = screenModel.state.value.sort,
                        )
                    },
                    SelectAction(strCheckSelectSource) {
                        val selection = screenModel.selection()
                        // 记下本轮送检范围, 完成时按同一批源出结果; 取消关键词框不会发完成事件
                        pendingCheckIds = selection.map { it.bookSourceUrl }.toSet()
                        pendingCheckQuick = false
                        PlatformCapabilityProviders.get().checkBookSource(selection)
                    },
                    SelectAction(strCheckSelectedInterval) {
                        screenModel.dispatch(BookSourceUiEvent.CheckSelectedInterval)
                    },
                )
            },
            getSourceHost = { screenModel.getSourceHost(it) },
        )
    }

    BookSourceListScreen(
        state = state,
        callbacks = callbacks,
        listState = listState,
    )

    // 在线导入 URL 输入对话框 (对照 app 端 showImportDialog)
    if (showUrlInput) {
        OnlineImportUrlDialog(
            recordKey = "bookSourceRecordKey",
            onConfirm = { url ->
                showUrlInput = false
                val vm = ImportBookSourceViewModelShared(scope)
                importVm = vm
                vm.importSource(url)
            },
            onDismiss = { showUrlInput = false },
        )
    }

    // 书源勾选导入对话框 (对照 app 端 ImportBookSourceDialog)
    importVm?.let { vm ->
        if (showImportDialog) {
            ImportBookSourceItemsDialog(
                vm = vm,
                onDismiss = {
                    showImportDialog = false
                    importVm = null
                    importError = null
                },
                onImported = {
                    showImportDialog = false
                    importVm = null
                    importError = null
                },
                errorText = importError,
            )
        }
    }

    // 单项删除确认
    delTarget?.let { part ->
        AppAlertDialog(
            onDismissRequest = { delTarget = null },
            title = stringResource(Res.string.delete_source),
            message = part.bookSourceName,
            okButton = AlertButton(stringResource(Res.string.delete)) {
                screenModel.dispatch(BookSourceUiEvent.Del(part))
            },
            cancelButton = AlertButton(stringResource(Res.string.cancel)),
        )
    }

    // 批量删除确认
    if (showDelSelection) {
        AppAlertDialog(
            onDismissRequest = { showDelSelection = false },
            title = stringResource(Res.string.delete_selected_source),
            okButton = AlertButton(stringResource(Res.string.delete)) {
                screenModel.dispatch(BookSourceUiEvent.DelSelection)
            },
            cancelButton = AlertButton(stringResource(Res.string.cancel)),
        )
    }

    // ---- 书源体检面板 ----
    if (healthConfigVisible) {
        SourceHealthCheckSheet(
            allCount = healthAllCount,
            currentCount = state.sources.size,
            keyword = CheckSourceShared.keyword,
            defaultScope = if (state.searchKey.isEmpty()) SourceHealthScope.All else SourceHealthScope.Current,
            onDismiss = { healthConfigVisible = false },
            onStart = start@{ healthScope, onlyEnabled, quick, keyword ->
                if (Debug.isChecking) {
                    Toasters.get().toast(strHealthChecking)
                    return@start
                }
                healthConfigVisible = false
                scope.launch {
                    val all = withContext(IoDispatcher) {
                        AppDbProviders.get().bookSourceDao.flowAll().first()
                    }
                    val base = if (healthScope == SourceHealthScope.All) all else screenModel.state.value.sources
                    val sources = base.filter { !onlyEnabled || it.enabled }
                    if (sources.isEmpty()) {
                        Toasters.get().toast(strHealthEmptyScope)
                        return@launch
                    }
                    // 新一轮体检重置上一轮结果与撤销批次
                    healthResult = null
                    healthResultVisible = false
                    undoDisabledParts = emptyList()
                    pendingCheckIds = sources.map { it.bookSourceUrl }.toSet()
                    pendingCheckQuick = quick
                    CheckSourceShared.keyword = keyword
                    CheckSourceShared.beginHealthCheck(quick)
                    PlatformCapabilityProviders.get().startCheckBookSource(
                        sources.map { it.bookSourceUrl }
                    )
                }
            },
        )
    }

    if (healthResultVisible) {
        val result = healthResult
        if (result != null) {
            SourceHealthResultSheet(
                result = result,
                onDismiss = { healthResultVisible = false },
                onViewFailed = {
                    healthResultVisible = false
                    screenModel.dispatch(BookSourceUiEvent.Search("group:失效"))
                },
                onExportFailed = {
                    PlatformCapabilityProviders.get().exportBookSourceSelection(
                        selection = result.failed,
                        allCount = result.total,
                        sortAscending = state.sortAscending,
                        sort = state.sort,
                    )
                },
                onDisableFailed = {
                    val enabledOnes = result.failed.filter { it.enabled }
                    screenModel.dispatch(BookSourceUiEvent.EnableSources(result.failed, false))
                    undoDisabledParts = enabledOnes
                    healthResultVisible = false
                    Toasters.get().toast(
                        if (enabledOnes.isEmpty()) strHealthAlreadyDisabled else strHealthDisabled
                    )
                },
                onDeleteFailed = { showHealthDeleteConfirm = true },
            )
        }
    }

    if (showHealthDeleteConfirm) {
        val result = healthResult
        if (result != null) {
            SourceHealthDeleteConfirmDialog(
                failedCount = result.failed.size,
                onConfirm = {
                    screenModel.dispatch(BookSourceUiEvent.DeleteSources(result.failed))
                    showHealthDeleteConfirm = false
                    healthResultVisible = false
                    undoDisabledParts = emptyList()
                    Toasters.get().toast(strHealthDeleted)
                },
                onDismiss = { showHealthDeleteConfirm = false },
            )
        }
    }

    // 禁用后给一次明确的撤销机会; 关闭即放弃 (之后仍可在列表里手动启用)
    if (undoDisabledParts.isNotEmpty()) {
        AppAlertDialog(
            onDismissRequest = { undoDisabledParts = emptyList() },
            title = strHealthDisableFailed,
            message = strHealthDisabled,
            okButton = AlertButton(strHealthUndo) {
                val parts = undoDisabledParts
                screenModel.dispatch(BookSourceUiEvent.EnableSources(parts, true))
                undoDisabledParts = emptyList()
                Toasters.get().toast(strHealthRestored)
            },
            cancelButton = AlertButton(strNo) {
                undoDisabledParts = emptyList()
            },
        )
    }

    // 书源分组管理 (对照 app 端 showDialogFragment<GroupManageDialog>)
    if (showGroupManage) {
        BookSourceGroupManageDialog(onDismiss = { showGroupManage = false })
    }
}
