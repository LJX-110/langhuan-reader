import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/replace_rule.dart';
import 'package:langhuan/data/repositories/replace_rule_repository.dart';
import 'package:langhuan/features/reader/model/toc_service.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/util/text_clean.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

ReplaceRule rule({
  required String pattern,
  String replacement = '',
  bool isRegex = false,
  bool scopeContent = true,
  bool scopeTitle = false,
  bool enabled = true,
}) => ReplaceRule(
  id: pattern,
  name: '',
  pattern: pattern,
  replacement: replacement,
  isRegex: isRegex,
  scopeContent: scopeContent,
  scopeTitle: scopeTitle,
  enabled: enabled,
);

void main() {
  setUpAll(sqfliteFfiInit);

  group('applyReplaceRules', () {
    test('按顺序应用规则，后一条能看到前一条的结果', () {
      final text = applyReplaceRules('广告正文广告', [
        rule(pattern: '广告'),
        rule(pattern: '正文', replacement: '内容'),
      ], scope: ReplaceRuleScope.content);
      expect(text, '内容');
    });

    test('正则规则支持捕获组替换', () {
      final text = applyReplaceRules(r'[第12章] 标题', [
        rule(pattern: r'\[第(\d+)章\]', replacement: '第\$1章', isRegex: true),
      ], scope: ReplaceRuleScope.content);
      expect(text, '第12章 标题');
    });

    test('纯文本规则按字面匹配，不当正则解释', () {
      final text = applyReplaceRules('a.b axb', [
        rule(pattern: 'a.b', replacement: '-'),
      ], scope: ReplaceRuleScope.content);
      expect(text, '- axb');
    });

    test('停用规则、非目标范围与无效正则都不生效', () {
      final text = applyReplaceRules('保留', [
        rule(pattern: '保留', enabled: false),
        rule(pattern: '保留', scopeContent: false, scopeTitle: true),
        rule(pattern: '(', isRegex: true),
      ], scope: ReplaceRuleScope.content);
      expect(text, '保留');
    });

    test('空匹配内容直接跳过', () {
      expect(
        applyReplaceRules('abc', [
          rule(pattern: ''),
        ], scope: ReplaceRuleScope.title),
        'abc',
      );
    });
  });

  group('ReplaceRuleRepository', () {
    late Database db;
    late ReplaceRuleRepository repo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await ReaderDatabase.createSchema(db);
      repo = ReplaceRuleRepository(db: ReaderDatabase.withDatabase(db));
    });

    test('新建规则按创建顺序排列，停用后不出现在 active', () async {
      final r1 = (await repo.create(pattern: '广告'))!;
      final r2 = (await repo.create(pattern: '网址', replacement: ' '))!;
      expect(r1.orderIndex, 0);
      expect(r2.orderIndex, 1);
      expect((await repo.all()).map((r) => r.pattern).toList(), ['广告', '网址']);
      expect((await repo.active()).length, 2);

      await repo.setEnabled(r1.id, false);
      expect((await repo.active()).map((r) => r.id).toList(), [r2.id]);
    });

    test('无效规则不写入：空匹配、无效正则、无作用范围', () async {
      expect(await repo.create(pattern: ''), isNull);
      expect(await repo.create(pattern: '(', isRegex: true), isNull);
      expect(
        await repo.create(pattern: 'x', scopeContent: false, scopeTitle: false),
        isNull,
      );
      expect((await repo.all()).isEmpty, isTrue);
    });

    test('编辑与删除', () async {
      final r = (await repo.create(pattern: '广告', name: '去广告'))!;
      expect(r.label, '去广告');

      final updated = await repo.update(
        r.copyWith(pattern: '推广', replacement: '', scopeTitle: true),
      );
      expect(updated, isTrue);
      final stored = (await repo.all()).single;
      expect(stored.pattern, '推广');
      expect(stored.scopeTitle, isTrue);

      await repo.delete(r.id);
      expect((await repo.all()).isEmpty, isTrue);
    });
  });

  group('TocService 标题净化', () {
    test('标题规则作用于章节名与卷名，正文规则不影响标题', () {
      final book = Book(id: 'b1');
      final entries = TocService.mapChapters(
        book,
        [
          SourceChapter(name: '- 【分组】第一卷 -', url: '', isVolume: true),
          SourceChapter(name: '【广告】第一章 起点', url: 'https://ex.com/1'),
          SourceChapter(name: '第二章 起点', url: 'https://ex.com/2'),
        ],
        rules: [
          rule(
            pattern: '【[^】]*】',
            isRegex: true,
            scopeContent: false,
            scopeTitle: true,
          ),
          rule(pattern: '起点', scopeTitle: false),
        ],
      );

      expect(entries, hasLength(2));
      expect(entries.first.volumeTitle, '第一卷');
      expect(entries.first.title, '第一章 起点');
      expect(entries.last.title, '第二章 起点');
    });
  });
}
