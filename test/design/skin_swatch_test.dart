import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/features/settings/skin_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SpUtil.getInstance();
  });

  testWidgets('theme list paints both swatch colours at full height', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: Skin())),
    );
    await tester.pumpAndSettle();

    // Before the fix ColoredBox collapsed to zero height inside the Row.
    for (var i = 0; i < 3; i++) {
      for (final part in ['accent', 'secondary']) {
        final box = tester.renderObject<RenderBox>(
          find.byKey(ValueKey('theme-swatch-$i-$part')),
        );
        expect(box.size.height, greaterThan(20), reason: 'swatch $i $part');
        expect(box.size.width, greaterThan(0), reason: 'swatch $i $part');
      }
    }
  });
}
