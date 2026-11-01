import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:langhuan/app/providers.dart';
import 'package:langhuan/data/repositories/source_repository.dart';
import 'package:langhuan/features/sources/model/book_source.dart';

/// 书源编辑器：Legado 字段口径的全字段表单（基础 / 搜索 / 发现 / 详情 /
/// 目录 / 正文）。
///
/// 保存时 `raw_json` 置空重建（规则已改，导出不得带旧规则）；
/// 编辑模式下书源地址只读——改地址等于换身份，请删除后新建。
class SourceEditPage extends ConsumerStatefulWidget {
  const SourceEditPage({
    super.key,
    required this.source,
    this.isNew = false,
    this.onSave,
  });

  final BookSource source;
  final bool isNew;

  /// 测试注入用；默认写入仓库并刷新列表后返回。
  final Future<void> Function(BookSource source)? onSave;

  @override
  ConsumerState<SourceEditPage> createState() => _SourceEditPageState();
}

/// 惰性文本控制器桶：按 key 建，保存时按 key 读。
class _Ctrls {
  final Map<String, TextEditingController> _map = {};

  TextEditingController of(String key, String initial) =>
      _map.putIfAbsent(key, () => TextEditingController(text: initial));

  String text(String key) => _map[key]?.text.trim() ?? '';

  void dispose() {
    for (final c in _map.values) {
      c.dispose();
    }
    _map.clear();
  }
}

