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
      isPlaceholder = false;

  ReadPage(
    this.chapterContent,
    this.chapterName,
    this.height,
    this.pages, {
    this.isPlaceholder = false,
  });

  factory ReadPage.fromJson(Map<String, dynamic> json) =>
      _$ReadPageFromJson(json);

  Map<String, dynamic> toJson() => _$ReadPageToJson(this);
}
