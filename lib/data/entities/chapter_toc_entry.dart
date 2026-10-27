/// TOC entry for a book chapter (local catalog row).
class ChapterTocEntry {
  String id;
  String title;
  String url;

  /// True when chapter body is cached in reader.db.
  bool hasBody;
  int ord;

  /// Display grouping only: the volume this chapter belongs to.
  ///
  /// Empty when the source has no `isVolume` rule. Never participates in
  /// reading progress, chapter ids or the `(book_id, ord)` index.
  String volumeTitle;
  int volumeOrd;

  /// Per-chapter meta from `ruleToc.updateTime`（章节字数 / 更新时间）.
  String info;

  ChapterTocEntry({
    this.id = '',
    this.title = '',
    this.url = '',
    this.hasBody = false,
    this.ord = 0,
    this.volumeTitle = '',
    this.volumeOrd = -1,
    this.info = '',
  });
}
