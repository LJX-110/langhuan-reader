package com.langhuan.reader.ui.config

import androidx.room3.executeSQL
import androidx.room3.useWriterConnection
import com.langhuan.reader.data.AppDatabase
import com.langhuan.reader.data.AppDatabaseProviders
import com.langhuan.reader.data.AppDbProviders
import com.langhuan.reader.data.entities.ReadRecord
import com.langhuan.reader.help.FileUtilsCommon
import com.langhuan.reader.help.book.BookStorageProviders
import com.langhuan.reader.help.coroutine.IoDispatcher
import com.langhuan.reader.help.file.AppFilesDirs
import com.langhuan.reader.model.ActiveReadBookRegistry
import com.langhuan.reader.ui.config.ConfigActionsShared.clearCache
import com.langhuan.reader.ui.config.ConfigActionsShared.shrinkDatabase
import kotlinx.coroutines.withContext

/**
 * 其它设置页纯 Kotlin 动作下沉 (shared commonMain)。
 *
 * 对照 app 端 [com.langhuan.reader.ui.config.ConfigViewModel] 的 [clearCache] / [shrinkDatabase]:
 * 两者仅依赖 shared 已有的 Provider ([BookStorageProviders] / [AppFilesDirs] /
 * [AppDatabaseProviders] / [FileUtilsCommon]), 无 Android Context 依赖, 可下沉供全平台复用。
 *
 * Toast 提示由调用方 (sharedUiMain 路由) 在 suspend 返回后自行处理, 保持与
 * app 端 `execute {}.onSuccess { toastOnUi(...) }` 等价语义。
 *
 * 模式参考 [com.langhuan.reader.help.book.BookHelpShared] / [com.langhuan.reader.help.storage.BackupShared]。
 */
object ConfigActionsShared {

    /**
     * 清除缓存 (对照 app 端 `ConfigViewModel.clearCache`)。
     *
     * 1. 删除书籍章节缓存目录 (book_cache): 委托 [BookStorageProviders.get].clearCache()
     * 2. 删除应用内部缓存目录 (cacheDir): 委托 [FileUtilsCommon].delete
     * 3. 丢弃正在阅读那本书的内存章节 (同 [com.langhuan.reader.help.book.BookHelpShared.clearBookCache]:
     *    只删盘不清内存, 阅读页仍拿旧正文渲染)
     *
     * 成功后调用方应 toast `clear_cache_success`。
     */
    suspend fun clearCache() {
        withContext(IoDispatcher) {
            BookStorageProviders.get().clearCache()
            FileUtilsCommon.delete(AppFilesDirs.get().cacheDir)
            ActiveReadBookRegistry.current?.clearTextChapter()
        }
    }

    /**
     * 收缩数据库 (对照 app 端 `ConfigViewModel.shrinkDatabase`)。
     *
     * 1. 删除不在书架的书籍章节: `bookChapterDao.deleteNotShelfBookChapters()`
     * 2. 删除不在书架的书籍: `bookDao.deleteNotShelfBook()`
     * 3. 融合压缩阅读记录重叠会话: `compactReadRecords(appDb)`
     * 4. VACUUM 回收空间: `useWriterConnection { it.executeSQL("VACUUM") }`
     *
     * 成功后调用方应 toast `success`。
     */
    suspend fun shrinkDatabase() {
        withContext(IoDispatcher) {
            // VACUUM 需完整 Room API (useWriterConnection), 不走 AppDbProviders;
            // DAO 访问同理走同一 appDb 实例, 保持单入口
            val appDb = AppDatabaseProviders.get().appDb
            appDb.bookChapterDao.deleteNotShelfBookChapters()
            appDb.bookDao.deleteNotShelfBook()
            compactReadRecords(appDb)
            // 配置 SQLiteDriver 后 openHelper 不可用, 走 driver 连接执行
            // useWriterConnection 的 block 接收 Transactor (继承 PooledConnection)
            // PooledConnection.executeSQL 是 androidx.room3 的 suspend 扩展
            appDb.useWriterConnection { it.executeSQL("VACUUM") }
        }
    }

    /**
     * 压缩/合并 readRecord 表中的连续与重叠阅读会话 (1C 区间融合)。
     *
     * 消除频繁微切片积累的冗余行, 配合 VACUUM 释放页空间。
     */
    private suspend fun compactReadRecords(appDb: AppDatabase) {
        val records = appDb.readRecordDao.all()
        if (records.size <= 1) return
        val merged = ReadRecord.mergeIntervals(records)
        if (merged.size < records.size) {
            AppDbProviders.get().runInTransactionSuspending {
                appDb.readRecordDao.clear()
                appDb.readRecordDao.insert(*merged.toTypedArray())
            }
        }
    }
}
