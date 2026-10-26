import 'package:flutter/material.dart';
import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/model/source_diagnostics.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';

/// Single-source test sheet: 搜索 → 详情 → 目录 → 正文（正文按需点）。
///
/// Stage 1 uses the caller's search callback (so health reporting stays with
/// the owning model); stages 2-4 run directly through the engine and report
/// the failing rule field when a stage produces nothing.
Future<void> showSourceTestSheet({
  required BuildContext context,
  required String sourceName,
  required String sourceUrl,
  required String initialKeyword,
  Future<SourceSearchReport?> Function(String keyword)? onSearch,
  Future<BookSource?> Function()? hydrate,
  BookSourceEngine? engine,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _SourceTestSheet(
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      initialKeyword: initialKeyword,
      onSearch: onSearch,
      hydrate: hydrate,
      engine: engine ?? BookSourceEngine(),
    ),
  );
}

class _SourceTestSheet extends StatefulWidget {
  const _SourceTestSheet({
    required this.sourceName,
    required this.sourceUrl,
    required this.initialKeyword,
    required this.engine,
    this.onSearch,
    this.hydrate,
  });

  final String sourceName;
  final String sourceUrl;
  final String initialKeyword;
  final BookSourceEngine engine;
  final Future<SourceSearchReport?> Function(String keyword)? onSearch;
  final Future<BookSource?> Function()? hydrate;

  @override
  State<_SourceTestSheet> createState() => _SourceTestSheetState();
}

class _SourceTestSheetState extends State<_SourceTestSheet> {
  late final TextEditingController _keyword = TextEditingController(
    text: widget.initialKeyword,
  );

  BookSource? _source;
  SourceSearchReport? _report;
  List<SearchBook> _hits = const [];
  int _selectedHit = 0;

  SourceStageResult? _bookInfo;
  SourceStageResult? _toc;
  SourceStageResult? _content;

  String _running = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<BookSource?> _ensureSource() async {
    final existing = _source;
    if (existing != null) return existing;
    final custom = widget.hydrate;
    final src = custom != null
        ? await custom()
        : await SourceRepository.instance.getByUrl(widget.sourceUrl);
    _source = src;
    return src;
  }

  Future<void> _runSearch() async {
    final key = _keyword.text.trim();
    if (key.isEmpty) {
      setState(() => _error = '请输入搜索关键词');
      return;
    }
    setState(() {
      _running = 'search';
      _error = '';
      _bookInfo = null;
      _toc = null;
      _content = null;
    });
    try {
      SourceSearchReport? report;
      final custom = widget.onSearch;
      if (custom != null) {
        report = await custom(key);
      } else {
        final src = await _ensureSource();
        if (src == null) {
          if (mounted) setState(() => _error = '书源不存在或已删除');
          return;
        }
        report = await widget.engine.searchWithReport(src, key, 1);
      }
      if (!mounted) return;
      setState(() {
        _report = report;
        _hits = report?.hits ?? const [];
        _selectedHit = 0;
      });
    } finally {
      if (mounted) setState(() => _running = '');
    }
  }

  SearchBook? get _hit =>
      _hits.isEmpty ? null : _hits[_selectedHit.clamp(0, _hits.length - 1)];

