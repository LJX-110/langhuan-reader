/// Where a book-source stage failed, with the rule field to blame.
///
/// Thrown by the engine's detail / catalog / content paths so callers can show
/// "目录 · 列表规则 chapterList" instead of a generic failure.
class SourceStageError implements Exception {
  const SourceStageError({
    required this.stage,
    required this.field,
    required this.detail,
    this.rule = '',
    this.cause,
  });

  /// `search` / `bookInfo` / `toc` / `content`.
  final String stage;

  /// Rule field name (`bookList`, `tocUrl`, `chapterUrl`, `content`, ...).
  final String field;

  /// Human-readable reason.
  final String detail;

  /// The failing rule text (possibly empty, e.g. network errors).
  final String rule;

  final Object? cause;

  String get stageLabel => switch (stage) {
    'search' => '搜索',
    'bookInfo' => '详情',
    'toc' => '目录',
    'content' => '正文',
    _ => stage,
  };

  /// Short user-facing message, e.g. `目录失败（列表规则 chapterList）：未匹配到章节`.
  String get message {
    final where = field.isEmpty ? '' : '（$field）';
    return '$stageLabel失败$where：$detail';
  }

  @override
  String toString() => message;
}

/// Result of one single-source stage test (used by the test sheet).
class SourceStageResult {
  const SourceStageResult({
    required this.stage,
    required this.ok,
    required this.elapsedMs,
    this.detail = '',
    this.field = '',
    this.rule = '',
    this.count = 0,
    this.sample = '',
    this.bookUrl = '',
    this.tocUrl = '',
    this.chapterUrl = '',
  });

  final String stage;
  final bool ok;
  final int elapsedMs;
  final String detail;

  /// Failing rule field ('' when ok or unattributable).
  final String field;
  final String rule;

  /// Hits / chapters / characters, depending on the stage.
  final int count;

  /// First hit name / first chapter title / content head.
  final String sample;

  /// Chain data so the sheet can run the next stage directly.
  final String bookUrl;
  final String tocUrl;
  final String chapterUrl;

  String get stageLabel => switch (stage) {
    'search' => '搜索',
    'bookInfo' => '详情',
    'toc' => '目录',
    'content' => '正文',
    _ => stage,
  };

  String get statusLabel => ok ? '通过' : '失败';

  factory SourceStageResult.fromError(
    SourceStageError error,
    int elapsedMs,
  ) => SourceStageResult(
    stage: error.stage,
    ok: false,
    elapsedMs: elapsedMs,
    detail: error.detail,
    field: error.field,
    rule: error.rule,
  );

  factory SourceStageResult.failure({
    required String stage,
    required String detail,
    required int elapsedMs,
    String field = '',
    String rule = '',
    String sample = '',
    String bookUrl = '',
    String tocUrl = '',
    String chapterUrl = '',
  }) => SourceStageResult(
    stage: stage,
    ok: false,
    elapsedMs: elapsedMs,
    detail: detail,
    field: field,
    rule: rule,
    sample: sample,
    bookUrl: bookUrl,
    tocUrl: tocUrl,
    chapterUrl: chapterUrl,
  );
}
