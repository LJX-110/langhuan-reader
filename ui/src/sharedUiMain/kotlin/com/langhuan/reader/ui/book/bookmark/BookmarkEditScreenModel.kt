package com.langhuan.reader.ui.book.bookmark

import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.Bookmark
import com.langhuan.reader.help.coroutine.Coroutine
import com.langhuan.reader.help.coroutine.IoDispatcher
import com.langhuan.reader.help.coroutine.printStackTraceOnDebug
import com.langhuan.reader.help.toast.Toasters
import com.langhuan.reader.ui.root.ScreenModel
import com.langhuan.reader.ui.root.screenModelScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 书签编辑对话框 shared ScreenModel：托管 [BookmarkEditUiState]，
 * 处理 bookText/content 编辑态与保存/删除入库，通过 [dispatch] 驱动。
 */
class BookmarkEditScreenModel : ScreenModel {

    private val scope = screenModelScope("书签编辑")

    private val _state = MutableStateFlow(BookmarkEditUiState())
    val state: StateFlow<BookmarkEditUiState> = _state.asStateFlow()

    fun dispatch(event: BookmarkEditUiEvent) {
        when (event) {
            is BookmarkEditUiEvent.Init -> {
                _state.value = BookmarkEditUiState(
                    bookmark = event.bookmark,
                    bookText = event.bookmark.bookText,
                    content = event.bookmark.content,
                    showDelete = event.editPos >= 0,
                )
            }

            is BookmarkEditUiEvent.UpdateBookText -> {
                _state.value = _state.value.copy(bookText = event.text)
            }

            is BookmarkEditUiEvent.UpdateContent -> {
                _state.value = _state.value.copy(content = event.text)
            }

            is BookmarkEditUiEvent.Save -> {
                val bookmark = _state.value.bookmark ?: return
                bookmark.bookText = _state.value.bookText
                bookmark.content = _state.value.content
                Coroutine.async(scope = scope, context = IoDispatcher) {
                    AppDbProviders.get().bookmarkDao.insert(bookmark)
                }.onSuccess {
                    event.onSuccess()
                }.onError {
                    Toasters.get().toast("保存书签失败")
                    it.printStackTraceOnDebug()
                }
            }

            is BookmarkEditUiEvent.Delete -> {
                val bookmark = _state.value.bookmark ?: return
                Coroutine.async(scope = scope, context = IoDispatcher) {
                    AppDbProviders.get().bookmarkDao.delete(bookmark)
                }.onSuccess {
                    event.onSuccess()
                }.onError {
                    Toasters.get().toast("删除书签失败")
                    it.printStackTraceOnDebug()
                }
            }
        }
    }

    override fun onCleared() {
        scope.cancel()
    }
}

data class BookmarkEditUiState(
    val bookmark: Bookmark? = null,
    val bookText: String = "",
    val content: String = "",
    val showDelete: Boolean = false,
)

sealed interface BookmarkEditUiEvent {
    data class Init(val bookmark: Bookmark, val editPos: Int) : BookmarkEditUiEvent

    data class UpdateBookText(val text: String) : BookmarkEditUiEvent

    data class UpdateContent(val text: String) : BookmarkEditUiEvent

    data class Save(val onSuccess: () -> Unit) : BookmarkEditUiEvent

    data class Delete(val onSuccess: () -> Unit) : BookmarkEditUiEvent
}
