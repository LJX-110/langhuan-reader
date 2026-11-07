import 'package:flutter/material.dart';

import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/book_tag.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/data/repositories/tag_repository.dart';
import 'package:langhuan/design/components/feedback.dart';
import 'package:langhuan/design/components/loading_view.dart';
import 'package:langhuan/design/components/pressable.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// 书籍标签编辑：勾选已有标签，或当场新建。
///
/// 标签归属 `book_tags`，要求书籍行已存在（加入过书架）；未加入时给出提示。
class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({super.key, required this.book});

  final Book book;

  static Future<void> show(BuildContext context, Book book) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => TagEditorSheet(book: book),
      );

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  List<BookTag> _tags = const [];
  Set<String> _selected = {};
  bool _loading = true;
  bool _busy = false;
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tags = await TagRepository.instance.all();
    final assigned = await TagRepository.instance.forBook(widget.book.id);
    if (!mounted) return;
    setState(() {
      _tags = tags;
      _selected = assigned.map((tag) => tag.id).toSet();
      _loading = false;
    });
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showError('先输入标签名', context: context);
      return;
    }
    final tag = await TagRepository.instance.create(name);
    if (!mounted) return;
    if (tag == null) {
      showError('标签名过长或不可用', context: context);
      return;
    }
    _nameCtrl.clear();
    await _load();
    if (!mounted) return;
    setState(() => _selected.add(tag.id));
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final exists = await BookRepository.instance.exists(widget.book.id);
      if (!exists) {
        if (mounted) showError('先加入书架，再设置标签', context: context);
        return;
      }
      await TagRepository.instance.setForBook(widget.book.id, _selected);
      if (!mounted) return;
      Navigator.pop(context);
      showFeedback('已更新标签', context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.accentOf(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final dark = theme.brightness == Brightness.dark;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '标签',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: _busy ? null : _save, child: const Text('保存')),
              ],
            ),
            Text(
              widget.book.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: LoadingView(),
              )
            else if (_tags.isEmpty)
              Text('还没有标签，先新建一个。', style: TextStyle(fontSize: 12, color: muted))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _tags)
                    Pressable(
                      onTap: () {
                        setState(() {
                          if (!_selected.remove(tag.id)) {
                            _selected.add(tag.id);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            width: .5,
                            color: _selected.contains(tag.id)
                                ? accent
                                : (dark ? AppColors.dividerDark : AppColors.line),
                          ),
                          color: _selected.contains(tag.id)
                              ? accent.withValues(alpha: .08)
                              : Colors.transparent,
                        ),
                        child: Text(
                          tag.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: _selected.contains(tag.id) ? accent : muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    maxLength: 24,
                    decoration: const InputDecoration(
                      hintText: '新建标签',
                      counterText: '',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(onPressed: _create, child: const Text('新建')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
