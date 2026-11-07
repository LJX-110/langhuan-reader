import 'package:extended_image/extended_image.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/core/utils/app_log.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/features/sources/engine/source_engine.dart';
import 'package:flutter/material.dart';
import 'package:langhuan/design/components/empty_state.dart';
import 'package:langhuan/design/components/loading_view.dart';

/// Cache management against [reader.db] chapter bodies + page layouts.
class CacheManager extends StatefulWidget {
  const CacheManager({super.key});

  @override
  State<CacheManager> createState() => _CacheManagerState();
}

class _CacheManagerState extends State<CacheManager> {
  final BookRepository _books = BookRepository.instance;
  final ChapterRepository _chapters = ChapterRepository.instance;

  bool _loading = true;
  int _pageCacheBytes = 0;
  int _bodyBytes = 0;
  int _engineBytes = 0;
  List<_BookCacheRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final books = await _books.getAll();
      final pageBytes = await _chapters.pageCacheBytes();
      final bodyBytes = await _chapters.bodyCacheBytes();
      final engineBytes = await SourceEngine.instance.engineCacheBytes();
      final rows = <_BookCacheRow>[];
      for (final book in books) {
        final stats = await _chapters.bodyStats(book.id);
        rows.add(_BookCacheRow(book: book, stats: stats));
      }
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _pageCacheBytes = pageBytes;
        _bodyBytes = bodyBytes;
        _engineBytes = engineBytes;
        _loading = false;
      });
    } catch (e, st) {
      AppLog.w('Cache', 'reload failed', error: e);
      AppLog.d('Cache', '$st');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _clearPageLayouts() async {
    await _chapters.clearAllPageLayouts();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除分页缓存')));
    await _reload();
  }

  Future<void> _clearCoverCache() async {
    final done = await clearDiskCachedImages();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(done ? '已清除封面缓存' : '封面缓存清理失败')));
  }

  Future<void> _clearEngineCache() async {
    final ok = await _confirm(
      '清除引擎缓存',
      '将清除书源临时缓存与源变量；不会删除书架、阅读记录与登录状态。',
      confirmLabel: '清除',
    );
    if (!ok || !mounted) return;
    await SourceEngine.instance.clearEngineCache();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除引擎缓存')));
    await _reload();
  }

  Future<void> _clearLoginState() async {
    final ok = await _confirm(
      '清除登录状态',
      '将清除所有书源的 Cookie / 登录态；下次访问需要重新登录。',
      confirmLabel: '清除',
    );
    if (!ok || !mounted) return;
    await SourceEngine.instance.clearCookies();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除登录状态')));
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmLabel = '清除',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _clearBookBodies(String bookId, String bookName) async {
    final ok = await _confirm(
      '清除缓存',
      '删除《$bookName》已缓存的章节正文与分页缓存？\n目录、书架与阅读进度都会保留。',
    );
    if (!ok || !mounted) return;
    // 只清正文/分页，保留目录行（分卷、章节信息不丢）。
    await _chapters.clearBodies(bookId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除本书章节缓存（目录保留）')));
    await _reload();
  }

  Future<void> _clearAllBodies() async {
    final ok = await _confirm(
      '清除全部章节正文',
      '删除所有书已缓存的章节正文与分页缓存？\n目录、书架与阅读进度都会保留。',
    );
    if (!ok || !mounted) return;
    await _chapters.clearAllBodies();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除全部章节正文')));
    await _reload();
  }

  /// 移出书架：保留记录、进度与缓存（与书架页 retire 语义一致）。
  Future<void> _retireBook(String bookId, String bookName) async {
    final ok = await _confirm(
      '移出书架',
      '把《$bookName》移出书架？\n阅读记录、进度与章节缓存都会保留。',
      confirmLabel: '移出',
    );
    if (!ok || !mounted) return;
    await _books.retire([bookId]);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已移出书架（记录与缓存保留）')));
    await _reload();
  }

  /// 彻底删除：书行 + 章节缓存 + 书签 + 阅读记录（数据库级联）。
  Future<void> _deleteBook(String bookId, String bookName) async {
    final ok = await _confirm(
      '彻底删除',
      '从书库彻底删除《$bookName》？\n章节缓存、书签与阅读记录会一并删除，不可恢复。',
      confirmLabel: '删除',
    );
    if (!ok || !mounted) return;
    await _books.delete(bookId);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已彻底删除本书及其缓存')));
    await _reload();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('缓存管理'),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _clearPageLayouts,
            child: const Text('清分页'),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView.page()
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  24 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  Card(
                    child: ListTile(
                      title: const Text('分页缓存占用'),
                      subtitle: Text(_formatBytes(_pageCacheBytes)),
                      trailing: IconButton(
                        tooltip: '清除全部分页缓存',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _clearPageLayouts,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      title: const Text('章节正文缓存'),
                      subtitle: Text(_formatBytes(_bodyBytes)),
                      trailing: IconButton(
                        tooltip: '清除全部章节正文',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _loading || _bodyBytes == 0
                            ? null
                            : _clearAllBodies,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      title: const Text('封面磁盘缓存'),
                      subtitle: const Text('清理后封面会重新下载；可解决旧图/错图'),
                      trailing: IconButton(
                        tooltip: '清除封面缓存',
                        icon: const Icon(Icons.image_not_supported_outlined),
                        onPressed: _loading ? null : _clearCoverCache,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      title: const Text('引擎缓存'),
                      subtitle: Text(_formatBytes(_engineBytes)),
                      trailing: IconButton(
                        tooltip: '清除引擎缓存',
                        icon: const Icon(Icons.cleaning_services_outlined),
                        onPressed: _loading ? null : _clearEngineCache,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      title: const Text('登录状态 / Cookie'),
                      subtitle: const Text('清除所有书源的登录态；不会删除书架与阅读记录'),
                      trailing: IconButton(
                        tooltip: '清除登录状态',
                        icon: const Icon(Icons.logout_outlined),
                        onPressed: _loading ? null : _clearLoginState,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('书籍章节缓存', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: EmptyState(
                        title: '书架还没有书',
                        hint: '添加书籍后，这里会显示每本书的章节缓存占用。',
                      ),
                    )
                  else
                    ..._rows.map((row) {
                      final total = row.stats.total;
                      final withBody = row.stats.withBody;
                      final progress = total == 0 ? 0.0 : withBody / total;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row.book.name.isEmpty
                                    ? row.book.id
                                    : row.book.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LoadingBar(
                                        value: progress,
                                        minHeight: 6,
                                        backgroundColor: AppColors.divider,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$withBody / $total',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: '更多操作',
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (action) {
                                      if (action == 'clear') {
                                        _clearBookBodies(
                                          row.book.id,
                                          row.book.name,
                                        );
                                      } else if (action == 'retire') {
                                        _retireBook(row.book.id, row.book.name);
                                      } else {
                                        _deleteBook(row.book.id, row.book.name);
                                      }
                                    },
                                    itemBuilder: (ctx) => const [
                                      PopupMenuItem(
                                        value: 'clear',
                                        child: Text('清除章节缓存（保留目录/进度）'),
                                      ),
                                      PopupMenuItem(
                                        value: 'retire',
                                        child: Text('移出书架（保留记录）'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('彻底删除（含缓存与记录）'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _BookCacheRow {
  const _BookCacheRow({required this.book, required this.stats});

  final Book book;
  final ({int total, int withBody}) stats;
}
