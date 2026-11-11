package com.langhuan.reader.ui.root

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.langhuan.reader.ui.route.AboutRoute
import com.langhuan.reader.ui.route.AudioPlayRoute
import com.langhuan.reader.ui.route.BackupConfigRoute
import com.langhuan.reader.ui.route.BookInfoEditRoute
import com.langhuan.reader.ui.route.BookInfoRoute
import com.langhuan.reader.ui.route.BookSourceDebugRoute
import com.langhuan.reader.ui.route.BookSourceEditRoute
import com.langhuan.reader.ui.route.BookSourceManageRoute
import com.langhuan.reader.ui.route.BookmarkRoute
import com.langhuan.reader.ui.route.BookshelfManageRoute
import com.langhuan.reader.ui.route.DictRuleRoute
import com.langhuan.reader.ui.route.ExploreShowRoute
import com.langhuan.reader.ui.route.ImportBookRoute
import com.langhuan.reader.ui.route.MainRoute
import com.langhuan.reader.ui.route.MyConfigRoute
import com.langhuan.reader.ui.route.ReadRecordRoute
import com.langhuan.reader.ui.route.ReaderRoute
import com.langhuan.reader.ui.route.RemoteBookRoute
import com.langhuan.reader.ui.route.ReplaceEditRoute
import com.langhuan.reader.ui.route.ReplaceRuleRoute
import com.langhuan.reader.ui.route.ReviewListRoute
import com.langhuan.reader.ui.route.KeywordHighlightRoute
import com.langhuan.reader.ui.route.SearchContentRoute
import com.langhuan.reader.ui.route.SearchRoute
import com.langhuan.reader.ui.debug.DialogPreviewScreen
import com.langhuan.reader.ui.route.SourceFilterRuleRoute
import com.langhuan.reader.ui.route.TocRoute
import com.langhuan.reader.ui.route.TxtTocRuleRoute
import com.langhuan.reader.ui.route.WebViewRoute

/**
 * shared 统一路由内容分发 (零薄壳方案)。
 *
 * 按 [RouteEntry.route] 类型调用 `com.langhuan.reader.ui.route` 下对应的 `XxxRoute`,
 * 由 Route 绑定 ScreenModel 并渲染 shared Screen。路由分发由 shared 统一接管,
 * 不再保留平台平行页面分发薄壳。
 */
@Composable
fun RouteContent(
    entry: RouteEntry,
    navigator: AppNavigator,
    screenModelStore: ScreenModelStore,
): Boolean {
    return when (val route = entry.route) {
        // ===== 已下沉路由 (调用 shared XxxRoute, 返回 true) =====
        is AppRoute.About -> {
            AboutRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.BackupConfig -> {
            BackupConfigRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.BookInfo -> {
            BookInfoRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.BookInfoEdit -> {
            BookInfoEditRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.BookSourceDebug -> {
            BookSourceDebugRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.BookSourceEdit -> {
            BookSourceEditRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.BookSourceManage -> {
            BookSourceManageRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.Bookmark -> {
            BookmarkRoute(entry, navigator, screenModelStore)
            true
        }
        is AppRoute.BookshelfManage -> {
            BookshelfManageRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.DialogPreview -> {
            DialogPreviewScreen(navigator)
            true
        }

        is AppRoute.DictRule -> {
            DictRuleRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.ExploreShow -> {
            ExploreShowRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.ExploreShowByUrl -> {
            ExploreShowRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.SourceSearchShow -> {
            ExploreShowRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.ImportBook -> {
            ImportBookRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.Main -> {
            // 深链导入 (壳/主界面内) 的对话框由 [DeepLinkImportHost] 挂载, 浮在书架之上;
            // 不因 pending 拆掉书架: 壳是透明的, 拆掉后透出的是纯色空容器而非主界面
            // (2026-10-11 实机取证后拍板修复)
            MainRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.MyConfig -> {
            MyConfigRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.ReadRecord -> {
            ReadRecordRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.RemoteBook -> {
            RemoteBookRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.ReplaceEdit -> {
            ReplaceEditRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.ReplaceRule -> {
            ReplaceRuleRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.Search -> {
            SearchRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.SearchContent -> {
            SearchContentRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.SourceFilterRule -> {
            SourceFilterRuleRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.KeywordHighlight -> {
            KeywordHighlightRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.Toc -> {
            TocRoute(entry, navigator)
            true
        }

        is AppRoute.TxtTocRule -> {
            TxtTocRuleRoute(entry, navigator, screenModelStore)
            true
        }

        // ===== 阅读、媒体与平台能力路由 =====
        is AppRoute.Reader -> {
            ReaderRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.AudioPlay -> {
            AudioPlayRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.ReviewList -> {
            ReviewListRoute(entry, navigator, screenModelStore)
            true
        }

        is AppRoute.WebView -> {
            WebViewRoute(entry, navigator, screenModelStore)
            true
        }
    }
}
