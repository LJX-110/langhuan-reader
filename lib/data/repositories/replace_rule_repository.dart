import 'package:langhuan/core/database/reader_database.dart';
import 'package:langhuan/data/entities/replace_rule.dart';
import 'package:sqflite/sqflite.dart';

/// 全局替换净化规则的唯一读写入口。
///
/// 规则按 `order_index` 升序应用；启停后，下一次加载章节 / 刷新目录即生效，
/// 不改写已缓存的章节正文。
class ReplaceRuleRepository {
  ReplaceRuleRepository({ReaderDatabase? db})
    : _db = db ?? ReaderDatabase.instance;

  final ReaderDatabase _db;

  static final ReplaceRuleRepository instance = ReplaceRuleRepository();

  static const int maxPatternLength = 1000;
  static const int maxReplacementLength = 2000;
  static const int maxNameLength = 60;

  Future<Database> get _database => _db.database;

  Future<List<ReplaceRule>> all() async {
    final db = await _database;
    final rows = await db.query(
      'replace_rules',
      orderBy: 'order_index ASC, id ASC',
    );
    return rows.map(ReplaceRule.fromRow).toList(growable: false);
  }

  /// 启用中的规则，按应用顺序返回；正文与标题共用这一份顺序。
  Future<List<ReplaceRule>> active() async {
    final db = await _database;
    final rows = await db.query(
      'replace_rules',
      where: 'enabled = 1',
      orderBy: 'order_index ASC, id ASC',
    );
    return rows.map(ReplaceRule.fromRow).toList(growable: false);
  }

  /// 新建规则；匹配内容为空、正则无效或范围为空时返回 null。
  Future<ReplaceRule?> create({
    required String pattern,
    String name = '',
    String replacement = '',
    bool isRegex = false,
    bool scopeContent = true,
    bool scopeTitle = false,
    bool enabled = true,
  }) async {
    if (!_isValid(
      pattern: pattern,
      name: name,
      replacement: replacement,
      isRegex: isRegex,
      scopeContent: scopeContent,
      scopeTitle: scopeTitle,
    )) {
      return null;
    }
    final db = await _database;
    final maxRows = await db.rawQuery(
      'SELECT MAX(order_index) AS max_order FROM replace_rules',
    );
    final nextOrder = (maxRows.first['max_order'] as int? ?? -1) + 1;
    final rule = ReplaceRule(
      id: 'rule-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      pattern: pattern,
      replacement: replacement,
      isRegex: isRegex,
      scopeContent: scopeContent,
      scopeTitle: scopeTitle,
      enabled: enabled,
      orderIndex: nextOrder,
    );
    await db.insert('replace_rules', rule.toRow());
    return rule;
  }

  /// 保存编辑；校验失败返回 false。
  Future<bool> update(ReplaceRule rule) async {
    if (rule.id.isEmpty ||
        !_isValid(
          pattern: rule.pattern,
          name: rule.name,
          replacement: rule.replacement,
          isRegex: rule.isRegex,
          scopeContent: rule.scopeContent,
          scopeTitle: rule.scopeTitle,
        )) {
      return false;
    }
    final db = await _database;
    final changed = await db.update(
      'replace_rules',
      rule.copyWith(name: rule.name.trim()).toRow(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
    return changed > 0;
  }

  Future<void> setEnabled(String id, bool enabled) async {
    if (id.isEmpty) return;
    final db = await _database;
    await db.update(
      'replace_rules',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    if (id.isEmpty) return;
    final db = await _database;
    await db.delete('replace_rules', where: 'id = ?', whereArgs: [id]);
  }

  /// 保存前的校验：空匹配内容不可用；正则模式必须能编译。
  static bool isValidPattern(String pattern, {required bool isRegex}) {
    if (pattern.isEmpty || pattern.length > maxPatternLength) return false;
    if (!isRegex) return true;
    try {
      RegExp(pattern);
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _isValid({
    required String pattern,
    required String name,
    required String replacement,
    required bool isRegex,
    required bool scopeContent,
    required bool scopeTitle,
  }) {
    if (!isValidPattern(pattern, isRegex: isRegex)) return false;
    if (replacement.length > maxReplacementLength) return false;
    if (name.trim().length > maxNameLength) return false;
    return scopeContent || scopeTitle;
  }
}
