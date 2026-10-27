import 'package:langhuan/data/entities/text_page.dart';
import 'package:json_annotation/json_annotation.dart';

part 'read_page.g.dart';

@JsonSerializable()
class ReadPage {
  int get pageOffsets => pages.length;
  List<TextPage> pages;
  String chapterContent;
  double height;
  String chapterName;

  /// Source-provided chapter meta (`ruleToc.updateTime`), e.g.
  /// 「章节字数：2345　更新时间：2022-12-04」. Painted under the chapter
  /// header on the first page. In-memory only.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String chapterInfo;

  /// In-memory only: true for loading / error placeholders.
  ///
  /// Never serialized into `pages_json`; old caches deserialize as `false`.
  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isPlaceholder;

  ReadPage.kong()
    : pages = const [],
      chapterContent = '',
      height = 0,
      chapterName = '',
      chapterInfo = '',
      isPlaceholder = false;

  ReadPage(
    this.chapterContent,
    this.chapterName,
    this.height,
    this.pages, {
    this.chapterInfo = '',
    this.isPlaceholder = false,
  });

  factory ReadPage.fromJson(Map<String, dynamic> json) =>
      _$ReadPageFromJson(json);

  Map<String, dynamic> toJson() => _$ReadPageToJson(this);
}
