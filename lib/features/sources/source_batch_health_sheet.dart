import 'package:flutter/material.dart';
import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';

/// 批量体检：把所有**启用**的书源跑一遍「搜索」，分类统计，并支持一键删除失败源。
///
/// 手机端也能跑（宿主机没有 JS 运行时，`@js:` 规则在电脑上必失败，所以
/// 这项体检在真机上才有意义）。
Future<void> showSourceBatchHealthSheet(
  BuildContext context, {
  String initialKeyword = '斗破苍穹',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BatchHealthSheet(initialKeyword: initialKeyword),
  );
}

class _BatchHealthSheet extends StatefulWidget {
  const _BatchHealthSheet({required this.initialKeyword});

  final String initialKeyword;

  @override
  State<_BatchHealthSheet> createState() => _BatchHealthSheetState();
}

class _BatchHealthSheetState extends State<_BatchHealthSheet> {
  late final TextEditingController _keyword = TextEditingController(
    text: widget.initialKeyword,
  );
  final SourceRepository _repo = SourceRepository.instance;
  final BookSourceEngine _engine = BookSourceEngine();

  bool _running = false;
  int _done = 0;
  int _total = 0;
  String _error = '';
  final List<_HealthRow> _rows = [];

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  /// 网络/超时/规则/解析/异常——这类源基本没救。
  List<_HealthRow> get _failed => _rows
      .where((r) => r.issue != 'none' && r.issue != 'noResult')
      .toList();
  /// 含"站点活着但搜不到"的更大集合。
  List<_HealthRow> get _noHit =>
      _rows.where((r) => r.issue != 'none' || r.hits == 0).toList();

  Future<void> _run() async {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty) {
      setState(() => _error = '请输入关键词');
      return;
    }
    setState(() {
      _running = true;
      _done = 0;
      _rows.clear();
      _error = '';
    });
    try {
      final metas = await _repo.getAll();
      final enabled = metas
          .where((s) => s.enabled && s.searchUrl.trim().isNotEmpty)
          .map((s) => s.bookSourceUrl)
          .toList();
      final sources = await _repo.getByUrls(enabled);
      setState(() => _total = sources.length);
      const concurrency = 4;
      for (var i = 0; i < sources.length; i += concurrency) {
        final end = (i + concurrency).clamp(0, sources.length);
        await Future.wait(
          sources.sublist(i, end).map((source) async {
            _HealthRow row;
            try {
              final r = await _engine.searchWithReport(source, keyword, 1);
              row = _HealthRow(
                name: source.bookSourceName,
                url: source.bookSourceUrl,
                issue: r.issue.name,
                hits: r.hits.length,
                ms: r.elapsedMs,
              );
            } catch (e) {
              row = _HealthRow(
                name: source.bookSourceName,
                url: source.bookSourceUrl,
                issue: 'exception',
                hits: 0,
                ms: 0,
              );
            }
            if (!mounted) return;
            setState(() {
              _rows.add(row);
              _done = _rows.length;
            });
          }),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '体检中断：${e.runtimeType}');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _deleteRows(List<_HealthRow> rows, String label) async {
    if (rows.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除$label'),
        content: Text('将删除 ${rows.length} 个书源，删除后要重新导入才能恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final urls = rows.map((r) => r.url).toList(growable: false);
    try {
      await _repo.deleteMany(urls);
      if (!mounted) return;
      setState(() {
        _rows.removeWhere((r) => urls.contains(r.url));
        _total = _rows.length;
        _done = _rows.length;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除 ${urls.length} 个书源')));
    } catch (e) {
      if (mounted) setState(() => _error = '删除失败：${e.runtimeType}');
    }
  }

  int get _okCount => _rows.where((r) => r.hits > 0).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height * 0.82;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '批量体检',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keyword,
                      enabled: !_running,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: '搜索关键词',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _running ? null : _run,
                    child: Text(_running ? '体检中' : '开始'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_error.isNotEmpty)
                Text(
                  _error,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
                ),
              Text(
                _total == 0
                    ? '对每个启用书源跑一次搜索；宿主机跑不了 JS，这项请在手机上用。'
                    : '进度 $_done/$_total · 有结果 $_okCount · 失败 ${_failed.length}',
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _rows.isEmpty
                    ? const Center(child: Text('还没有结果'))
                    : ListView.builder(
                        itemCount: _rows.length,
                        itemBuilder: (context, index) {
                          final r = _rows[index];
                          final bad = r.issue != 'none' && r.issue != 'noResult';
                          return ListTile(
                            dense: true,
                            title: Text(
                              r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              r.hits > 0
                                  ? '${r.hits} 条 · ${r.ms}ms'
                                  : '${_issueLabel(r.issue)} · ${r.ms}ms',
                              style: TextStyle(
                                fontSize: 12,
                                color: bad
                                    ? theme.colorScheme.error
                                    : theme.hintColor,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _failed.isEmpty || _running
                          ? null
                          : () => _deleteRows(_failed, '失败源'),
                      child: Text('删除失败源 (${_failed.length})'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _noHit.isEmpty || _running
                          ? null
                          : () => _deleteRows(_noHit, '无结果与失败源'),
                      child: Text('删无结果+失败 (${_noHit.length})'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _issueLabel(String issue) => switch (issue) {
    'none' => '成功',
    'noResult' => '无结果',
    'incompatibleRule' => '规则不兼容',
    'parse' => '解析失败',
    'network' => '网络失败',
    'timeout' => '超时',
    'exception' => '异常',
    _ => issue,
  };
}

class _HealthRow {
  const _HealthRow({
    required this.name,
    required this.url,
    required this.issue,
    required this.hits,
    required this.ms,
  });

  final String name;
  final String url;
  final String issue;
  final int hits;
  final int ms;
}
