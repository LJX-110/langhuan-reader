import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/read_model.dart';

class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.readModel,
    required this.chrome,
    required this.onSearch,
    required this.bookmarked,
    required this.onBookmark,
    required this.onExit,
  });

  final ReadModel readModel;
  final ReaderChrome chrome;
  final VoidCallback onSearch;
  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onExit;

  /// Open the source-site page in an external browser.
  /// Prefer current chapter URL; fall back to book detail / toc.
  Future<void> _openOriginalPage(BuildContext context) async {
    final b = readModel.book;
    if (b == null) {
      BotToast.showText(text: '暂无书籍信息');
      return;
    }
    final chapters = readModel.chapters;
    final idx = b.chapterIndex;
    String raw = '';
    if (idx >= 0 && idx < chapters.length) {
      raw = chapters[idx].url.trim();
    }
    if (raw.isEmpty) raw = b.bookUrl.trim();
    if (raw.isEmpty) raw = b.tocUrl.trim();
    if (raw.isEmpty) {
      BotToast.showText(text: '暂无原网页地址');
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      BotToast.showText(text: '原网页地址无效');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      BotToast.showText(text: '无法打开浏览器');
    }
  }

  void _openDetail(BuildContext context) {
    final b = readModel.book;
    if (b == null) return;
    final info = BookInfo(
      id: b.id,
      name: b.name,
      author: b.author,
      coverUrl: b.coverUrl,
      category: b.category,
      description: b.description,
      latestChapter: b.latestChapter,
      updatedAt: b.updatedAt,
      sourceUrl: b.sourceUrl,
      bookUrl: b.bookUrl,
      originName: b.originName,
      tocUrl: b.tocUrl,
    );
    Routes.navigateTo(
      context,
      Routes.detail,
      params: {'detail': jsonEncode(info)},
      replace: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookName = readModel.book?.name ?? '';
    final chapter = readModel.book?.readingChapter.trim() ?? '';
    final pageChapter = readModel.curPage?.chapterName.trim() ?? '';
    final chapterName = (pageChapter.isEmpty || pageChapter == '加载中')
        ? chapter
        : pageChapter;

    // Color outside SafeArea so the bar fills status-bar / notch; content
    // still respects the inset. Otherwise the page text peeks through above.
    return Container(
      decoration: BoxDecoration(
        color: chrome.panelBg,
        boxShadow: AppShadows.softBar,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: '返回',
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: chrome.fg,
                ),
                onPressed: onExit,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bookName.isNotEmpty)
                      Text(
                        bookName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: chrome.muted,
                        ),
                      ),
                    Text(
                      chapterName.isEmpty ? '正文' : chapterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        height: 1.3,
                        color: chrome.fg,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: bookmarked ? '取消书签' : '添加书签',
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 22,
                  color: chrome.fg,
                ),
                onPressed: onBookmark,
              ),
              IconButton(
                tooltip: '查找',
                icon: Icon(Icons.search, size: 22, color: chrome.fg),
                onPressed: onSearch,
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                icon: Icon(Icons.more_vert, size: 22, color: chrome.fg),
                onSelected: (value) {
                  if (value == 'browser') _openOriginalPage(context);
                  if (value == 'detail') _openDetail(context);
                  if (value == 'reload') readModel.reloadCurrentPage();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'reload', child: Text('刷新正文')),
                  PopupMenuItem(value: 'browser', child: Text('打开原网页')),
                  PopupMenuItem(value: 'detail', child: Text('书籍详情')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
