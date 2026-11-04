package io.legado.runner

import io.legado.app.data.AppDatabase
import io.legado.app.data.AppDatabaseProvider
import io.legado.app.data.AppDatabaseProviders
import io.legado.app.data.AppDbAccessor
import io.legado.app.data.BundledDatabaseDriver
import io.legado.app.data.runInImmediateTransaction

/** runner 版 AppDatabase provider：委托 data jvmMain 的 BundledDatabaseDriver（真实 Room）。 */
class RunnerAppDatabaseProvider(
    private val driver: BundledDatabaseDriver,
) : AppDatabaseProvider {
    override val appDb: AppDatabase get() = driver.appDatabase
}

/** runner 版 AppDbAccessor：转发全部 DAO（与桌面 DesktopAppDbAccessor 同构）。 */
class RunnerAppDbAccessor : AppDbAccessor {
    private val appDb: AppDatabase get() = AppDatabaseProviders.get().appDb

    override val bookDao get() = appDb.bookDao
    override val bookSourceDao get() = appDb.bookSourceDao
    override val bookChapterDao get() = appDb.bookChapterDao
    override val bookGroupDao get() = appDb.bookGroupDao
    override val keywordHighlightDao get() = appDb.keywordHighlightDao
    override val replaceRuleDao get() = appDb.replaceRuleDao
    override val txtTocRuleDao get() = appDb.txtTocRuleDao
    override val dictRuleDao get() = appDb.dictRuleDao
    override val readRecordDao get() = appDb.readRecordDao
    override val serverDao get() = appDb.serverDao
    override val sourceFilterRuleDao get() = appDb.sourceFilterRuleDao
    override val httpTTSDao get() = appDb.httpTTSDao
    override val cacheDao get() = appDb.cacheDao
    override val cookieDao get() = appDb.cookieDao
    override val ruleSubDao get() = appDb.ruleSubDao
    override val bookmarkDao get() = appDb.bookmarkDao
    override val searchKeywordDao get() = appDb.searchKeywordDao
    override val keyboardAssistsDao get() = appDb.keyboardAssistsDao

    override suspend fun <R> runInTransactionSuspending(block: suspend () -> R): R {
        return appDb.runInImmediateTransaction(block)
    }
}
