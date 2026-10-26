import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/sources/model/search_book.dart';
import 'package:langhuan/features/sources/model/source_search_report.dart';
import 'package:langhuan/features/sources/source_test_panel.dart';

/// The single-source sheet must show the search evidence plus the three
/// on-demand stages, without touching the network or the database.
void main() {
  testWidgets('renders the search report and the four stages', (tester) async {
    final report = SourceSearchReport(
      sourceUrl: 'https://ex.com',
      sourceName: '测试源',
      keyword: '斗破',
      page: 1,
      issue: SourceSearchIssue.none,
      elapsedMs: 120,
      hits: [
        SearchBook(
          name: '斗破苍穹',
          author: '天蚕土豆',
          bookUrl: 'https://ex.com/book/1',
          sourceUrl: 'https://ex.com',
          sourceName: '测试源',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSourceTestSheet(
                context: context,
                sourceName: '测试源',
                sourceUrl: 'https://ex.com',
                initialKeyword: '斗破',
                onSearch: (_) async => report,
                hydrate: () async => null,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('测试「测试源」'), findsOneWidget);
    // Search evidence card.
    expect(find.text('搜索成功'), findsOneWidget);
    expect(find.textContaining('120ms'), findsOneWidget);
    // The hit is selectable for the later stages.
    expect(find.text('斗破苍穹'), findsWidgets);
    // Stage cards, 正文 explicitly marked as on-demand.
    expect(find.text('详情'), findsOneWidget);
    expect(find.text('目录'), findsOneWidget);
    expect(find.text('正文'), findsOneWidget);
    expect(find.text('按需抓取第一章'), findsOneWidget);
  });

  testWidgets('empty keyword reports without running a search', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSourceTestSheet(
                context: context,
                sourceName: '测试源',
                sourceUrl: 'https://ex.com',
                initialKeyword: '',
                onSearch: (_) async {
                  calls++;
                  return SourceSearchReport(
                    sourceUrl: 'https://ex.com',
                    sourceName: '测试源',
                    keyword: '',
                    page: 1,
                    issue: SourceSearchIssue.incompatibleRule,
                  );
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.text('请输入搜索关键词'), findsOneWidget);
  });
}
