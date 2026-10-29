import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/features/reader/read_model.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/features/sources/model/source_groups.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';
import 'package:langhuan/features/sources/util/text_clean.dart';
import 'package:langhuan/app/providers.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';

/// Bottom sheet: search enabled sources for the current book and switch.
///
/// Works both from the reader (active session) and the book detail page
/// (metadata only — no chapter window to open yet).
class SourceSwitchSheet extends ConsumerStatefulWidget {
  final ReadModel readModel;

  /// Called after a successful source switch so the host page can refresh UI.
  final void Function(Book book)? onSwitched;

  const SourceSwitchSheet({
    super.key,
    required this.readModel,
    this.onSwitched,
  });

  @override
  ConsumerState<SourceSwitchSheet> createState() => _SourceSwitchSheetState();
}

class _SourceSwitchSheetState extends ConsumerState<SourceSwitchSheet> {
  final BookSourceEngine _engine = BookSourceEngine();
  bool loading = true;
  String? error;
  final List<_Candidate> candidates = [];

  /// 关键词筛选（对齐阅读换源面板的 `screen(key)`）：按书名 / 作者 / 书源名过滤。
  String _keyword = '';
  List<_Candidate> get _visibleCandidates {
    final kw = _keyword.trim();
    if (kw.isEmpty) return candidates;
    return candidates
        .where(
          (c) =>
              c.hit.name.contains(kw) ||
              cleanAuthor(c.hit.author).contains(kw) ||
              c.source.bookSourceName.contains(kw),
        )
        .toList(growable: false);
  }

  /// Group scope for the candidate sweep ('' = all).
  String _groupFilter = '';
  List<String> _groups = const [];

  /// Per-source outcome counts for the status row.
  int _noMatch = 0;
  final List<({String name, String reason})> _failed = [];

  Book? get _book => widget.readModel.book;

  /// 置顶 / 置底（对齐阅读的 `topSource` / `bottomSource`）。
  ///
  /// 书源列表按 `custom_order ASC` 排：置顶写 0，置底写一个大数；同时把
  /// 候选列表就地重排，界面立刻反映，不用重新搜一遍。
  Future<void> _moveSource(_Candidate c, {required bool toTop}) async {
    try {
      await SourceRepository.instance.updateOrder(
        c.source.bookSourceUrl,
        toTop ? 0 : 1 << 20,
      );
      if (!mounted) return;
      setState(() {
        candidates.removeWhere(
          (x) => x.source.bookSourceUrl == c.source.bookSourceUrl,
        );
        if (toTop) {
          candidates.insert(0, c);
        } else {
          candidates.add(c);
        }
      });
    } catch (_) {
      // 排序失败不影响换源流程。
    }
  }

  /// 面板内禁用该源（对齐阅读换源面板的 `disableSource`）：禁用后不再参与
  /// 换源搜索，但书源本身和它的本地规则都保留，随时可在书源管理里启用。
  Future<void> _disableSource(_Candidate c) async {
    try {
      await SourceRepository.instance.setEnabled(
        c.source.bookSourceUrl,
        false,
      );
      if (!mounted) return;
      setState(() {
        candidates.removeWhere(
          (x) => x.source.bookSourceUrl == c.source.bookSourceUrl,
        );
      });
    } catch (_) {
      // 禁用失败不打断换源流程。
    }
  }

  bool get _dark => SpUtil.getBool(PrefsKeys.dark);

