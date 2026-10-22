import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/reading_record.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/reading_history_repository.dart';
import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// Recently read books, newest first.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ReadingRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final records = await ReadingHistoryRepository.instance.recent();
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

  Future<void> _open(ReadingRecord record) async {
    final Book? book = await BookRepository.instance.getById(record.bookId);
    if (book == null) {
      BotToast.showText(text: '这本书已不在书架，无法继续阅读');
      return;
    }
    if (!mounted) return;
    Routes.navigateTo(
      context,
      Routes.read,
      params: {'read': jsonEncode(book.toJson())},
    );
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
        title: const Text('阅读记录'),
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
                    '还没有阅读记录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '打开一本书读几页，这里会记录上次读到的位置。',
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
                      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppDimens.coverRadius,
                            ),
                            child: PicWidget(
                              record.coverUrl,
                              width: 46,
                              height: 62,
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: primary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  record.progressLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _timeLabel(record.readAt),
                                  style: TextStyle(fontSize: 11, color: muted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: muted),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _timeLabel(int millis) {
    if (millis <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.month}-${d.day} $hh:$mm';
  }
}
