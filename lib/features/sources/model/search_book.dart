/// Engine-level search hit from a book source.
class SearchBook {
  String name;
  String author;
  String kind;
  String wordCount;
  String lastChapter;
  String intro;
  String coverUrl;
  String bookUrl;
  String sourceUrl;
  String sourceName;

  SearchBook({
    this.name = '',
    this.author = '',
    this.kind = '',
    this.wordCount = '',
    this.lastChapter = '',
    this.intro = '',
    this.coverUrl = '',
    this.bookUrl = '',
    this.sourceUrl = '',
    this.sourceName = '',
  });
}

/// Engine-level chapter entry with absolute URL.
class SourceChapter {
  String name;
  String url;
  bool isVolume;
  int index;

  /// Optional per-chapter meta from `ruleToc.updateTime`, e.g.
  /// 「章节字数：2345　更新时间：2022-12-04」. Rendered in the reader header.
  String info;

  SourceChapter({
    this.name = '',
    this.url = '',
    this.isVolume = false,
    this.index = 0,
    this.info = '',
  });
}
