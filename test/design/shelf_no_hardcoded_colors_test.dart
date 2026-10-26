import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Plan §8.4: the 3D shelf must derive every surface from the active theme.
/// Shadows may use `Colors.black.withValues`, but a raw `Color(0x...)`
/// swatch in this file means a dead colour slipped back in.
void main() {
  test('bookshelf_3d.dart contains no fixed colour literals', () {
    final source = File(
      'lib/design/components/bookshelf_3d.dart',
    ).readAsStringSync();

    final literals = RegExp(r'Color\(0x').allMatches(source).length;
    expect(
      literals,
      0,
      reason: 'derive surfaces from AppColors instead of fixed swatches',
    );
  });
}
