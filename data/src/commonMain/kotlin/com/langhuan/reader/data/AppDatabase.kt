package com.langhuan.reader.data

import androidx.room3.AutoMigration
import androidx.room3.ColumnTypeConverters
import androidx.room3.ConstructedBy
import androidx.room3.Database
import androidx.room3.RoomDatabase
import androidx.room3.RoomDatabaseConstructor
import androidx.room3.TypeConverters
import com.langhuan.reader.data.dao.BookChapterDao
import com.langhuan.reader.data.dao.BookDao
import com.langhuan.reader.data.dao.BookGroupDao
import com.langhuan.reader.data.dao.BookSourceDao
import com.langhuan.reader.data.dao.BookmarkDao
import com.langhuan.reader.data.dao.CacheDao
import com.langhuan.reader.data.dao.CookieDao
import com.langhuan.reader.data.dao.DictRuleDao
import com.langhuan.reader.data.dao.HttpTTSDao
import com.langhuan.reader.data.dao.KeyboardAssistsDao
import com.langhuan.reader.data.dao.KeywordHighlightDao
import com.langhuan.reader.data.dao.ReadRecordDao
import com.langhuan.reader.data.dao.ReplaceRuleDao
import com.langhuan.reader.data.dao.RuleSubDao
import com.langhuan.reader.data.dao.SearchKeywordDao
import com.langhuan.reader.data.dao.ServerDao
import com.langhuan.reader.data.dao.TxtTocRuleDao
import com.langhuan.reader.data.entities.Book
import com.langhuan.reader.data.entities.BookChapter
import com.langhuan.reader.data.entities.BookGroup
import com.langhuan.reader.data.entities.BookSource
import com.langhuan.reader.data.entities.BookSourcePart
import com.langhuan.reader.data.entities.Bookmark
import com.langhuan.reader.data.entities.Cache
import com.langhuan.reader.data.entities.Cookie
import com.langhuan.reader.data.entities.DictRule
import com.langhuan.reader.data.entities.HttpTTS
import com.langhuan.reader.data.entities.KeyboardAssist
import com.langhuan.reader.data.entities.KeywordHighlight
import com.langhuan.reader.data.entities.ReadRecord
import com.langhuan.reader.data.entities.ReplaceRule
import com.langhuan.reader.data.entities.RuleSub
import com.langhuan.reader.data.entities.SearchKeyword
import com.langhuan.reader.data.entities.Server
import com.langhuan.reader.data.entities.TxtTocRule

/**
 * AppDatabase 主体下沉 commonMain。
 *
 * - @Database 注解 + abstract DAO 属性 + companion 常量 在 commonMain (平台无关)
 * - appDb 单例 + dbCallback 留 app 端 (依赖 appCtx + AndroidSQLiteConnection + Locale.CHINESE + DefaultData)
 * - DatabaseMigrations (80..83 手写 Migration) 在 commonMain, 各端 actual 只提供 Migration 子类
 *   (官方 room3 的 migrate 是 suspend, 鸿蒙 CPF fork 不是)
 */
@Database(
    version = 90,
    exportSchema = true,
    entities = [Book::class, BookGroup::class, BookSource::class, BookChapter::class,
        ReplaceRule::class, SearchKeyword::class, Cookie::class,
        Bookmark::class, TxtTocRule::class, ReadRecord::class,
        HttpTTS::class, Cache::class,
        RuleSub::class, DictRule::class, KeyboardAssist::class, Server::class,
        KeywordHighlight::class],
    views = [BookSourcePart::class],
    autoMigrations = [
        AutoMigration(from = 83, to = 84),
        AutoMigration(from = 84, to = 85, spec = Migration84To85::class),
        AutoMigration(from = 85, to = 86),
        AutoMigration(from = 86, to = 87),
        AutoMigration(from = 87, to = 88),
        AutoMigration(from = 88, to = 89),
        AutoMigration(from = 89, to = 90, spec = Migration89To90::class),
    ]
)
// DATABASE 作用域注册 Book.Converters: iOS/ohos KSP 处理 BookChapter.ForeignKey 跨实体解析时,
// 需在 Database 级可见 ReadConfig <-> String 转换链 (与 Book 实体上的 ENTITY 作用域双重注册,
// 详见 Book.kt 顶部注释)。缺此注册会导致 iOS/ohos KSP 报 ReadConfig 类型链解析失败。
// 鸿蒙 fork (alpha01 API) KSP 只认 TypeConverters 旧名, 与 ColumnTypeConverters 并存双注册。
@ColumnTypeConverters(Book.Converters::class)
// 旧名同步注册: 缺此注册时 fork KSP 看不到 DATABASE 作用域转换链, DAO 里以 ReadConfig 作
// @Query 参数的 PATCH 方法 (如 updateReadConfig) 会报"参数类型无法转换为数据库列"
@TypeConverters(Book.Converters::class)
// 非 Android 平台 (iOS/desktop/鸿蒙) Room3 要求显式 @ConstructedBy 提供实例工厂
@ConstructedBy(AppDatabaseConstructor::class)
abstract class AppDatabase : RoomDatabase() {

    abstract val bookDao: BookDao
    abstract val bookGroupDao: BookGroupDao
    abstract val bookSourceDao: BookSourceDao
    abstract val bookChapterDao: BookChapterDao
    abstract val replaceRuleDao: ReplaceRuleDao
    abstract val searchKeywordDao: SearchKeywordDao
    abstract val bookmarkDao: BookmarkDao
    abstract val cookieDao: CookieDao
    abstract val txtTocRuleDao: TxtTocRuleDao
    abstract val readRecordDao: ReadRecordDao
    abstract val httpTTSDao: HttpTTSDao
    abstract val cacheDao: CacheDao
    abstract val ruleSubDao: RuleSubDao
    abstract val dictRuleDao: DictRuleDao
    abstract val keyboardAssistsDao: KeyboardAssistsDao
    abstract val keywordHighlightDao: KeywordHighlightDao
    abstract val serverDao: ServerDao

    companion object {

        const val DATABASE_NAME = "legado.db"

        const val BOOK_TABLE_NAME = "books"
        const val BOOK_SOURCE_TABLE_NAME = "book_sources"
    }

}

// Room3 编译期生成 actual (KSP expect/actual 约定), 各平台源集无需手写
@Suppress("KotlinNoActualForExpect")
expect object AppDatabaseConstructor : RoomDatabaseConstructor<AppDatabase> {
    override fun initialize(): AppDatabase
}
