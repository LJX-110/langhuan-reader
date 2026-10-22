import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/read_model.dart';

/// Chapter slider shown when the menu first opens.
class ReaderChapterPanel extends StatelessWidget {
  const ReaderChapterPanel({
    super.key,
    required this.readModel,
    required this.chrome,
    required this.onChanged,
  });

  final ReadModel readModel;
  final ReaderChrome chrome;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final chapters = readModel.chapters;
    final max = chapters.isEmpty ? 0.0 : (chapters.length - 1).toDouble();
    final index = readModel.book?.chapterIndex ?? 0;
    final cur = index.toDouble().clamp(0.0, max);
    final chapterName = index >= 0 && index < chapters.length
        ? chapters[index].title
        : '';

    Future<void> step(int delta) async {
      final book = readModel.book;
      if (book == null) return;
      final next = book.chapterIndex + delta;
      if (next < 0) {
        BotToast.showText(text: '已经是第一章');
        return;
      }
      if (next >= chapters.length) {
        BotToast.showText(text: '已经是最后一章');
        return;
      }
      book.chapterIndex = next;
      await readModel.openChapterAt(next, true);
      readModel.scheduleProgressSave(delay: Duration.zero);
      onChanged();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chapterName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                chapterName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: chrome.muted),
              ),
            ),
          Row(
            children: <Widget>[
              _miniTextBtn('上一章', () => step(-1)),
              Expanded(
                child: SliderTheme(
                  data: readerSliderTheme(context, chrome),
                  child: Slider(
                    value: cur,
                    max: max <= 0 ? 1 : max,
                    min: 0.0,
                    onChanged: max <= 0
                        ? null
                        : (newValue) {
                            readModel.book!.chapterIndex = newValue.round();
                            onChanged();
                          },
                    onChangeEnd: max <= 0
                        ? null
                        : (newValue) {
                            readModel.openChapterAt(newValue.round(), true);
                            readModel.scheduleProgressSave(
                              delay: Duration.zero,
                            );
                          },
                  ),
                ),
              ),
              _miniTextBtn('下一章', () => step(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTextBtn(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: chrome.fg,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
