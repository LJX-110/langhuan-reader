import 'package:langhuan/data/entities/read_page.dart';
import 'package:langhuan/data/entities/text_line.dart';
import 'package:langhuan/data/entities/text_page.dart';
import 'package:langhuan/features/reader/model/text_paginator.dart';

/// In-page loading / error placeholders drawn as normal [ReadPage]s.
///
/// No BotToast overlay — the reader canvas paints these like chapter content.
class ReaderLoadingPresenter {
  ReaderLoadingPresenter({
    required this.paginator,
    required this.setLoadingHint,
    required this.notify,
  });

  final TextPaginator paginator;
  final void Function(String text) setLoadingHint;
  final void Function() notify;

  /// Lightweight sync placeholder (no paginator / isolate) for open/clear races.
  ///
  /// [chapterTitle]: painted in the top chrome. Callers decide whether an
  /// unknown title stays empty or falls back to a neutral label.
  /// [hint]: body text. Empty keeps a blank paper page.
  static ReadPage syncPlaceholder(String hint, {String chapterTitle = ''}) {
    final page = ReadPage.kong();
    page.chapterName = chapterTitle;
    page.chapterContent = hint;
    page.isPlaceholder = true;
    if (hint.isEmpty) {
      // Blank paper — no centered "正在加载" text. Real content replaces this.
      page.pages = [TextPage(const [], 0)];
    } else {
      page.pages = [
        TextPage([TextLine.simple(hint)], 24),
      ];
    }
    return page;
  }

  /// Build a single-page [ReadPage] with a readable error/hint message.
  Future<ReadPage> messagePage(String title, String message) async {
    final page = ReadPage.kong();
    page.chapterName = title;
    page.chapterContent = message;
    page.isPlaceholder = true;
    try {
      page.pages = await paginator.paginate(page);
    } catch (_) {
      page.pages = const [];
    }
    if (page.pages.isEmpty) {
      // Absolute fallback so drawContent never paints a blank canvas.
      page.pages = [
        TextPage([TextLine.simple(message, height: 24)], 24),
      ];
    }
    return page;
  }

  /// Show a lightweight loading hint without replacing readable content.
  ///
  /// The reader keeps the previous chapter on screen until the target body is
  /// ready. TOC jumps paint their target title via [syncPlaceholder] first.
  Future<void> show(String text) async {
    setLoadingHint(text);
    notify();
  }

  /// Content replacement (openChapterAt / chapter load) clears the hint page.
  void hide() {}
}
