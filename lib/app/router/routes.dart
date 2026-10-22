import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';

import 'route_handler.dart';

class Routes {
  // 路由管理
  static late FluroRouter router;

  static String root = '/'; // 根目录
  static String search = '/search';
  static String read = '/read';
  static String detail = '/detail';
  static String chapters = '/chapters';
  static String fontSet = '/fontSet';
  static String sortShelf = '/sortShelf';
  static String update = '/update';
  static String sources = '/sources';
  static String logs = '/logs';
  static String cache = '/cache';
  static String history = '/history';
  static String bookmarks = '/bookmarks';

  // 配置route
  static void configureRoutes(FluroRouter router) {
    // 未发现对应route

    router.define(root, handler: rootHandler);
    router.define(search, handler: searchHandler);
    router.define(read, handler: readHandler);
    router.define(detail, handler: detailHandler);
    router.define(chapters, handler: chaptersHandler);
    router.define(fontSet, handler: fontSetHandler);
    router.define(sortShelf, handler: sortShelfHandler);
    router.define(sources, handler: sourcesHandler);
    router.define(logs, handler: logsHandler);
    router.define(cache, handler: cacheHandler);
    router.define(history, handler: historyHandler);
    router.define(bookmarks, handler: bookmarksHandler);
  }

  // 对参数进行encode，解决参数中有特殊字符，影响fluro路由匹配
  static Future navigateTo(
    BuildContext context,
    String path, {
    Map<String, dynamic>? params,
    TransitionType transition = TransitionType.fadeIn,
    bool replace = false,
  }) {
    String query = "";

    if (params != null) {
      int index = 0;
      for (var key in params.keys) {
        var value = Uri.encodeComponent(params[key].toString());
        if (index == 0) {
          query = "?";
        } else {
          query = "$query&";
        }
        query += "$key=$value";
        index++;
      }
    }
    path = path + query;
    return router.navigateTo(
      context,
      path,
      transition: transition,
      replace: replace,
    );
  }
}
