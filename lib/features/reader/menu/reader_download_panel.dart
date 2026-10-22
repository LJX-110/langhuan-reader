import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/read_model.dart';

/// Offline cache actions shown under the "缓存" tab.
class ReaderDownloadPanel extends StatelessWidget {
  const ReaderDownloadPanel({
    super.key,
    required this.readModel,
    required this.chrome,
  });

  final ReadModel readModel;
  final ReaderChrome chrome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _filledOutlineBtn('从当前缓存', () {
              BotToast.showText(text: '从当前章节开始下载…');
              final book = readModel.book;
              if (book == null) return;
              readModel.downloadAll(book.chapterIndex);
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _filledOutlineBtn('全本缓存', () {
              BotToast.showText(text: '开始全本下载…');
              readModel.downloadAll(0);
            }),
          ),
        ],
      ),
    );
  }

  Widget _filledOutlineBtn(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: chrome.fg,
        side: BorderSide(color: chrome.divider),
        backgroundColor: chrome.chipBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
