import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/detail/book_detail.dart';
import 'package:langhuan/features/sources/engine/book_source_engine.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/net/analyze_url.dart';
import 'package:langhuan/features/sources/source_model.dart';

/// 详情加载壳：先用搜索结果种子立即推页（点书零等待），
/// 详情在页内加载（对齐文库 DetailLoaderPage 的"先到壳、内容后补"）。
class DetailLoader extends ConsumerStatefulWidget {
  const DetailLoader({super.key, required this.seed});

  final SearchBook seed;

  @override
  ConsumerState<DetailLoader> createState() => _DetailLoaderState();
}

class _DetailLoaderState extends ConsumerState<DetailLoader> {
  final BookSourceEngine _engine = BookSourceEngine();
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final item = widget.seed;
    final resolved = AnalyzeUrl.sanitizeUrl(
      item.bookUrl,
      base: item.sourceUrl,
    );
    if (item.sourceUrl.isEmpty || resolved.isEmpty) {
      setState(() {
        _busy = false;
        _error = '该书详情地址无效，可能书源规则不完整';
      });
      return;
    }
    try {
      final src = await SourceModel().findByUrl(item.sourceUrl);
      if (src == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = '书源不存在：${item.sourceName}';
        });
        return;
      }
      final seed = SearchBook(
        name: item.name,
        author: item.author,
        intro: item.intro,
        coverUrl: item.coverUrl,
        lastChapter: item.lastChapter,
        kind: item.kind,
        bookUrl: resolved,
        sourceUrl: item.sourceUrl,
        sourceName: item.sourceName,
      );
      final info = await _engine.bookInfo(src, resolved, seed: seed);
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
      // 替换为正式详情页（详情页自带 Scaffold）。
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => BookDetail(info)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '获取详情失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scaffold = dark ? AppColors.scaffoldDark : AppColors.scaffold;
    final primary = dark ? AppColors.textOnDark : AppColors.textPrimary;
    final muted = dark ? AppColors.textMutedDark : AppColors.textSecondary;
    final seed = widget.seed;
    return Scaffold(
      backgroundColor: scaffold,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: scaffold,
        title: Text(
          seed.name.isEmpty ? '书籍详情' : seed.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 16, color: primary),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 种子预览：封面 + 书名 + 作者（网络详情到达前的即时内容）。
              // Hero：与来源列表的封面共用 tag，承接封面飞行（批次 5）。
              Hero(
                tag: 'cover-${seed.name}|${seed.author}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: PicWidget(
                    seed.coverUrl,
                    width: 92,
                    height: 130,
                    referer: seed.bookUrl,
                    title: seed.name,
                    baseUrl: seed.sourceUrl,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                seed.name.isEmpty ? '未知书名' : seed.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
              if (seed.author.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  seed.author,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
              const SizedBox(height: 22),
              if (_busy) ...[
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(height: 10),
                Text('正在加载详情…', style: TextStyle(fontSize: 13, color: muted)),
              ] else ...[
                Text(
                  _error ?? '获取详情失败，请稍后重试',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重试'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
