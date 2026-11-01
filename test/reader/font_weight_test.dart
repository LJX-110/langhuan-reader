import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/design/theme/color_model.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/menu/reader_settings_panel.dart';
import 'package:langhuan/features/reader/read_model.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 字重三段（对齐阅读 `textBold`）：0 中 / 1 粗 / 2 细，
/// 只改绘制、不重新分页；设置面板提供三段式选项行。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SpUtil.getInstance();
  });

  test('defaults to 中 and maps body / title / running-head weights', () {
    expect(ReadSetting.getFontWeightCd(), 0);
    expect(ReadSetting.bodyFontWeight, FontWeight.w400);
    expect(ReadSetting.titleFontWeight, FontWeight.w600);
    expect(ReadSetting.runningHeadFontWeight, FontWeight.w500);

    ReadSetting.setFontWeightCd(1);
    expect(ReadSetting.getFontWeightCd(), 1);
    expect(ReadSetting.bodyFontWeight, FontWeight.w600);
    expect(ReadSetting.titleFontWeight, FontWeight.w800);
    expect(ReadSetting.runningHeadFontWeight, FontWeight.w700);

    ReadSetting.setFontWeightCd(2);
    expect(ReadSetting.getFontWeightCd(), 2);
    expect(ReadSetting.bodyFontWeight, FontWeight.w300);
    expect(ReadSetting.titleFontWeight, FontWeight.w400);
    expect(ReadSetting.runningHeadFontWeight, FontWeight.w400);
  });

  test('clamps out-of-range values into 0-2', () {
    ReadSetting.setFontWeightCd(9);
    expect(ReadSetting.getFontWeightCd(), 2);
    ReadSetting.setFontWeightCd(-1);
    expect(ReadSetting.getFontWeightCd(), 0);
  });

  testWidgets('字重行切换 粗 / 细 并持久化', (tester) async {
    final model = ReadModel();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLanghuanTheme(dark: false),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReaderSettingsPanel(
              readModel: model,
              colorModel: ColorModel(),
              chrome: const ReaderChrome(PaperTheme.white),
              onChanged: () {},
              onOpenLayout: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('字重'), findsOneWidget);
    await tester.tap(find.text('粗'));
    expect(ReadSetting.getFontWeightCd(), 1);
    await tester.tap(find.text('细'));
    expect(ReadSetting.getFontWeightCd(), 2);
  });
}
