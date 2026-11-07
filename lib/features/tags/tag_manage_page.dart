import 'package:flutter/material.dart';

import 'package:langhuan/data/entities/book_tag.dart';
import 'package:langhuan/data/repositories/tag_repository.dart';
import 'package:langhuan/design/components/empty_state.dart';
import 'package:langhuan/design/components/feedback.dart';
import 'package:langhuan/design/components/loading_view.dart';
import 'package:langhuan/design/components/pressable.dart';

/// 标签管理：新建、重命名、删除；删除会同时移除书籍归属。
class TagManagePage extends StatefulWidget {
  const TagManagePage({super.key});

  @override
  State<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends State<TagManagePage> {
  List<BookTag> _tags = const [];
  Map<String, int> _counts = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final tags = await TagRepository.instance.all();
    final counts = await TagRepository.instance.counts();
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _counts = counts;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final name = await _askName(title: '新建标签');
    if (name == null || !mounted) return;
    final tag = await TagRepository.instance.create(name);
    if (!mounted) return;
    if (tag == null) {
      showError('标签名过长或不可用', context: context);
      return;
    }
    await _reload();
  }

  Future<void> _rename(BookTag tag) async {
    final name = await _askName(title: '重命名标签', initial: tag.name);
    if (name == null || !mounted) return;
    final ok = await TagRepository.instance.rename(tag.id, name);
    if (!mounted) return;
    if (!ok) {
      showError('名称已被占用或不可用', context: context);
      return;
    }
    await _reload();
  }

  Future<void> _delete(BookTag tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${tag.name}」'),
        content: const Text('标签及其书籍归属会一起删除，书籍本身与进度不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await TagRepository.instance.delete(tag.id);
    if (!mounted) return;
    showFeedback('已删除标签「${tag.name}」');
    await _reload();
  }

  Future<String?> _askName({required String title, String initial = ''}) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: '标签名', counterText: ''),
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return (result == null || result.isEmpty) ? null : result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        centerTitle: true,
        actions: [TextButton(onPressed: _create, child: const Text('新建'))],
      ),
      body: _loading
          ? const LoadingView.page()
          : _tags.isEmpty
          ? const EmptyState(
              title: '还没有标签',
              hint: '在书籍详情底部点「标签」即可创建。',
              alignment: EmptyStateAlignment.center,
            )
          : ListView.separated(
              itemCount: _tags.length,
              separatorBuilder: (_, _) => const Divider(height: .5),
              itemBuilder: (context, i) {
                final tag = _tags[i];
                final count = _counts[tag.id] ?? 0;
                return Pressable(
                  onTap: () => _rename(tag),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tag.name,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        Text(
                          '$count 本',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: '删除标签',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _delete(tag),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
