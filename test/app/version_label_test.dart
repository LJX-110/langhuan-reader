import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/app/version_label.dart';

void main() {
  group('resolveAppVersion', () {
    test('prefers the package version over a cached one', () {
      expect(
        resolveAppVersion(packageVersion: '2.0.0', cachedVersion: '1.0.0'),
        '2.0.0',
      );
    });

    test('falls back to the cached version when package info fails', () {
      expect(resolveAppVersion(cachedVersion: '1.9.0'), '1.9.0');
    });

    test('ignores blank values and reports unknown instead of 1.0.0', () {
      expect(resolveAppVersion(packageVersion: '  ', cachedVersion: ''), '未知');
      expect(resolveAppVersion(), '未知');
    });
  });

  group('versionDisplayLabel', () {
    test('prefixes a real version', () {
      expect(versionDisplayLabel('2.0.0'), 'v2.0.0');
      expect(versionDisplayLabel(' 2.0.0 '), 'v2.0.0');
    });

    test('shows an explicit unknown label for empty or missing versions', () {
      expect(versionDisplayLabel(''), '版本未知');
      expect(versionDisplayLabel('  '), '版本未知');
      expect(versionDisplayLabel(unknownVersion), '版本未知');
    });
  });

  group('isLegacyFallbackVersion', () {
    test('flags the synthetic 1.0.0 written by older builds', () {
      expect(isLegacyFallbackVersion('1.0.0'), isTrue);
      expect(isLegacyFallbackVersion(' 1.0.0 '), isTrue);
    });

    test('leaves real versions and missing caches alone', () {
      expect(isLegacyFallbackVersion('2.0.0'), isFalse);
      expect(isLegacyFallbackVersion(''), isFalse);
      expect(isLegacyFallbackVersion(null), isFalse);
    });
  });
}