  Color get _surface => _dark ? AppColors.surfaceDark : AppColors.surface;
  Color get _primary => _dark ? AppColors.textOnDark : AppColors.textPrimary;
  Color get _secondary =>
      _dark ? AppColors.textMutedDark : AppColors.textSecondary;
  Color get _divider => _dark ? AppColors.dividerDark : AppColors.divider;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final book = _book;
    if (book == null) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '当前没有可换源的书籍';
      });
      return;
    }
    final key = book.name.trim().isNotEmpty
        ? book.name.trim()
        : book.author.trim();
    if (key.isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '书名未知，无法搜索其它书源';
      });
      return;
    }

    final model = ref.read(sourceModelProvider);
    final all = await model.enabledSources();
    if (all.isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '请先在「书源管理」导入并启用书源';
      });
      return;
    }
    _groups = SourceGroups.collect(all);
    final meta = SourceGroups.filter(all, _groupFilter);
    if (meta.isEmpty) {
      if (!mounted) return;
      setState(() {
        loading = false;
        candidates.clear();
        _failed.clear();
        _noMatch = 0;
        error = '该分组下没有启用的书源';
      });
      return;
    }

    final list = <_Candidate>[];
    var noMatch = 0;
    final failed = <({String name, String reason})>[];
    const pool = 5;
    final author = cleanAuthor(book.author);
    for (var i = 0; i < meta.length; i += pool) {
      if (!mounted) return;
      final chunkMeta = meta.skip(i).take(pool).toList();
      final chunk = await model.hydrateSources(chunkMeta);
      if (!mounted) return;
      final futures = chunk.map((s) async {
        // searchWithReport never throws and tells失败种类 apart from 无匹配.
        final report = await _engine.searchWithReport(s, key, 1);
        final matched = report.hits
            .where((h) => _isLikelyMatch(book, h, author))
            .map((h) => _Candidate(s, h))
            .toList();
        switch (switchOutcomeOf(report, matched.length)) {
          case SwitchSourceOutcome.hit:
            return matched;
          case SwitchSourceOutcome.noMatch:
            noMatch++;
            return const <_Candidate>[];
          case SwitchSourceOutcome.failed:
            failed.add((
              name: s.bookSourceName.isEmpty
                  ? s.bookSourceUrl
                  : s.bookSourceName,
              reason: '${report.label}：${report.hint}',
            ));
            return const <_Candidate>[];
        }
      });
      final parts = await Future.wait(futures);
      for (final p in parts) {
        list.addAll(p);
      }
    }

    // Prefer exact name, then same source last, then source name.
    list.sort((a, b) {
      final an = _nameScore(a.hit.name, book.name);
      final bn = _nameScore(b.hit.name, book.name);
      if (an != bn) return an - bn;
      final aa = _authorScore(a.hit.author, author);
      final ba = _authorScore(b.hit.author, author);
      if (aa != ba) return aa - ba;
      return a.source.bookSourceName.compareTo(b.source.bookSourceName);
    });

    if (!mounted) return;
    setState(() {
      candidates
        ..clear()
        ..addAll(list);
      _noMatch = noMatch;
      _failed
        ..clear()
        ..addAll(failed);
      loading = false;
      error = list.isEmpty
          ? (failed.isNotEmpty
                ? '没有可用结果：${failed.length} 个书源失败'
                : '未找到其它可用书源')
          : null;
    });
  }

  void _retry() {
    setState(() {
      loading = true;
      error = null;
      candidates.clear();
      _failed.clear();
      _noMatch = 0;
    });
    _load();
  }

  Future<void> _showFailures() async {
    if (_failed.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('失败书源'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _failed.length,
            separatorBuilder: (_, _) => const Divider(height: 12),
            itemBuilder: (_, i) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _failed[i].name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _failed[i].reason,
                  style: TextStyle(fontSize: 12, color: _secondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// Strict-ish match: same/similar title; author only when both sides have one.
  bool _isLikelyMatch(Book book, SearchBook hit, String bookAuthor) {
    final bn = book.name.trim();
    final hn = hit.name.trim();
    if (bn.isEmpty || hn.isEmpty) return false;
    // Name must overlap (exact, contains, or strip spaces).
    final bnN = bn.replaceAll(RegExp(r'\s+'), '');
    final hnN = hn.replaceAll(RegExp(r'\s+'), '');
    final nameOk =
        bn == hn || bnN == hnN || bnN.contains(hnN) || hnN.contains(bnN);
    if (!nameOk) return false;

    final ha = cleanAuthor(hit.author);
    if (bookAuthor.isEmpty || ha.isEmpty) return true;
    return ha.contains(bookAuthor) ||
        bookAuthor.contains(ha) ||
        ha == bookAuthor;
  }

  int _nameScore(String hit, String book) {
    if (hit == book) return 0;
    final a = hit.replaceAll(RegExp(r'\s+'), '');
    final b = book.replaceAll(RegExp(r'\s+'), '');
    if (a == b) return 1;
    if (a.contains(b) || b.contains(a)) return 2;
    return 3;
  }

  int _authorScore(String hit, String book) {
    if (book.isEmpty) return 1;
    final h = cleanAuthor(hit);
    if (h.isEmpty) return 2;
    if (h == book) return 0;
    if (h.contains(book) || book.contains(h)) return 1;
    return 3;
  }

  Future<void> _onPick(_Candidate c) async {
    final book = _book;
    if (book == null) return;
    final current =
        c.source.bookSourceUrl == book.sourceUrl &&
        (c.hit.bookUrl.isEmpty || c.hit.bookUrl == book.bookUrl);
    if (current) return;

    final ok = await widget.readModel.switchSource(c.source, c.hit);
    if (!mounted) return;
    if (ok) {
      widget.onSwitched?.call(widget.readModel.book ?? book);
      Navigator.pop(context, true);
    } else {
      BotToast.showText(text: '换源失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return Material(
      color: _surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '换源 · ${book?.name ?? ''}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _secondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              if ((book?.originName ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '当前：${book!.originName}',
                      style: TextStyle(fontSize: 13, color: _secondary),
                    ),
                  ),
                ),
              if (_groups.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final group in ['', ..._groups])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              group.isEmpty ? '全部' : group,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: _groupFilter == group,
                            onSelected: (_) {
                              if (_groupFilter == group) return;
                              setState(() {
                                _groupFilter = group;
                                loading = true;
                                error = null;
                                candidates.clear();
                                _failed.clear();
                                _noMatch = 0;
                              });
                              _load();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              if (!loading && candidates.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: '筛选结果（书名 / 作者 / 书源）',
                    ),
                    style: const TextStyle(fontSize: 13),
                    onChanged: (value) => setState(() => _keyword = value),
                  ),
                ),
              if (!loading && (_noMatch > 0 || _failed.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '候选 ${candidates.length} · 无匹配 $_noMatch · '
                          '失败 ${_failed.length}',
                          style: TextStyle(fontSize: 11, color: _secondary),
                        ),
                      ),
                      if (_failed.isNotEmpty)
                        TextButton(
                          onPressed: _showFailures,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            '失败原因',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      TextButton(
                        onPressed: _retry,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('重试', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              Divider(height: 1, color: _divider),
              Expanded(
                child: loading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.5),
                            SizedBox(height: 12),
                            Text(
                              '正在搜索可用书源…',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _visibleCandidates.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            error ??
                                (_keyword.trim().isEmpty
                                    ? '未找到其它可用书源'
                                    : '没有匹配「${_keyword.trim()}」的结果'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: _secondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _visibleCandidates.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: _divider),
                        itemBuilder: (ctx, i) {
                          final c = _visibleCandidates[i];
                          final isCurrent =
                              book != null &&
                              c.source.bookSourceUrl == book.sourceUrl;
                          final author = cleanAuthor(c.hit.author);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            title: Text(
                              c.source.bookSourceName.isNotEmpty
                                  ? c.source.bookSourceName
                                  : c.source.bookSourceUrl,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                            subtitle: Text(
                              [
                                c.hit.name,
                                if (author.isNotEmpty) author,
                                if (c.hit.lastChapter.isNotEmpty)
                                  c.hit.lastChapter,
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _secondary,
                                height: 1.35,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrent)
                                  Text(
                                    '当前',
                                    style: TextStyle(
                                      color: AppColors.accentOf(context),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else ...[
                                  Icon(Icons.chevron_right, color: _secondary),
                                  PopupMenuButton<String>(
                                    tooltip: '书源操作',
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.more_vert,
                                      size: 18,
                                      color: _secondary,
                                    ),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'top':
                                          _moveSource(c, toTop: true);
                                        case 'bottom':
                                          _moveSource(c, toTop: false);
                                        case 'disable':
                                          _disableSource(c);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'top',
                                        child: Text('置顶此书源'),
                                      ),
                                      PopupMenuItem(
                                        value: 'bottom',
                                        child: Text('置底此书源'),
                                      ),
                                      PopupMenuItem(
                                        value: 'disable',
                                        child: Text('禁用此书源'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            onTap: isCurrent ? null : () => _onPick(c),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outcome of one source during a 换源 sweep.
enum SwitchSourceOutcome { hit, noMatch, failed }

/// Classify a switch-search report for the status row.
///
/// A reachable site whose results do not match the book is 无匹配, not a
/// failure; only unreachable / timed-out / rule-broken sources count as 失败.
SwitchSourceOutcome switchOutcomeOf(SourceSearchReport report, int matched) {
  if (matched > 0) return SwitchSourceOutcome.hit;
  if (!report.reachable) return SwitchSourceOutcome.failed;
  return SwitchSourceOutcome.noMatch;
}

class _Candidate {
  final BookSource source;
  final SearchBook hit;
  _Candidate(this.source, this.hit);
}
