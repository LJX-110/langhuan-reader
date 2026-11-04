package com.langhuan.engine

import io.legado.app.help.config.AppConfigAccessor

/** facade 版 AppConfigAccessor：安全默认值（与 runner/桌面口径一致）。 */
class DefaultAppConfig : AppConfigAccessor {

    private var tocCountWordsValue = true
    private var tocUiUseReplaceValue = false
    override val tocCountWords: Boolean get() = tocCountWordsValue
    override fun setTocCountWords(value: Boolean) {
        tocCountWordsValue = value
    }

    override val tocUiUseReplace: Boolean get() = tocUiUseReplaceValue
    override fun setTocUiUseReplace(value: Boolean) {
        tocUiUseReplaceValue = value
    }

    override val threadCount: Int = 8

    override var chineseConverterType: Int = 0

    override val replaceEnableDefault: Boolean = true
    override val enableReadRecord: Boolean = true

    override val bookshelfSort: Int = 0
    override val bookshelfLayout: Int = 0
    override val bookshelfCoverHeight: Int = 120
    override val bookshelfGridWidth: Int = 120
    override val showUnread: Boolean = true
    override val bookshelfListShowKind: Boolean = false
    override val bookshelfListShowIntro: Boolean = false
    override val bookshelfListIntroLines: Int = 2
    override val bookshelfShowGroupCount: Boolean = true
    override val bookshelfFixedWidthMode: Boolean = false
    override val showLastUpdateTime: Boolean = false
    override val saveTabPosition: Int = 0
    override val bookExportFileName: String = ""
    override val episodeExportFileName: String = ""
    override val bookGroupStyle: Int = 0
    override val autoRefreshBook: Boolean = false
    override val preDownloadNum: Int = 10

    override var changeSourceCheckAuthor: Boolean = true
    override var changeSourceLoadInfo: Boolean = true
    override var changeSourceLoadToc: Boolean = true
    override var changeSourceLoadWordCount: Boolean = true

    override var searchScope: String = ""
    override var searchGroup: String = ""
    override val searchLayout: Int = 1
    private var precisionSearchValue = false
    override val precisionSearch: Boolean get() = precisionSearchValue
    override fun setPrecisionSearch(value: Boolean) {
        precisionSearchValue = value
    }

    override val exportCharset: String = "UTF-8"

    override val webDavUrl: String = ""
    override val webDavAccount: String = ""
    override val webDavPassword: String = ""
    override val syncBookProgress: Boolean = true
    override val webDavDir: String = "legado"
    override val webDavDeviceName: String = ""

    private var ttsEngineValue = ""
    override val ttsEngine: String get() = ttsEngineValue
    override fun setTtsEngine(value: String?) {
        ttsEngineValue = value ?: ""
    }
    override val ttsSpeechRate: Int = 5
    override val ttsTimer: Int = 0
    override val audioPlayUseWakeLock: Boolean = false

    override val themeMode: String = "1"
    override val isNightTheme: Boolean = false
    override val isEInkMode: Boolean = false
    override val systemNightTheme: Boolean = false
    override val useDefaultCover: Boolean = false
    override val coverDrawBookName: Boolean = true
    override val coverDrawBookAuthor: Boolean = true

    override val bottomBarHeight: Int = 50
    override val bottomBarIconSize: Int = 24
    override val bottomBarLabelMode: Int = 0
    override val showHome: Boolean = true
    override val showDiscovery: Boolean = true
    override val bottomNavItemOrder: String = ""
    override val defaultHomePage: String = "bookshelf"

    override var importKeepName: Boolean = false
    override var importKeepGroup: Boolean = false
    override var importKeepEnable: Boolean = false
    override val localBookImportSort: Int = 0

    override val remoteServerId: Long = 0
    override val batchChangeSourceDelay: Int = 0
    override val webPort: Int = 1122
    private var bitmapCacheSizeValue = 50
    override val bitmapCacheSize: Int get() = bitmapCacheSizeValue
    override fun setBitmapCacheSize(value: Int) {
        bitmapCacheSizeValue = value
    }
    override val sourceEditMaxLine: Int = Int.MAX_VALUE
    override val welcomeShowTime: Int = 600
    override val devFeat: Boolean = false
    override val bookInfoHorizontalLayout: Boolean = false
    override val showAddToShelfAlert: Boolean = true
}
