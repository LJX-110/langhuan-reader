import 'dart:convert' as convert;

import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/features/detail/book_detail.dart';
import 'package:langhuan/features/shelf/book_shelf.dart';
import 'package:langhuan/features/reader/chapter_view.dart';
import 'package:langhuan/features/reader/read_book.dart';
import 'package:langhuan/features/search/search_page.dart';
import 'package:langhuan/features/shelf/sort_shelf.dart';
import 'package:langhuan/features/sources/source_manage_page.dart';
import 'package:langhuan/features/settings/cache_manager.dart';
import 'package:langhuan/features/settings/font_set_page.dart';
import 'package:langhuan/features/settings/log_viewer_page.dart';
import 'package:langhuan/features/profile/history_page.dart';
import 'package:langhuan/features/profile/bookmarks_page.dart';
import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';

// 根目录
var rootHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    return BookShelf();
  },
);
// 根目录

// 设置页 - 示例：不传参数
var searchHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    String type = (params['type']![0]);
    String name = (params['name']![0]);
    return Search(type, name);
  },
);
var fontSetHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    return FontSet();
  },
);

var sortShelfHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    return SortShelf();
  },
);

var historyHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    return const HistoryPage();
  },
);

var bookmarksHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    return const BookmarksPage();
  },
);

// 示例：传多个model参数
var readHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    Book bookInfo = Book.fromJson(convert.jsonDecode(params['read']![0]));
    return ReadBook(bookInfo);
  },
);
var chaptersHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    return ChapterView();
  },
);

var detailHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    BookInfo bookInfo = BookInfo.fromJson(
      convert.jsonDecode(params['detail']![0]),
    );

    return BookDetail(bookInfo);
  },
);

var sourcesHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    return SourceManagePage();
  },
);

var logsHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    return const LogViewer();
  },
);

var cacheHandler = Handler(
  handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
    return const CacheManager();
  },
);
