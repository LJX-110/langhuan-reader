import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/platform/screen.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/features/reader/menu/reader_bottom_bar.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 专注模式：阅读页隐藏行头（第 2 页起的章节小标题）与时间 / 页码，
/// 底部留白收紧；每章第 1 页的章首头保留（顶部 inset 不变）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SpUtil.getInstance();
  });

  test('defaults to off and persists the toggle', () {
    expect(ReadSetting.getFocusMode(), isFalse);
    ReadSetting.setFocusMode(true);
    expect(ReadSetting.getFocusMode(), isTrue);
    ReadSetting.setFocusMode(false);
    expect(ReadSetting.getFocusMode(), isFalse);
  });

  test('focus mode reclaims the bottom chrome band, keeps the top inset', () {
    final topNormal = ReadSetting.contentTopInset();
    final bottomNormal = ReadSetting.contentBottomInset();

    ReadSetting.setFocusMode(true);

    // The chapter opening header still owns the top band.
    expect(ReadSetting.contentTopInset(), topNormal);
    // Footer band is gone; only the bottom safe area + gap remain.
    expect(
      ReadSetting.contentBottomInset(),
      bottomNormal - ReadSetting.contentBottomChrome,
    );
    expect(
      ReadSetting.contentBottomInset(),
      Screen.bottomSafeHeight + ReadSetting.contentChromeGap,
    );
  });

  testWidgets('focus tab reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderBottomBar(
            chrome: const ReaderChrome(PaperTheme.cream),
            night: false,
            focusActive: false,
            downloadActive: false,
            settingsActive: false,
            onChapters: () {},
            onToggleNight: () {},
            onFocus: () => taps++,
            onDownload: () {},
            onSettings: () {},
          ),
        ),
      ),
    );

    expect(find.text('专注'), findsOneWidget);
    await tester.tap(find.text('专注'));
    expect(taps, 1);
  });
}
