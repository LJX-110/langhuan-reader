import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/database/reader_database.dart';

void main() {
  group('ReaderDatabase legacy sources heal decision', () {
    test('imports only when marker is absent and sources table was absent', () {
      expect(
        ReaderDatabase.shouldImportLegacySources(
          markerExists: false,
          hadSourcesTable: false,
          legacyFileExists: true,
        ),
        isTrue,
      );
    });

    test('does not import when a marker already exists', () {
      expect(
        ReaderDatabase.shouldImportLegacySources(
          markerExists: true,
          hadSourcesTable: false,
          legacyFileExists: true,
        ),
        isFalse,
      );
    });

    test('does not import when reader.db already had a sources table', () {
      expect(
        ReaderDatabase.shouldImportLegacySources(
          markerExists: false,
          hadSourcesTable: true,
          legacyFileExists: true,
        ),
        isFalse,
      );
    });

    test('does not import when there is no legacy sources.db', () {
      expect(
        ReaderDatabase.shouldImportLegacySources(
          markerExists: false,
          hadSourcesTable: false,
          legacyFileExists: false,
        ),
        isFalse,
      );
    });
  });
}
