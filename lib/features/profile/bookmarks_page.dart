import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/bookmark_record.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/bookmark_repository.dart';
import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// All bookmarks, newest first.
class BookmarksPage extends StatefulWidget {
  const BookmarksPage({super.key});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  List<BookmarkRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final records = await BookmarkRepository.instance.allWithBook();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _open(BookmarkRecord record) async {
    final Book? book = await BookRepository.instance.getById(
      record.bookmark.bookId,
    );
    if (book == null) {
      BotToast.showText(text: '这本书已不在书架');
      return;
    }
    book
      ..chapterIndex = record.bookmark.chapterIndex
      ..pageIndex = record.bookmark.pageIndex;
    if (!mounted) return;
    Routes.navigateTo(
      context,
      Routes.read,
      params: {'read': jsonEncode(book.toJson())},
    );
  }

  Future<void> _delete(BookmarkRecord record) async {
    await BookmarkRepository.instance.remove(record.bookmark.id);
    if (!mounted) return;
    setState(() {
      _records = _records
          .where((e) => e.bookmark.id != record.bookmark.id)
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? AppColors.scaffoldDark : AppColors.paper;
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
    final line = dark ? AppColors.dividerDark : AppColors.divider;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('书签'),
        elevation: 0,
        backgroundColor: background,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 96, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '还没有书签',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '阅读时点顶栏的书签图标，可保存当前页。',
                    style: TextStyle(fontSize: 12, color: muted, height: 1.6),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _records.length,
              separatorBuilder: (_, _) => Divider(height: .5, color: line),
              itemBuilder: (context, i) {
                final record = _records[i];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _open(record),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimens.coverRadius,
                            ),
                            child: PicWidget(
                              record.coverUrl,
                              width: 42,
                              height: 58,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.bookName.isEmpty
                                      ? '未知书名'
                                      : record.bookName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppType.serif,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: primary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  [
                                    if (record.bookmark.chapterName.isNotEmpty)
                                      record.bookmark.chapterName,
                                    record.bookmark.pageLabel,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                                if (record.bookmark.excerpt.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    record.bookmark.excerpt,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '删除书签',
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: muted,
                            ),
                            onPressed: () => _delete(record),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
