import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Neighbor prefetch range: defaults 1 back / 2 forward, clamped to 0–5 and
/// persisted for the settings panel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SpUtil.getInstance();
  });

  test('defaults to 1 back / 2 forward', () {
    expect(ReadSetting.prefetchBack, 1);
    expect(ReadSetting.prefetchForward, 2);
  });

  test('persists and clamps the range', () {
    ReadSetting.setPrefetchRange(back: 3, forward: 4);
    expect(ReadSetting.prefetchBack, 3);
    expect(ReadSetting.prefetchForward, 4);

    ReadSetting.setPrefetchRange(back: 99, forward: -3);
    expect(ReadSetting.prefetchBack, 5);
    expect(ReadSetting.prefetchForward, 0);
  });
}
