import 'package:flutter/material.dart';

import 'package:langhuan/data/entities/replace_rule.dart';
import 'package:langhuan/data/repositories/replace_rule_repository.dart';
import 'package:langhuan/design/components/feedback.dart';
import 'package:langhuan/design/components/loading_view.dart';
import 'package:langhuan/design/components/pressable.dart';

/// 替换净化：全局规则列表。
///
/// 规则只作用于显示层（正文加载与目录标题），不改写章节缓存；
/// 修改后重新打开章节即可看到效果。
class ReplaceRulesPage extends StatefulWidget {
  const ReplaceRulesPage({super.key});

  @override
  State<ReplaceRulesPage> createState() => _ReplaceRulesPageState();
}

class _ReplaceRulesPageState extends State<ReplaceRulesPage> {
  List<ReplaceRule> _rules = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final rules = await ReplaceRuleRepository.instance.all();
    if (!mounted) return;
    setState(() {
      _rules = rules;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final draft = await _editRule();
    if (draft == null || !mounted) return;
    final rule = await ReplaceRuleRepository.instance.create(
      name: draft.name,
      pattern: draft.pattern,
      replacement: draft.replacement,
      isRegex: draft.isRegex,
      scopeContent: draft.scopeContent,
      scopeTitle: draft.scopeTitle,
    );
    if (!mounted) return;
    if (rule == null) {
      showError('规则未保存：匹配内容为空或格式无效', context: context);
      return;
    }
    await _reload();
  }

  Future<void> _edit(ReplaceRule rule) async {
    final draft = await _editRule(rule: rule);
    if (draft == null || !mounted) return;
    final ok = await ReplaceRuleRepository.instance.update(
      rule.copyWith(
        name: draft.name,
        pattern: draft.pattern,
        replacement: draft.replacement,
        isRegex: draft.isRegex,
        scopeContent: draft.scopeContent,
        scopeTitle: draft.scopeTitle,
      ),
    );
    if (!mounted) return;
    if (!ok) {
      showError('规则未保存：匹配内容为空或格式无效', context: context);
      return;
    }
    await _reload();
  }

  Future<void> _toggle(ReplaceRule rule, bool enabled) async {
    await ReplaceRuleRepository.instance.setEnabled(rule.id, enabled);
    if (!mounted) return;
    setState(() {
      _rules = _rules
          .map((r) => r.id == rule.id ? r.copyWith(enabled: enabled) : r)
          .toList(growable: false);
    });
  }

  Future<void> _delete(ReplaceRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除「${rule.label}」'),
        content: const Text('删除后不再净化匹配内容，已缓存的章节正文不受影响。'),
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
    await ReplaceRuleRepository.instance.delete(rule.id);
    if (!mounted) return;
    showFeedback('已删除替换规则「${rule.label}」');
    await _reload();
  }

  Future<_RuleDraft?> _editRule({ReplaceRule? rule}) {
    return showDialog<_RuleDraft>(
      context: context,
      builder: (_) => _ReplaceRuleDialog(rule: rule),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: const Text('替换净化'),
        centerTitle: true,
        actions: [TextButton(onPressed: _create, child: const Text('新建'))],
      ),
      body: _loading
          ? const LoadingView.page()
          : _rules.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '还没有替换规则。\n'
                  '用规则去掉广告、网址、乱码等固定内容；'
                  '规则按顺序应用到正文和章节标题。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.8, color: muted),
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: _rules.length + 1,
              separatorBuilder: (_, i) => i == _rules.length - 1
                  ? const SizedBox.shrink()
                  : const Divider(height: .5),
              itemBuilder: (context, i) {
                if (i == _rules.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                    child: Text(
                      '规则保存后，重新打开章节生效。正文只净化显示内容，不修改缓存。',
                      style: TextStyle(fontSize: 12, height: 1.7, color: muted),
                    ),
                  );
                }
                final rule = _rules[i];
                return _RuleTile(
                  rule: rule,
                  onTap: () => _edit(rule),
                  onToggle: (value) => _toggle(rule, value),
                  onDelete: () => _delete(rule),
                );
              },
            ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final ReplaceRule rule;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final scope = [
      if (rule.scopeContent) '正文',
      if (rule.scopeTitle) '标题',
    ].join('、');
    final mode = rule.isRegex ? '正则' : '文本';
    final replacement = rule.replacement.isEmpty ? '（删除匹配）' : rule.replacement;
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: rule.enabled ? null : muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${rule.pattern} → $replacement',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.5, color: muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$mode｜$scope',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
            Switch(value: rule.enabled, onChanged: onToggle),
            IconButton(
              tooltip: '删除规则',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleDraft {
  const _RuleDraft({
    required this.name,
    required this.pattern,
    required this.replacement,
    required this.isRegex,
    required this.scopeContent,
    required this.scopeTitle,
  });

  final String name;
  final String pattern;
  final String replacement;
  final bool isRegex;
  final bool scopeContent;
  final bool scopeTitle;
}

class _ReplaceRuleDialog extends StatefulWidget {
  const _ReplaceRuleDialog({this.rule});

  final ReplaceRule? rule;

  @override
  State<_ReplaceRuleDialog> createState() => _ReplaceRuleDialogState();
}

class _ReplaceRuleDialogState extends State<_ReplaceRuleDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.rule?.name ?? '',
  );
  late final TextEditingController _pattern = TextEditingController(
    text: widget.rule?.pattern ?? '',
  );
  late final TextEditingController _replacement = TextEditingController(
    text: widget.rule?.replacement ?? '',
  );
  late bool _isRegex = widget.rule?.isRegex ?? false;
  late bool _scopeContent = widget.rule?.scopeContent ?? true;
  late bool _scopeTitle = widget.rule?.scopeTitle ?? false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _pattern.dispose();
    _replacement.dispose();
    super.dispose();
  }

  void _save() {
    final pattern = _pattern.text;
    if (pattern.isEmpty) {
      setState(() => _error = '匹配内容不能为空');
      return;
    }
    if (!_scopeContent && !_scopeTitle) {
      setState(() => _error = '至少选择一个作用范围');
      return;
    }
    if (_isRegex &&
        !ReplaceRuleRepository.isValidPattern(pattern, isRegex: true)) {
      setState(() => _error = '正则表达式无效');
      return;
    }
    Navigator.pop(
      context,
      _RuleDraft(
        name: _name.text.trim(),
        pattern: pattern,
        replacement: _replacement.text,
        isRegex: _isRegex,
        scopeContent: _scopeContent,
        scopeTitle: _scopeTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AlertDialog(
      title: Text(widget.rule == null ? '新建替换规则' : '编辑替换规则'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              maxLength: ReplaceRuleRepository.maxNameLength,
              decoration: const InputDecoration(
                labelText: '名称（可选）',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pattern,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: '匹配内容',
                hintText: '例如：www.example.com',
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _replacement,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: '替换为（留空即删除）'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('使用正则表达式'),
              subtitle: const Text('替换内容可用 \$1、\$2 引用捕获组'),
              value: _isRegex,
              onChanged: (value) => setState(() => _isRegex = value),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('作用于正文'),
              value: _scopeContent,
              onChanged: (value) =>
                  setState(() => _scopeContent = value ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('作用于章节标题'),
              value: _scopeTitle,
              onChanged: (value) =>
                  setState(() => _scopeTitle = value ?? false),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else
              Text(
                '规则按列表顺序依次应用；标题规则在目录刷新时生成。',
                style: TextStyle(fontSize: 12, height: 1.6, color: muted),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
