import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/search/search_model.dart';

void main() {
  group('SearchModel failure reporting', () {
    late SearchModel model;

    setUp(() => model = SearchModel());
    tearDown(() => model.dispose());

    test('no result without failures suggests another keyword', () {
      model
        ..totalSources = 4
        ..searchedSources = 4
        ..failedSources = 0;

      expect(model.allSourcesFailed, isFalse);
      expect(model.emptyHint, '换个书名、作者或关键词再试。');
    });

    test('partial outage says results may be incomplete', () {
      model
        ..totalSources = 4
        ..searchedSources = 4
        ..failedSources = 2;

      expect(model.allSourcesFailed, isFalse);
      expect(model.emptyHint, '2 个书源请求失败，结果可能不完整。');
    });

    test('total outage names the failed sources', () {
      model
        ..totalSources = 5
        ..searchedSources = 5
        ..failedSources = 5
        ..failedSourceNames.addAll(['甲源', '乙源', '丙源', '丁源', '戊源']);

      expect(model.allSourcesFailed, isTrue);
      expect(model.emptyHint, contains('全部 5 个书源请求失败'));
      expect(model.emptyHint, contains('甲源、乙源、丙源 等'));
    });
  });
}
