import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/detail/source_switch_sheet.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';

/// 换源状态行：命中 / 无匹配 / 失败 必须分清，避免把"站点正常但没有这本书"
/// 当成书源损坏。
void main() {
  SourceSearchReport report(SourceSearchIssue issue) => SourceSearchReport(
    sourceUrl: 'https://ex.com',
    sourceName: '测试源',
    keyword: '斗破苍穹',
    page: 1,
    issue: issue,
  );

  SearchBook hit(String name, String author) =>
      SearchBook(name: name, author: author, bookUrl: 'https://ex.com/b');

  test('精搜：书名去空白后完全一致才算命中', () {
    expect(isPreciseSourceHit('斗破苍穹', '天蚕土豆', hit('斗破苍穹', '天蚕土豆')), isTrue);
    expect(isPreciseSourceHit('斗 破 苍 穹', '天蚕土豆', hit('斗破苍穹', '天蚕土豆')), isTrue);
    expect(isPreciseSourceHit('斗破苍穹', '天蚕土豆', hit('斗破苍穹之炎帝', '天蚕土豆')), isFalse);
  });

  test('精搜：双方都有作者时必须一致，缺作者时只看书名', () {
    expect(isPreciseSourceHit('斗破苍穹', '天蚕土豆', hit('斗破苍穹', '作者：天蚕土豆')), isTrue);
    expect(isPreciseSourceHit('斗破苍穹', '天蚕土豆', hit('斗破苍穹', '其它作者')), isFalse);
    expect(isPreciseSourceHit('斗破苍穹', '', hit('斗破苍穹', '天蚕土豆')), isTrue);
    expect(isPreciseSourceHit('斗破苍穹', '天蚕土豆', hit('斗破苍穹', '')), isTrue);
  });

  test('matched candidates win over everything', () {
    expect(
      switchOutcomeOf(report(SourceSearchIssue.none), 2),
      SwitchSourceOutcome.hit,
    );
    expect(
      switchOutcomeOf(report(SourceSearchIssue.noResult), 1),
      SwitchSourceOutcome.hit,
    );
  });

  test('reachable without matches counts as 无匹配', () {
    expect(
      switchOutcomeOf(report(SourceSearchIssue.none), 0),
      SwitchSourceOutcome.noMatch,
    );
    expect(
      switchOutcomeOf(report(SourceSearchIssue.noResult), 0),
      SwitchSourceOutcome.noMatch,
    );
  });

  test('unreachable or broken rules count as 失败', () {
    for (final issue in [
      SourceSearchIssue.network,
      SourceSearchIssue.timeout,
      SourceSearchIssue.incompatibleRule,
      SourceSearchIssue.parse,
      SourceSearchIssue.unknown,
    ]) {
      expect(
        switchOutcomeOf(report(issue), 0),
        SwitchSourceOutcome.failed,
        reason: '$issue should be a failure',
      );
    }
  });
}