  Future<void> _runStage(String stage) async {
    BookSource? src;
    try {
      src = await _ensureSource();
    } catch (e) {
      if (mounted) setState(() => _error = '书源读取失败：${e.runtimeType}');
      return;
    }
    if (!mounted) return;
    if (src == null) {
      setState(() => _error = '书源不存在或已删除');
      return;
    }
    setState(() {
      _running = stage;
      _error = '';
    });
    try {
      switch (stage) {
        case 'bookInfo':
          final hit = _hit;
          if (hit == null) {
            setState(() => _error = '先搜索并选中一条结果');
            return;
          }
          final result = await widget.engine.testBookInfo(src, hit.bookUrl);
          if (mounted) setState(() => _bookInfo = result);
        case 'toc':
          final url = _bookInfo?.tocUrl.isNotEmpty == true
              ? _bookInfo!.tocUrl
              : (_hit?.bookUrl ?? '');
          if (url.isEmpty) {
            setState(() => _error = '先完成详情测试');
            return;
          }
          final result = await widget.engine.testToc(src, url);
          if (mounted) setState(() => _toc = result);
        case 'content':
          final url = _toc?.chapterUrl ?? '';
          if (url.isEmpty) {
            setState(() => _error = '先完成目录测试（正文按需抓取第一章）');
            return;
          }
          final result = await widget.engine.testContent(src, url);
          if (mounted) setState(() => _content = result);
      }
    } finally {
      if (mounted) setState(() => _running = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AlertDialog(
      title: Text(
        '测试「${widget.sourceName}」',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyword,
                      enabled: _running.isEmpty,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                      decoration: const InputDecoration(
                        labelText: '搜索关键词',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _running.isNotEmpty ? null : _runSearch,
                    child: Text(_report == null ? '开始测试' : '重搜'),
                  ),
                ],
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _error,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              if (_running == 'search')
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                ),
              if (_report != null) SourceSearchReportCard(report: _report!),
              if (_hits.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '选择一条结果用于后续测试',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < _hits.length && i < 5; i++)
                      ChoiceChip(
                        label: Text(
                          _hits[i].name,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: i == _selectedHit,
                        onSelected: (_) => setState(() => _selectedHit = i),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _StageCard(
                label: '详情',
                hint: '取书名 / 目录地址',
                result: _bookInfo,
                enabled: _hits.isNotEmpty && _running.isEmpty,
                running: _running == 'bookInfo',
                onRun: () => _runStage('bookInfo'),
              ),
              const SizedBox(height: 8),
              _StageCard(
                label: '目录',
                hint: '取章节列表',
                result: _toc,
                enabled: _bookInfo?.ok == true && _running.isEmpty,
                running: _running == 'toc',
                onRun: () => _runStage('toc'),
              ),
              const SizedBox(height: 8),
              _StageCard(
                label: '正文',
                hint: '按需抓取第一章',
                result: _content,
                enabled: _toc?.ok == true && _running.isEmpty,
                running: _running == 'content',
                onRun: () => _runStage('content'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running.isEmpty ? () => Navigator.pop(context) : null,
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// One stage's status card: result chip, timing, sample and the failing rule.
class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.label,
    required this.hint,
    required this.result,
    required this.enabled,
    required this.running,
    required this.onRun,
  });

  final String label;
  final String hint;
  final SourceStageResult? result;
  final bool enabled;
  final bool running;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final r = result;
    final okColor = theme.colorScheme.primary;
    final failColor = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              if (r == null)
                Text(hint, style: TextStyle(fontSize: 11, color: muted))
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: (r.ok ? okColor : failColor).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${r.statusLabel} · ${r.elapsedMs}ms',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: r.ok ? okColor : failColor,
                    ),
                  ),
                ),
              const Spacer(),
              if (running)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: enabled ? onRun : null,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text('测试', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (r != null) ...[
            const SizedBox(height: 6),
            Text(r.detail, style: TextStyle(fontSize: 12, color: muted)),
            if (r.sample.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                r.sample,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
            if (!r.ok && r.field.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '失败字段：${r.field}',
                style: TextStyle(fontSize: 11, color: failColor),
              ),
            ],
            if (!r.ok && r.rule.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                r.rule,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: muted,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Compact evidence card: outcome, hint, sample hits, timing, redacted URL.
class SourceSearchReportCard extends StatelessWidget {
  const SourceSearchReportCard({super.key, required this.report});

  final SourceSearchReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final error = theme.colorScheme.error;
    final accent = report.ok
        ? theme.colorScheme.primary
        : (report.issue == SourceSearchIssue.noResult
              ? theme.colorScheme.onSurfaceVariant
              : error);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  report.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${report.elapsedMs}ms',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.hint,
            style: TextStyle(fontSize: 12, height: 1.5, color: muted),
          ),
          if (report.hits.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '结果示例',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            for (final hit in report.hits.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '· ${hit.name}'
                  '${hit.author.isEmpty ? '' : ' / ${hit.author}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          if (report.requestUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              report.requestUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: muted,
              ),
            ),
            Text(
              '查询参数已隐藏',
              style: TextStyle(fontSize: 10, color: muted),
            ),
          ],
          if (report.httpStatus > 0) ...[
            const SizedBox(height: 4),
            Text(
              'HTTP ${report.httpStatus}',
              style: TextStyle(fontSize: 10, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}
