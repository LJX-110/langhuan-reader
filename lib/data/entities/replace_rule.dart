/// 规则作用范围：正文还是章节标题。
enum ReplaceRuleScope { content, title }

/// 一条全局替换净化规则。
///
/// 规则按 [orderIndex] 升序依次应用；[isRegex] 为 true 时 [pattern] 按正则
/// 解析，[replacement] 可用 `$1` 引用捕获组，纯文本模式则按字面替换。
class ReplaceRule {
  const ReplaceRule({
    required this.id,
    required this.name,
    required this.pattern,
    this.replacement = '',
    this.isRegex = false,
    this.scopeContent = true,
    this.scopeTitle = false,
    this.enabled = true,
    this.orderIndex = 0,
  });

  final String id;
  final String name;
  final String pattern;
  final String replacement;
  final bool isRegex;
  final bool scopeContent;
  final bool scopeTitle;
  final bool enabled;
  final int orderIndex;

  /// 列表展示用名称；未填名称时回退到匹配内容。
  String get label => name.isEmpty ? pattern : name;

  bool appliesTo(ReplaceRuleScope scope) => switch (scope) {
    ReplaceRuleScope.content => scopeContent,
    ReplaceRuleScope.title => scopeTitle,
  };

  ReplaceRule copyWith({
    String? name,
    String? pattern,
    String? replacement,
    bool? isRegex,
    bool? scopeContent,
    bool? scopeTitle,
    bool? enabled,
    int? orderIndex,
  }) => ReplaceRule(
    id: id,
    name: name ?? this.name,
    pattern: pattern ?? this.pattern,
    replacement: replacement ?? this.replacement,
    isRegex: isRegex ?? this.isRegex,
    scopeContent: scopeContent ?? this.scopeContent,
    scopeTitle: scopeTitle ?? this.scopeTitle,
    enabled: enabled ?? this.enabled,
    orderIndex: orderIndex ?? this.orderIndex,
  );

  static ReplaceRule fromRow(Map<String, Object?> row) => ReplaceRule(
    id: row['id'] as String? ?? '',
    name: row['name'] as String? ?? '',
    pattern: row['pattern'] as String? ?? '',
    replacement: row['replacement'] as String? ?? '',
    isRegex: (row['is_regex'] as int? ?? 0) != 0,
    scopeContent: (row['scope_content'] as int? ?? 1) != 0,
    scopeTitle: (row['scope_title'] as int? ?? 0) != 0,
    enabled: (row['enabled'] as int? ?? 1) != 0,
    orderIndex: row['order_index'] as int? ?? 0,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'pattern': pattern,
    'replacement': replacement,
    'is_regex': isRegex ? 1 : 0,
    'scope_content': scopeContent ? 1 : 0,
    'scope_title': scopeTitle ? 1 : 0,
    'enabled': enabled ? 1 : 0,
    'order_index': orderIndex,
  };
}
