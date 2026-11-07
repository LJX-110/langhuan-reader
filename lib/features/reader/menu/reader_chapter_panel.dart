import 'package:flutter/material.dart';

import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/read_model.dart';
import 'package:langhuan/design/components/feedback.dart';

/// Chapter slider shown when the menu first opens.
class ReaderChapterPanel extends StatefulWidget {
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
  State<ReaderChapterPanel> createState() => _ReaderChapterPanelState();
}

class _ReaderChapterPanelState extends State<ReaderChapterPanel> {
  Future<void> _step(int delta) async {
    final chapters = widget.readModel.chapters;
    final book = widget.readModel.book;
    if (book == null) return;
    final next = book.chapterIndex + delta;
    if (next < 0) {
      showFeedback('已经是第一章');
      return;
    }
    if (next >= chapters.length) {
      showFeedback('已经是最后一章');
      return;
    }
    await widget.readModel.openChapterAt(next, true);
    widget.readModel.scheduleProgressSave(delay: Duration.zero);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final chapters = widget.readModel.chapters;
    final chrome = widget.chrome;
    final index = (widget.readModel.book?.chapterIndex ?? 0)
        .clamp(0, chapters.isEmpty ? 0 : chapters.length - 1)
        .toInt();
    final chapterName = index >= 0 && index < chapters.length
        ? chapters[index].title
        : '';

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
          // 全书拖动定位交给底栏进度条（reader_progress_bar），这里保留章节步进。
          Row(
            children: <Widget>[
              Expanded(child: _miniTextBtn('上一章', () => _step(-1))),
              const SizedBox(width: 10),
              Expanded(child: _miniTextBtn('下一章', () => _step(1))),
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
        foregroundColor: widget.chrome.fg,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
