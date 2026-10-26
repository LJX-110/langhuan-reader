import 'package:langhuan/data/entities/chapter_toc_entry.dart';

/// One rendered catalog row: either a volume header or a chapter row.
///
/// Chapter indices always refer to readable chapters, so volume headers never
/// shift reading progress, jump maths or the chapter number shown in the list.
class TocRow {
  const TocRow({
    this.isVolume = false,
    this.title = '',
    this.count = 0,
    this.chapterIndex = -1,
    this.chapter,
  });

  final bool isVolume;
  final String title;
  final int count;
  final int chapterIndex;
  final ChapterTocEntry? chapter;
}

/// Build the catalog rows for [chapters], optionally filtered by [query].
///
/// Search matches chapter names, volume names and chapter numbers; a volume
/// header is inserted once, before the first match of that volume.
List<TocRow> buildTocRows(
  List<ChapterTocEntry> chapters, {
  String query = '',
}) {
  final rows = <TocRow>[];
  final q = query.trim().toLowerCase();
  var lastVolume = '';
  for (var i = 0; i < chapters.length; i++) {
    final chapter = chapters[i];
    if (q.isEmpty) {
      if (chapter.volumeTitle.isNotEmpty &&
          chapter.volumeTitle != lastVolume) {
        lastVolume = chapter.volumeTitle;
        rows.add(
          TocRow(
            isVolume: true,
            title: lastVolume,
            count: _volumeChapterCount(chapters, lastVolume, from: i),
          ),
        );
      }
      rows.add(TocRow(chapterIndex: i, chapter: chapter));
      continue;
    }
    final nameHit = chapter.title.toLowerCase().contains(q);
    final volumeHit =
        chapter.volumeTitle.isNotEmpty &&
        chapter.volumeTitle.toLowerCase().contains(q);
    final numberHit = '${i + 1}'.contains(q);
    if (!nameHit && !volumeHit && !numberHit) continue;
    final volume = chapter.volumeTitle;
    if (volume.isNotEmpty && volume != lastVolume) {
      lastVolume = volume;
      rows.add(
        TocRow(
          isVolume: true,
          title: volume,
          count: _volumeChapterCount(chapters, volume, from: i),
        ),
      );
    }
    rows.add(TocRow(chapterIndex: i, chapter: chapter));
  }
  return rows;
}

/// Row index of [chapterIndex] inside [rows]; `0` when not present.
int tocRowForChapter(List<TocRow> rows, int chapterIndex) {
  for (var i = rows.length - 1; i >= 0; i--) {
    if (!rows[i].isVolume && rows[i].chapterIndex == chapterIndex) {
      return i;
    }
  }
  return 0;
}

int _volumeChapterCount(
  List<ChapterTocEntry> chapters,
  String volume, {
  required int from,
}) {
  var count = 0;
  for (var i = from; i < chapters.length; i++) {
    if (chapters[i].volumeTitle != volume) break;
    count++;
  }
  return count;
}
