import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/search/search_model.dart';

/// First-screen soft timeout: after the window the UI offers 停止等待, and
/// stopping keeps whatever hits already arrived.
void main() {
  group('SearchModel soft timeout', () {
    test('window defaults to 20 seconds', () {
      expect(SearchModel.firstScreenWindow, const Duration(seconds: 20));
    });

    test('starts without the soft flag set', () {
      final model = SearchModel();
      addTearDown(model.dispose);

      expect(model.softTimeoutElapsed, isFalse);
      expect(model.loading, isFalse);
    });

    test('defaults to six concurrent sources', () {
      final model = SearchModel();
      addTearDown(model.dispose);

      expect(SearchModel.defaultSourceConcurrency, 6);
      expect(model.sourceConcurrency, 6);
      expect(model.fromCache, isFalse);
    });

    test('stopWaiting ends the sweep and clears the flag', () {
      final model = SearchModel();
      addTearDown(model.dispose);
      model
        ..loading = true
        ..softTimeoutElapsed = true
        ..searchedSources = 3
        ..totalSources = 10;

      model.stopWaiting();

      expect(model.loading, isFalse);
      expect(model.softTimeoutElapsed, isFalse);
      // Already-received progress is untouched.
      expect(model.searchedSources, 3);
      expect(model.totalSources, 10);
    });

    test('stopWaiting is a no-op when no sweep is running', () {
      final model = SearchModel();
      addTearDown(model.dispose);

      model.stopWaiting();

      expect(model.loading, isFalse);
      expect(model.softTimeoutElapsed, isFalse);
    });
  });
}
