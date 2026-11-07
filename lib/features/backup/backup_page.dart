import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:langhuan/app/providers.dart';
import 'package:langhuan/design/components/feedback.dart';
import 'package:langhuan/design/components/loading_view.dart';
import 'package:langhuan/features/backup/backup_service.dart';

/// 备份与恢复：只备份元数据/进度/书签/阅读记录/标签/替换规则，
/// 不含章节正文、分页缓存、Cookie、Token、字体文件。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _includeSources = false;
  bool _busy = false;

  BackupService get _service => BackupService.instance;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _service.exportBytes(includeSources: _includeSources);
      final name = _fileName();
      final path = await FilePicker.saveFile(
        dialogTitle: '保存备份',
        fileName: name,
        type: FileType.any,
        bytes: bytes,
      );
      if (!mounted) return;
      if (path == null) return;
      showFeedback('备份已保存：$name', context: context);
    } on BackupFormatException catch (e) {
      if (mounted) showError(e.message, context: context);
    } catch (_) {
      if (mounted) showError('导出失败，请稍后重试', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: '选择备份文件',
        type: FileType.any,
        withData: true,
      );
      if (!mounted) return;
      final file = picked?.files.single;
      if (file == null) return;
      final bytes = await _readFile(file);
      final preview = await _service.preview(bytes);
      if (!mounted) return;
      final confirmed = await _confirm(preview);
      if (!mounted || !confirmed) return;

      setState(() => _busy = true);
      final result = await _service.apply(bytes);
      await ref.read(shelfModelProvider).initShelf();
      if (result.sources > 0) {
        await ref.read(sourceModelProvider).load();
      }
      if (!mounted) return;
      showFeedback(result.summary, context: context);
    } on BackupFormatException catch (e) {
      if (mounted) showError(e.message, context: context);
    } catch (_) {
      if (mounted) showError('恢复失败，数据未改动，请检查文件后重试', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List> _readFile(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) return bytes;
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw const BackupFormatException('无法读取所选文件');
    }
    return File(path).readAsBytes();
  }

  Future<bool> _confirm(BackupPreview preview) async {
    final date = DateTime.fromMillisecondsSinceEpoch(preview.createdAt);
    final when =
        '${date.year}-${_two(date.month)}-${_two(date.day)} '
        '${_two(date.hour)}:${_two(date.minute)}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复备份'),
        content: Text(
          '备份时间：$when\n'
          '版本：${preview.appVersion.isEmpty ? '未知' : preview.appVersion}\n\n'
          '书籍 ${preview.books} 本 ｜ 书签 ${preview.bookmarks} 个 ｜ '
          '阅读记录 ${preview.history} 条 ｜ 标签 ${preview.tags} 个'
          '${preview.replaceRules > 0 ? ' ｜ 替换规则 ${preview.replaceRules} 条' : ''}'
          '${preview.includeSources ? ' ｜ 书源 ${preview.sources} 个' : ''}\n\n'
          '恢复为合并写入：本地已有的书与进度不会被覆盖；'
          '书签与阅读记录取较新的一份；书源与替换规则只补缺失项。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  String _fileName() {
    final now = DateTime.now();
    return 'langhuan-${now.year}${_two(now.month)}${_two(now.day)}-'
        '${_two(now.hour)}${_two(now.minute)}.lhb';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复'), centerTitle: true),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              Card(
                child: SwitchListTile(
                  title: const Text('包含书源'),
                  subtitle: const Text('含书源规则原文；恢复时只补缺失项，不覆盖本地编辑'),
                  value: _includeSources,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _includeSources = value),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '备份内容：书籍信息、阅读进度、书签、阅读记录、标签、替换净化规则'
                '${_includeSources ? '、书源' : ''}。\n'
                '不含：章节正文、分页缓存、登录 Cookie、仓库 Token、字体文件。\n'
                '备份文件未加密，导出后请自行妥善保存。',
                style: TextStyle(fontSize: 12, height: 1.7, color: muted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.ios_share),
                label: const Text('导出备份'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.restore),
                label: const Text('从文件恢复'),
              ),
              const SizedBox(height: 18),
              Text(
                '建议在换机、清除数据或大版本升级前导出一份，保存到本机文件管理器。',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
          if (_busy)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LoadingBar(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
