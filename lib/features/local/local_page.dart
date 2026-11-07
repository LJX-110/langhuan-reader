import 'dart:convert';

import 'package:langhuan/core/utils/redact.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/design/components/bookshelf_3d.dart';
import 'package:langhuan/design/components/page_header.dart';
import 'package:langhuan/design/components/shelf_book_view.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/local/local_import_service.dart';
import 'package:langhuan/design/components/feedback.dart';
import 'package:langhuan/design/components/loading_view.dart';

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
  int _importDone = 0;
  int _importTotal = 0;

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
      showError('无法打开文件选择器：${Redact.userMessage(e)}');
      return;
    }
    if (picked == null || picked.files.isEmpty) return;
    final files = picked.files;

    setState(() {
      _importing = true;
      _importDone = 0;
      _importTotal = files.length;
    });
    var ok = 0;
    final failures = <String>[];
    LocalImportResult? last;
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      try {
        final result = await _imports.importFile(file);
        last = result;
        ok++;
      } catch (e) {
        failures.add('${file.name.isEmpty ? '未命名文件' : file.name}：$e');
      }
      if (mounted) setState(() => _importDone = i + 1);
    }
    if (!mounted) return;
    setState(() => _importing = false);
    await _reload();
    if (failures.isEmpty) {
      final name = last?.book.name ?? '';
      showFeedback(ok == 1 ? '已导入《$name》' : '已导入 $ok 本');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入结果'),
        content: SingleChildScrollView(
          child: Text(
            '成功 $ok 本，失败 ${failures.length} 本\n\n${failures.join('\n')}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _open(Book book) async {
    await Routes.navigateTo(
      context,
      Routes.read,
      params: {'read': jsonEncode(book.toJson())},
    );
    _reload();
  }

  Future<void> _openById(String id) async {
    for (final book in _list) {
      if (book.id == id) {
        await _open(book);
        return;
      }
    }
  }

  Future<void> _deleteById(String id) async {
    for (final book in _list) {
      if (book.id == id) {
        await _delete(book);
        return;
      }
    }
  }

  /// Deletion after the shelf's inline confirm; the page no longer opens its
  /// own dialog so 书架 / 本地 share one interaction.
  Future<void> _delete(Book book) async {
    setState(() {
      _list = _list.where((b) => b.id != book.id).toList(growable: false);
    });
    try {
      await _books.delete(book.id);
    } catch (e) {
      showError('删除失败：${Redact.userMessage(e)}');
      await _reload();
    }
  }

  /// 本地书信息修正：只改书架显示的书名 / 作者，不改原文件。
  Future<void> _editInfo(String id) async {
    Book? book;
    for (final b in _list) {
      if (b.id == id) {
        book = b;
        break;
      }
    }
    if (book == null) return;
    final nameCtrl = TextEditingController(text: book.name);
    final authorCtrl = TextEditingController(text: book.author);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑本地书信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '书名',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: authorCtrl,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '作者',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, (
              nameCtrl.text.trim(),
              authorCtrl.text.trim(),
            )),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    authorCtrl.dispose();
    if (result == null || !mounted) return;
    final (name, author) = result;
    if (name.isEmpty) {
      showError('书名不能为空', context: context);
      return;
    }
    await _books.updateMetadata(bookId: book.id, name: name, author: author);
    if (!mounted) return;
    setState(() {
      book!
        ..name = name
        ..author = author;
    });
    showFeedback('已更新《$name》');
  }

  /// Default focus: the most recently read local book, else the first one.
  String? _initialFocusId() {
    for (final book in _list) {
      if (book.readingChapter.trim().isNotEmpty ||
          book.chapterIndex > 0 ||
          book.pageIndex > 0) {
        return book.id;
      }
    }
    return _list.isEmpty ? null : _list.first.id;
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
                  label: Text(
                    _importing
                        ? (_importTotal > 0
                              ? '正在导入 $_importDone/$_importTotal…'
                              : '正在导入…')
                        : '导入 TXT',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentOf(context),
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
              LoadingBar(
                minHeight: 2,
                value: _importTotal > 0 ? _importDone / _importTotal : null,
              ),
            Expanded(child: _body(dark)),
          ],
        ),
      ),
    );
  }

  Widget _body(bool dark) {
    if (_loading) {
      return const LoadingView.page();
    }
    if (_list.isEmpty) return _empty(dark);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Bookshelf3D(
        entryAnimation: !SpUtil.getBool(PrefsKeys.lowPerformance),
        books: _list.map(ShelfBookView.fromBook).toList(growable: false),
        initialBookId: _initialFocusId(),
        onOpen: (view) => _openById(view.id),
        onDelete: (view) => _deleteById(view.id),
        onLongPress: (view) => _editInfo(view.id),
        deleteWarning: '删除后无法撤销',
      ),
    );
  }

  Widget _empty(bool dark) {
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
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
            '导入 TXT 后会出现在这里，不上传、不同步。长按书脊可改书名 / 作者。',
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
}
