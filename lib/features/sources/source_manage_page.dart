import 'dart:convert';
import 'dart:io';

import 'package:langhuan/core/utils/redact.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:langhuan/features/sources/source_model.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/import/source_import_conflict.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
import 'package:langhuan/features/sources/import/source_validation.dart';
import 'package:langhuan/features/sources/model/source_groups.dart';
import 'package:langhuan/features/sources/source_test_panel.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/features/sources/source_repo_page.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 书源管理：导入 / 启用 / 删除 / 导出 / 批量管理
class SourceManagePage extends ConsumerStatefulWidget {
  const SourceManagePage({super.key});

  @override
  ConsumerState<SourceManagePage> createState() => _SourceManagePageState();
}

class _SourceManagePageState extends ConsumerState<SourceManagePage> {
  bool _agreed = false;
  bool _selectMode = false;
  final Set<String> _selected = <String>{};

  /// Current group filter ('' = 全部). Scope only; never rewrites sources.
  String _groupFilter = '';

  List<BookSource> _visibleSources(SourceModel model) =>
      SourceGroups.filter(model.sources, _groupFilter);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sourceModelProvider).load();
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  void _enterSelectMode() {
    setState(() {
      _selectMode = true;
      _selected.clear();
    });
  }

  /// 全选 / 反选只作用于当前分组筛选下的书源。
  void _selectAll(SourceModel model) {
    setState(() {
      _selected
        ..clear()
        ..addAll(_visibleSources(model).map((e) => e.bookSourceUrl));
    });
  }

  void _invertSelection(SourceModel model) {
    setState(() {
      final all = _visibleSources(
        model,
      ).map((e) => e.bookSourceUrl).toSet();
      final next = all.difference(_selected);
      _selected
        ..clear()
        ..addAll(next);
    });
  }

  Widget _groupChips(List<String> groups, String effective) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final group in ['', ...groups])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  group.isEmpty ? '全部' : group,
                  style: const TextStyle(fontSize: 12),
                ),
                selected: effective == group,
                onSelected: (_) => setState(() => _groupFilter = group),
              ),
            ),
        ],
      ),
    );
  }

  /// 批量移动分组：替换所选书源的 bookSourceGroup（留空 = 清空分组）。
  Future<void> _moveSelectedToGroup(SourceModel model) async {
    if (_selected.isEmpty) {
      BotToast.showText(text: '请先勾选书源');
      return;
    }
    final groups = SourceGroups.collect(model.sources);
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移动到分组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: '分组名称（留空 = 清空分组）',
                border: OutlineInputBorder(),
              ),
            ),
            if (groups.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '已有分组（点击填入）',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final group in groups)
                    ActionChip(
                      label: Text(
                        group,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => ctrl.text = group,
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: Text('移动 ${_selected.length} 个'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    await model.setGroup(_selected.toList(), result);
    BotToast.showText(
      text: result.isEmpty
          ? '已清空所选书源的分组'
          : '已移动到分组「$result」',
    );
    _exitSelectMode();
  }

  Future<void> _exportSelected(SourceModel model) async {
    if (_selected.isEmpty) {
      BotToast.showText(text: '请先勾选书源');
      return;
    }
    try {
      final json = await model.exportSelected(_selected.toList());
      if (json.length > 8 * 1024 * 1024) {
        BotToast.showText(text: '所选书源过大，无法复制到剪贴板，请分批导出');
        return;
      }
      await Clipboard.setData(ClipboardData(text: json));
      BotToast.showText(text: '已复制 ${_selected.length} 个书源 JSON 到剪贴板');
    } catch (e) {
      BotToast.showText(text: '导出失败：${Redact.userMessage(e)}');
    }
  }

  Future<void> _enableSelected(SourceModel model) async {
    if (_selected.isEmpty) {
      BotToast.showText(text: '请先勾选书源');
      return;
    }
    await model.enableMany(_selected.toList());
    BotToast.showText(text: '已启用 ${_selected.length} 个书源');
    _exitSelectMode();
  }

  Future<void> _disableSelected(SourceModel model) async {
    if (_selected.isEmpty) {
      BotToast.showText(text: '请先勾选书源');
      return;
    }
    await model.disableMany(_selected.toList());
    BotToast.showText(text: '已禁用 ${_selected.length} 个书源');
    _exitSelectMode();
  }

  Future<void> _deleteSelected(SourceModel model) async {
    if (_selected.isEmpty) {
      BotToast.showText(text: '请先勾选书源');
      return;
    }
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除书源'),
        content: Text('确定删除已选的 $n 个书源？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await model.removeMany(_selected.toList());
    BotToast.showText(text: '已删除 $n 个书源');
    _exitSelectMode();
  }

  Future<void> _deleteSource(SourceModel model, BookSource source) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除书源'),
        content: Text('确定删除「${source.bookSourceName}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) await model.remove(source);
  }

  Future<void> _testSourceDialog(SourceModel model, BookSource source) {
    final name = source.bookSourceName.isEmpty
        ? source.bookSourceUrl
        : source.bookSourceName;
    return showSourceTestSheet(
      context: context,
      sourceName: name,
      sourceUrl: source.bookSourceUrl,
      initialKeyword: '测试',
      onSearch: (keyword) => model.testSourceSearch(source, keyword),
    );
  }

  Future<bool?> _askImportIssues(
    BuildContext context,
    SourceValidationReport report,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('部分书源未通过校验'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '可导入 ${report.valid.length} 个；'
                '${report.invalid.length} 个有问题：',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: report.invalid.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (_, i) {
                    final item = report.invalid[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.problem} · ${item.hint}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('仅导入可用的 ${report.valid.length} 个'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(sourceModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '已选 ${_selected.length}' : '书源管理'),
        leading: _selectMode
            ? IconButton(
                tooltip: '取消',
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              )
            : null,
        actions: _selectMode
            ? [
                TextButton(
                  onPressed: () => _selectAll(model),
                  child: const Text('全选'),
                ),
                TextButton(
                  onPressed: () => _invertSelection(model),
                  child: const Text('反选'),
                ),
              ]
            : [
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SourceRepoPage()),
                    );
                    if (mounted) ref.read(sourceModelProvider).load();
                  },
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('私有仓库'),
                ),
                if (model.sources.isNotEmpty)
                  IconButton(
                    tooltip: '批量管理',
                    icon: const Icon(Icons.checklist),
                    onPressed: _enterSelectMode,
                  ),
                IconButton(
                  tooltip: '导出',
                  icon: const Icon(Icons.upload_file),
                  onPressed: () async {
                    try {
                      final json = await model.exportAll();
                      // Very large payloads OOM the clipboard MethodChannel.
                      if (json.length > 8 * 1024 * 1024) {
                        BotToast.showText(
                          text:
                              '书源过大（${(json.length / (1024 * 1024)).toStringAsFixed(1)}MB），'
                              '无法复制到剪贴板，请分批导出或从源文件备份',
                        );
                        return;
                      }
                      await Clipboard.setData(ClipboardData(text: json));
                      BotToast.showText(text: '已复制全部书源 JSON 到剪贴板');
                    } catch (e) {
                      BotToast.showText(text: '导出失败：${Redact.userMessage(e)}');
                    }
                  },
                ),
                IconButton(
                  tooltip: '导入',
                  icon: const Icon(Icons.add),
                  onPressed: () => _showImport(context, model),
                ),
              ],
      ),
      body: model.loading && model.sources.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : model.sources.isEmpty
          ? _empty(context, model)
          : Builder(
              builder: (context) {
                final groups = SourceGroups.collect(model.sources);
                final effective = groups.contains(_groupFilter)
                    ? _groupFilter
                    : '';
                final visible = SourceGroups.filter(model.sources, effective);
                return Column(
                  children: [
                    if (groups.length > 1) _groupChips(groups, effective),
                    Expanded(
                      child: visible.isEmpty
                          ? Center(
                              child: Text(
                                '该分组下暂无书源',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.only(
                                bottom:
                                    12 +
                                    MediaQuery.viewPaddingOf(context).bottom,
                              ),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final s = visible[i];
                final url = s.bookSourceUrl;
                final selected = _selected.contains(url);
                return ListTile(
                  onTap: _selectMode
                      ? () {
                          setState(() {
                            if (selected) {
                              _selected.remove(url);
                            } else {
                              _selected.add(url);
                            }
                          });
                        }
                      : null,
                  leading: _selectMode
                      ? Checkbox(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selected.add(url);
                              } else {
                                _selected.remove(url);
                              }
                            });
                          },
                        )
                      : null,
                  title: Text(
                    s.bookSourceName.isEmpty
                        ? s.bookSourceUrl
                        : s.bookSourceName,
                  ),
                  subtitle: Text(
                    [
                      if (s.bookSourceGroup.isNotEmpty) s.bookSourceGroup,
                      if (s.lastCheckTime > 0)
                        s.respondTime > 0 ? '${s.respondTime}ms' : '测试失败'
                      else if (s.respondTime > 0 && s.respondTime < 60000)
                        '${s.respondTime}ms',
                      s.canExplore ? '可发现' : '仅搜索',
                      s.bookSourceUrl,
                    ].where((e) => e.isNotEmpty).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _selectMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: s.enabled,
                              onChanged: (_) => model.toggle(s),
                            ),
                            PopupMenuButton<String>(
                              tooltip: '更多',
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'test') {
                                  _testSourceDialog(model, s);
                                }
                                if (value == 'delete') {
                                  _deleteSource(model, s);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'test',
                                  child: Text('测试搜索'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                            ),
                          ],
                        ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: _selectMode
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _enableSelected(model),
                            child: const Text('启用'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _disableSelected(model),
                            child: const Text('禁用'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _deleteSelected(model),
                            child: const Text('删除'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _moveSelectedToGroup(model),
                            child: const Text('移动到分组'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _exportSelected(model),
                            child: const Text('导出选中'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _empty(BuildContext context, SourceModel model) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.library_books_outlined,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            const Text('还没有书源', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              '请自行导入 Legado / 阅读 书源 JSON。\n应用不附带任何书源。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showImport(context, model),
              icon: const Icon(Icons.add),
              label: const Text('导入书源'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SourceRepoPage()),
                );
                if (mounted) ref.read(sourceModelProvider).load();
              },
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('从私有仓库同步'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _askOverwrite(
    BuildContext context,
    SourceImportConflict conflict,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('发现规则不同的书源'),
        content: Text(
          '本次导入包含 ${conflict.newCount} 个新书源；'
          '${conflict.changedCount} 个已有书源规则不同'
          '${conflict.unchangedCount > 0 ? '，${conflict.unchangedCount} 个规则相同' : ''}。\n\n'
          '新书源会正常添加。已有书源默认保留本地规则；'
          '只有选择「覆盖本地规则」才会用导入内容更新这 '
          '${conflict.changedCount} 个书源。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留本地'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('覆盖本地规则'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImport(BuildContext context, SourceModel model) async {
    final textCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    var agreed = _agreed;
    var tab = 0; // 0 paste, 1 url, 2 local file
    var fileName = '';
    var fileText = '';
    var fileBusy = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '导入书源',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '书源由用户自行导入，仅供学习交流。请勿导入或使用侵犯他人版权的书源。由此产生的法律责任由用户自行承担。',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        '我已阅读并同意上述声明',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: agreed,
                      onChanged: (v) => setSt(() {
                        agreed = v ?? false;
                        _agreed = agreed;
                      }),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('粘贴 JSON'),
                          selected: tab == 0,
                          onSelected: (_) => setSt(() => tab = 0),
                        ),
                        ChoiceChip(
                          label: const Text('网络 URL'),
                          selected: tab == 1,
                          onSelected: (_) => setSt(() => tab = 1),
                        ),
                        ChoiceChip(
                          label: const Text('本地文件'),
                          selected: tab == 2,
                          onSelected: (_) => setSt(() => tab = 2),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.cloud_download_outlined,
                            size: 18,
                          ),
                          label: const Text('私有仓库'),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SourceRepoPage(),
                              ),
                            );
                            if (mounted) {
                              ref.read(sourceModelProvider).load();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (tab == 0)
                      TextField(
                        controller: textCtrl,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '粘贴 Legado 书源 JSON（对象或数组）',
                        ),
                      )
                    else if (tab == 1)
                      TextField(
                        controller: urlCtrl,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'https://example.com/sources.json',
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: fileBusy
                                ? null
                                : () async {
                                    setSt(() => fileBusy = true);
                                    try {
                                      final picked = await FilePicker
                                          .pickFiles(withData: true);
                                      if (picked == null ||
                                          picked.files.isEmpty) {
                                        return;
                                      }
                                      final f = picked.files.single;
                                      final bytes = f.bytes ??
                                          (f.path != null
                                              ? await File(f.path!)
                                                  .readAsBytes()
                                              : null);
                                      if (bytes == null) {
                                        BotToast.showText(
                                          text: '读取文件失败',
                                        );
                                        return;
                                      }
                                      var text = const Utf8Decoder(
                                        allowMalformed: true,
                                      ).convert(bytes);
                                      if (text.isNotEmpty &&
                                          text.codeUnitAt(0) == 0xFEFF) {
                                        text = text.substring(1);
                                      }
                                      setSt(() {
                                        fileName = f.name;
                                        fileText = text;
                                      });
                                    } catch (e) {
                                      BotToast.showText(
                                        text: '读取文件失败：${e.runtimeType}',
                                      );
                                    } finally {
                                      setSt(() => fileBusy = false);
                                    }
                                  },
                            icon: const Icon(
                              Icons.folder_open_outlined,
                              size: 18,
                            ),
                            label: Text(
                              fileName.isEmpty ? '选择书源文件' : fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            fileText.isEmpty
                                ? '支持 Legado / 阅读 导出的 .json；大文件在后台解析，不卡界面。'
                                : '已读取 ${(fileText.length / 1024).toStringAsFixed(0)} KB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (!agreed) {
                          BotToast.showText(text: '请先勾选同意上述声明');
                          return;
                        }
                        try {
                          if (tab == 1) {
                            BotToast.showText(text: '正在下载书源…');
                          }
                          final SourceParseResult parsed;
                          if (tab == 0) {
                            parsed = SourceImporter.parseJson(textCtrl.text);
                          } else if (tab == 1) {
                            parsed = await SourceImporter.fromUrl(
                              urlCtrl.text.trim(),
                            );
                          } else {
                            if (fileText.isEmpty) {
                              BotToast.showText(text: '请先选择书源文件');
                              return;
                            }
                            BotToast.showText(text: '正在解析书源文件…');
                            // Multi-MB packs would jank the UI thread.
                            parsed = fileText.length > 200 * 1024
                                ? await compute(
                                    SourceImporter.parseJson,
                                    fileText,
                                  )
                                : SourceImporter.parseJson(fileText);
                          }
                          if (!ctx.mounted) return;
                          if (parsed.sources.isEmpty) {
                            await model.importParsed(parsed, agreed: true);
                            if (ctx.mounted) Navigator.pop(ctx);
                            return;
                          }

                          // 导入前校验：结构有问题的源默认不写入，用户可明确选择
                          // 「仅导入可用的 N 个」。
                          var checked = parsed;
                          final validation = SourceValidator.validate(parsed);
                          if (validation.invalid.isNotEmpty) {
                            final keepValid = await _askImportIssues(
                              ctx,
                              validation,
                            );
                            if (keepValid != true) return;
                            checked = SourceParseResult(
                              sources: validation.valid,
                              skipped:
                                  parsed.skipped + validation.invalid.length,
                              duplicatesInBatch: parsed.duplicatesInBatch,
                            );
                          }
                          if (checked.sources.isEmpty) {
                            BotToast.showText(text: '没有通过校验的书源可导入');
                            return;
                          }

                          final conflict = await model.inspectImport(checked);
                          var overwrite = false;
                          if (conflict.hasChanged) {
                            if (!ctx.mounted) return;
                            final choice = await _askOverwrite(ctx, conflict);
                            if (choice == null) return;
                            overwrite = choice;
                          } else if (conflict.newCount == 0) {
                            BotToast.showText(text: '没有需要导入或更新的书源');
                            return;
                          }

                          final toImport = overwrite
                              ? conflict.withoutUnchanged(checked)
                              : checked;
                          await model.importParsed(
                            toImport,
                            agreed: true,
                            overwriteExistingRules: overwrite,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          BotToast.showText(text: e.toString());
                        }
                      },
                      child: const Text('导入'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
