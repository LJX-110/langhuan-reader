import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/discover/explore_model.dart';
import 'package:langhuan/features/discover/explore_page.dart';
import 'package:langhuan/features/sources/model/book_source.dart';
import 'package:langhuan/features/sources/source_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 发现页布局：统一 20 水平节奏；行排版对齐文库的节奏
/// （封面 64×98、标题两行、简介一行、行高随内容）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SpUtil.getInstance();
  });

  testWidgets('发现页：20 边距、64×98 封面、两行标题、单行简介', (tester) async {
    const longName = '一本很长很长很长很长很长很长的测试书名';
    const desc = '这是一段用于验证单行截断的测试简介文字';
    final model = ExploreModel()
      ..kinds = const [
        ExploreKind(title: '玄幻', url: 'u1'),
        ExploreKind(title: '都市', url: 'u2'),
      ]
      ..activeKind = const ExploreKind(title: '玄幻', url: 'u1')
      ..books = [
        SearchItem(
          name: longName,
          author: '某作者',
          description: desc,
          latestChapter: '第 12 章 新的开始',
          sourceName: '测试源',
        ),
      ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exploreModelProvider.overrideWith((ref) => model),
          sourceModelProvider.overrideWith((ref) => SourceModel()),
        ],
        child: MaterialApp(
          theme: buildLanghuanTheme(dark: false),
          home: const ExplorePage(),
        ),
      ),
    );
    await tester.pump();

    // 分类标签从 x=20 起排（与页头 / 列表同一水平节奏）。
    expect(tester.getTopLeft(find.text('玄幻')).dx, 20);

    // 封面 64 宽（高 = 64/0.65），行从 x=20 开始。
    final cover = find.byType(PicWidget);
    expect(cover, findsOneWidget);
    final coverSize = tester.getSize(cover);
    expect(coverSize.width, 64);
    expect(coverSize.height, closeTo(64 / .65, 0.01));
    expect(tester.getTopLeft(cover).dx, 20);

    // 标题两行 15/w600，简介一行截断。
    final title = tester.widget<Text>(find.text(longName));
    expect(title.maxLines, 2);
    expect(title.style?.fontSize, 15);
    expect(title.style?.fontWeight, FontWeight.w600);

    final descText = tester.widget<Text>(find.text(desc));
    expect(descText.maxLines, 1);
  });
}
