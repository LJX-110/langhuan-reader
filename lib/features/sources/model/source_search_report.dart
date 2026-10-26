import 'package:langhuan/features/sources/model/search_book.dart';

/// Why one source produced (or failed to produce) search results.
///
/// The normal search UI only shows counts; the diagnostics sheet maps this to
/// an actionable label so "no hits" is never confused with a broken rule.
enum SourceSearchIssue {
  /// The source returned at least one usable hit.
  none,

  /// The request succeeded and the page was parsed, but nothing matched.
  noResult,

  /// Search URL / list rule is missing or cannot be resolved.
  incompatibleRule,

  /// The page was fetched but its structure did not match the rules.
  parse,

  /// DNS / connection / HTTP / TLS failure.
  network,

  /// No response before the deadline.
  timeout,

  /// Anything else (cancelled request, unexpected exception).
  unknown;

  String get label => switch (this) {
    SourceSearchIssue.none => '搜索成功',
    SourceSearchIssue.noResult => '无结果',
    SourceSearchIssue.incompatibleRule => '规则不兼容',
    SourceSearchIssue.parse => '解析失败',
    SourceSearchIssue.network => '网络失败',
    SourceSearchIssue.timeout => '请求超时',
    SourceSearchIssue.unknown => '未知错误',
  };
}

/// One source's search attempt, including a redacted request URL and timing.
class SourceSearchReport {
  const SourceSearchReport({
    required this.sourceUrl,
    required this.sourceName,
    required this.keyword,
    required this.page,
    required this.issue,
    this.hits = const [],
    this.elapsedMs = 0,
    this.requestUrl = '',
    this.detail = '',
    this.httpStatus = 0,
    this.rawItems = 0,
  });

  final String sourceUrl;
  final String sourceName;
  final String keyword;
  final int page;
  final SourceSearchIssue issue;
  final List<SearchBook> hits;
  final int elapsedMs;

  /// Sanitised: scheme/host/path only, never a query value or userinfo.
  final String requestUrl;
  final String detail;
  final int httpStatus;

  /// Number of list nodes matched before field extraction.
  final int rawItems;

  bool get ok => issue == SourceSearchIssue.none;

  /// The site answered, even if it had no results.
  bool get reachable =>
      issue == SourceSearchIssue.none || issue == SourceSearchIssue.noResult;

  bool get failed => !reachable;

  String get label => issue.label;

  /// One-line result used in lists.
  String get summary {
    if (ok) return '${hits.length} 条结果 · ${elapsedMs}ms';
    if (issue == SourceSearchIssue.noResult) {
      return '无结果 · ${elapsedMs}ms';
    }
    return label;
  }

  /// Actionable explanation shown under the label.
  String get hint {
    switch (issue) {
      case SourceSearchIssue.none:
        return hits.isEmpty ? '未返回结果。' : '返回 ${hits.length} 条结果。';
      case SourceSearchIssue.noResult:
        return '书源可访问，但没有匹配「$keyword」的结果。';
      case SourceSearchIssue.incompatibleRule:
        return detail.isEmpty ? '搜索地址或列表规则缺失，当前引擎无法执行。' : detail;
      case SourceSearchIssue.parse:
        return detail.isEmpty ? '页面结构未匹配搜索规则。' : detail;
      case SourceSearchIssue.network:
        return detail.isEmpty ? '无法连接书源站点，请检查网络或站点状态。' : detail;
      case SourceSearchIssue.timeout:
        return detail.isEmpty ? '请求超时，可稍后重试。' : detail;
      case SourceSearchIssue.unknown:
        return detail.isEmpty ? '请求或解析异常，可重试后查看日志。' : detail;
    }
  }
}
