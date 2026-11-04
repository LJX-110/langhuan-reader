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

  /// 路由参数传递（详情壳先用种子立即推页，页内再补网络详情）。
  Map<String, dynamic> toJson() => {
    'name': name,
    'author': author,
    'kind': kind,
    'wordCount': wordCount,
    'lastChapter': lastChapter,
    'intro': intro,
    'coverUrl': coverUrl,
    'bookUrl': bookUrl,
    'sourceUrl': sourceUrl,
    'sourceName': sourceName,
  };

  factory SearchBook.fromJson(Map<String, dynamic> json) => SearchBook(
    name: (json['name'] ?? '').toString(),
    author: (json['author'] ?? '').toString(),
    kind: (json['kind'] ?? '').toString(),
    wordCount: (json['wordCount'] ?? '').toString(),
    lastChapter: (json['lastChapter'] ?? '').toString(),
    intro: (json['intro'] ?? '').toString(),
    coverUrl: (json['coverUrl'] ?? '').toString(),
    bookUrl: (json['bookUrl'] ?? '').toString(),
    sourceUrl: (json['sourceUrl'] ?? '').toString(),
    sourceName: (json['sourceName'] ?? '').toString(),
  );
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
