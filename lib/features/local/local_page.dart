import 'dart:convert';

import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/design/components/page_header.dart';
import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/local/local_import_service.dart';

/// Local TXT library: imported files live in reader.db and open in the
/// existing reader without a book source.
class LocalPage extends StatefulWidget {
  const LocalPage({super.key});

  @override
  State<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends State<LocalPage> {
  final _books = BookRepository.instance;
  final _imports = LocalImportService();
  List<Book> _list = const [];
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await _books.getLocal();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _importTxt() async {
    if (_importing) return;
    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
        withData: false,
        allowMultiple: true,
      );
    } catch (e) {
      BotToast.showText(text: '无法打开文件选择器：$e');
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    setState(() => _importing = true);
    var ok = 0;
    String? firstError;
    LocalImportResult? last;
    for (final file in picked.files) {
      try {
        final result = await _imports.importFile(file);
        last = result;
        ok++;
      } catch (e) {
        firstError ??= '$e';
      }
    }
    if (!mounted) return;
    setState(() => _importing = false);
    await _reload();
    if (ok > 0) {
      final name = last?.book.name ?? '';
      BotToast.showText(
        text: ok == 1 ? '已导入《$name》' : '已导入 $ok 本',
      );
    } else {
      BotToast.showText(text: '导入失败：${firstError ?? '未知错误'}');
    }
  }

  Future<void> _open(Book book) async {
    await Routes.navigateTo(
      context,
      Routes.read,
      params: {'read': jsonEncode(book.toJson())},
    );
    _reload();
  }

  Future<void> _delete(Book book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出本地书库'),
        content: Text('删除《${book.name}》及其章节缓存？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _list = _list.where((b) => b.id != book.id).toList(growable: false);
    });
    try {
      await _books.delete(book.id);
    } catch (e) {
      BotToast.showText(text: '删除失败：$e');
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? AppColors.scaffoldDark : AppColors.paper;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              title: '本地',
              actions: [
                IconButton(
                  tooltip: '导入 TXT',
                  onPressed: _importing ? null : _importTxt,
                  icon: const Icon(Icons.add, size: 21),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _importing ? null : _importTxt,
                  icon: const Icon(Icons.file_open_outlined, size: 17),
                  label: Text(_importing ? '正在导入…' : '导入 TXT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: dark ? AppColors.dividerDark : AppColors.line,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
            ),
            if (_importing)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _body(dark)),
          ],
        ),
      ),
    );
  }

  Widget _body(bool dark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_list.isEmpty) return _empty(dark);
    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: _list.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: dark ? AppColors.dividerDark : AppColors.line,
      ),
      itemBuilder: (context, i) => Material(
        color: Colors.transparent,
        child: _row(_list[i], dark),
      ),
    );
  }

  Widget _empty(bool dark) {
    final muted = dark ? AppColors.textOnDark : AppColors.inkMute;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '还没有本地书',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: dark ? AppColors.textOnDark : AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '导入 TXT 后会出现在这里，不上传、不同步。',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _importing ? null : _importTxt,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
            ),
            child: const Text('导入 TXT'),
          ),
        ],
      ),
    );
  }

  Widget _row(Book book, bool dark) {
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    final muted = dark ? const Color(0xFFB3B3B3) : AppColors.inkMute;
    final progress = book.readingChapter.isNotEmpty
        ? book.readingChapter
        : '第 ${book.chapterIndex + 1} 章';
    return InkWell(
      onTap: () => _open(book),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: PicWidget(
                book.coverUrl,
                width: 46,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '删除',
              onPressed: () => _delete(book),
              icon: Icon(
                Icons.delete_outline,
                size: 19,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