class _SourceEditPageState extends ConsumerState<SourceEditPage> {
  final _Ctrls _c = _Ctrls();
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.source.enabled;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _c.text('url');
    if (url.isEmpty ||
        !(url.startsWith('http://') || url.startsWith('https://'))) {
      BotToast.showText(text: '书源地址需以 http:// 或 https:// 开头');
      return;
    }
    final s = widget.source;
    final updated = BookSource(
      bookSourceUrl: url,
      bookSourceName: _c.text('name'),
      bookSourceGroup: _c.text('group'),
      bookSourceType: s.bookSourceType,
      enabled: _enabled,
      enabledExplore: s.enabledExplore,
      header: _c.text('header'),
      searchUrl: _c.text('searchUrl'),
      exploreUrl: _c.text('exploreUrl'),
      jsLib: _c.text('jsLib'),
      customOrder: s.customOrder,
      weight: s.weight,
      lastUpdateTime: s.lastUpdateTime,
      respondTime: s.respondTime,
      lastCheckTime: s.lastCheckTime,
      ruleSearch: SearchRule(
        bookList: _c.text('s.bookList'),
        name: _c.text('s.name'),
        author: _c.text('s.author'),
        kind: _c.text('s.kind'),
        wordCount: _c.text('s.wordCount'),
        lastChapter: _c.text('s.lastChapter'),
        intro: _c.text('s.intro'),
        coverUrl: _c.text('s.coverUrl'),
        bookUrl: _c.text('s.bookUrl'),
        checkKeyWord: _c.text('s.checkKeyWord'),
      ),
      ruleExplore: SearchRule(
        bookList: _c.text('e.bookList'),
        name: _c.text('e.name'),
        author: _c.text('e.author'),
        kind: _c.text('e.kind'),
        wordCount: _c.text('e.wordCount'),
        lastChapter: _c.text('e.lastChapter'),
        intro: _c.text('e.intro'),
        coverUrl: _c.text('e.coverUrl'),
        bookUrl: _c.text('e.bookUrl'),
        checkKeyWord: _c.text('e.checkKeyWord'),
      ),
      ruleBookInfo: BookInfoRule(
        init: _c.text('i.init'),
        name: _c.text('i.name'),
        author: _c.text('i.author'),
        kind: _c.text('i.kind'),
        wordCount: _c.text('i.wordCount'),
        lastChapter: _c.text('i.lastChapter'),
        intro: _c.text('i.intro'),
        coverUrl: _c.text('i.coverUrl'),
        tocUrl: _c.text('i.tocUrl'),
        canReName: _c.text('i.canReName'),
      ),
      ruleToc: TocRule(
        chapterList: _c.text('t.chapterList'),
        chapterName: _c.text('t.chapterName'),
        chapterUrl: _c.text('t.chapterUrl'),
        isVolume: _c.text('t.isVolume'),
        updateTime: _c.text('t.updateTime'),
        nextTocUrl: _c.text('t.nextTocUrl'),
      ),
      ruleContent: ContentRule(
        content: _c.text('c.content'),
        nextContentUrl: _c.text('c.nextContentUrl'),
        sourceRegex: _c.text('c.sourceRegex'),
        replaceRegex: _c.text('c.replaceRegex'),
        imageStyle: _c.text('c.imageStyle'),
      ),
      // 规则已改：raw_json 重建，导出不会带旧规则。
      rawJson: '',
    );
    await (widget.onSave ?? _defaultSave)(updated);
  }

  Future<void> _defaultSave(BookSource source) async {
    await SourceRepository.instance.upsert(source);
    ref.read(sourceModelProvider).load();
    if (!mounted) return;
    BotToast.showText(text: widget.isNew ? '已新建书源' : '已保存书源');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '新建书源' : '编辑书源'),
        elevation: 0,
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          _section(theme, '基础'),
          _field('名称', 'name', s.bookSourceName),
          _field('分组', 'group', s.bookSourceGroup),
          widget.isNew
              ? _field('书源地址', 'url', s.bookSourceUrl, keyboard: TextInputType.url)
              : _field(
                  '书源地址（不可改）',
                  'url',
                  s.bookSourceUrl,
                  readOnly: true,
                ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('启用', style: TextStyle(fontSize: 13)),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          _field('请求头 header（JSON，可空）', 'header', s.header, lines: 3),
          _field('公共脚本 jsLib（可空）', 'jsLib', s.jsLib, lines: 5),

          _section(theme, '搜索'),
          _field('搜索地址 searchUrl', 'searchUrl', s.searchUrl, lines: 3),
          ..._searchRuleFields('s', s.ruleSearch),

          _section(theme, '发现'),
          _field('发现地址 exploreUrl（可多行「分类::地址」）', 'exploreUrl', s.exploreUrl, lines: 6),
          ..._searchRuleFields('e', s.ruleExplore),

          _section(theme, '详情（ruleBookInfo）'),
          _field('预处理 init', 'i.init', s.ruleBookInfo.init, lines: 2),
          _field('书名 name', 'i.name', s.ruleBookInfo.name),
          _field('作者 author', 'i.author', s.ruleBookInfo.author),
          _field('分类 kind', 'i.kind', s.ruleBookInfo.kind),
          _field('字数 wordCount', 'i.wordCount', s.ruleBookInfo.wordCount),
          _field('最新章节 lastChapter', 'i.lastChapter', s.ruleBookInfo.lastChapter),
          _field('简介 intro', 'i.intro', s.ruleBookInfo.intro, lines: 2),
          _field('封面 coverUrl', 'i.coverUrl', s.ruleBookInfo.coverUrl),
          _field('目录地址 tocUrl', 'i.tocUrl', s.ruleBookInfo.tocUrl),
          _field('允许重命名 canReName', 'i.canReName', s.ruleBookInfo.canReName),

          _section(theme, '目录（ruleToc）'),
          _field('章节列表 chapterList', 't.chapterList', s.ruleToc.chapterList, lines: 3),
          _field('章节名 chapterName', 't.chapterName', s.ruleToc.chapterName),
          _field('章节地址 chapterUrl', 't.chapterUrl', s.ruleToc.chapterUrl),
          _field('分卷标记 isVolume', 't.isVolume', s.ruleToc.isVolume),
          _field('更新时间 updateTime', 't.updateTime', s.ruleToc.updateTime),
          _field('下一页目录 nextTocUrl', 't.nextTocUrl', s.ruleToc.nextTocUrl),

          _section(theme, '正文（ruleContent）'),
          _field('正文规则 content', 'c.content', s.ruleContent.content, lines: 3),
          _field('下一页正文 nextContentUrl', 'c.nextContentUrl', s.ruleContent.nextContentUrl),
          _field('来源正则 sourceRegex', 'c.sourceRegex', s.ruleContent.sourceRegex),
          _field('替换正则 replaceRegex', 'c.replaceRegex', s.ruleContent.replaceRegex, lines: 3),
          _field('图片样式 imageStyle', 'c.imageStyle', s.ruleContent.imageStyle),

          const SizedBox(height: 12),
          Center(
            child: Text(
              '规则为 Legado 子集：CSS / JsonPath / @js: / {{}} 插值 / ## 替换',
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _searchRuleFields(String prefix, SearchRule rule) {
    return [
      _field('结果列表 bookList', '$prefix.bookList', rule.bookList, lines: 3),
      _field('书名 name', '$prefix.name', rule.name),
      _field('作者 author', '$prefix.author', rule.author),
      _field('分类 kind', '$prefix.kind', rule.kind),
      _field('字数 wordCount', '$prefix.wordCount', rule.wordCount),
      _field('最新章节 lastChapter', '$prefix.lastChapter', rule.lastChapter),
      _field('简介 intro', '$prefix.intro', rule.intro),
      _field('封面 coverUrl', '$prefix.coverUrl', rule.coverUrl),
      _field('详情地址 bookUrl', '$prefix.bookUrl', rule.bookUrl),
      _field('校验关键词 checkKeyWord', '$prefix.checkKeyWord', rule.checkKeyWord),
    ];
  }

  Widget _section(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _field(
    String label,
    String key,
    String initial, {
    int lines = 1,
    bool readOnly = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: ValueKey('edit-$key'),
        controller: _c.of(key, initial),
        minLines: 1,
        maxLines: lines,
        readOnly: readOnly,
        keyboardType: keyboard,
        style: TextStyle(
          fontSize: 13,
          color: readOnly
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12),
          isDense: true,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}
