import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/model/book_source.dart';

/// One source's pre-import check result.
class SourceValidationItem {
  const SourceValidationItem({
    required this.source,
    this.problem = '',
    this.hint = '',
  });

  final BookSource source;

  /// Empty when the source passed.
  final String problem;

  /// What the user can do about it.
  final String hint;

  bool get valid => problem.isEmpty;

  String get displayName =>
      source.bookSourceName.trim().isEmpty
      ? '(未命名书源)'
      : source.bookSourceName.trim();
}

/// Pre-import validation report.
///
/// Only structural problems are rejected here (missing identity, no usable
/// entry URL, empty rule sets). Whether a rule actually matches a live site is
/// what the single-source test sheet is for.
class SourceValidationReport {
  const SourceValidationReport(this.items);

  final List<SourceValidationItem> items;

  List<BookSource> get valid => [
    for (final item in items)
      if (item.valid) item.source,
  ];

  List<SourceValidationItem> get invalid => [
    for (final item in items)
      if (!item.valid) item,
  ];

  int get total => items.length;
}

class SourceValidator {
  const SourceValidator._();

  static SourceValidationReport validate(SourceParseResult parsed) {
    final items = <SourceValidationItem>[];
    for (final source in parsed.sources) {
      items.add(_check(source));
    }
    return SourceValidationReport(items);
  }

  static SourceValidationItem _check(BookSource source) {
    final url = source.bookSourceUrl.trim();
    final name = source.bookSourceName.trim();
    if (url.isEmpty || url.startsWith('local://')) {
      return SourceValidationItem(
        source: source,
        problem: '缺少 bookSourceUrl',
        hint: '书源没有源站地址，导入后无法发起任何请求',
      );
    }
    if (name.isEmpty) {
      return SourceValidationItem(
        source: source,
        problem: '缺少书源名称',
        hint: '补一个 bookSourceName 便于在列表和换源时识别',
      );
    }
    final searchUrl = source.searchUrl.trim();
    final exploreUrl = source.exploreUrl.trim();
    if (searchUrl.isEmpty && exploreUrl.isEmpty) {
      return SourceValidationItem(
        source: source,
        problem: '没有搜索或发现地址',
        hint: '至少需要 searchUrl 或 exploreUrl 之一',
      );
    }
    if (source.ruleSearch.isEmpty &&
        source.ruleExplore.isEmpty &&
        source.ruleBookInfo.isEmpty &&
        source.ruleToc.isEmpty &&
        source.ruleContent.isEmpty) {
      return SourceValidationItem(
        source: source,
        problem: '没有任何解析规则',
        hint: '搜索 / 发现 / 详情 / 目录 / 正文规则全为空，导入后无法解析',
      );
    }
    if (searchUrl.isNotEmpty && source.ruleSearch.bookList.trim().isEmpty) {
      return SourceValidationItem(
        source: source,
        problem: '搜索规则缺少 bookList',
        hint: '配置了 searchUrl 但没有搜索结果列表规则，搜索会解析失败',
      );
    }
    if (exploreUrl.isEmpty &&
        source.ruleSearch.bookList.trim().isEmpty &&
        source.ruleExplore.bookList.trim().isEmpty) {
      return SourceValidationItem(
        source: source,
        problem: '没有可用的列表规则',
        hint: 'bookList 为空，无法取出任何书籍条目',
      );
    }
    return SourceValidationItem(source: source);
  }
}
