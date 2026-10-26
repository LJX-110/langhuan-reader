import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/features/discover/cover_enricher.dart';

SearchItem _item(String id, {String cover = ''}) => SearchItem(
  id: id,
  name: '书$id',
  bookUrl: 'https://ex.com/book/$id',
  sourceUrl: 'https://ex.com',
  coverUrl: cover,
);

void main() {
  setUp(CoverEnricher.clearCache);

  test('fills missing covers and skips rows that already have one', () async {
    final calls = <String>[];
    final enricher = CoverEnricher(
      fetch: (item) async {
        calls.add(item.bookUrl);
        return 'https://img/${item.id}.jpg';
      },
    );
    final items = [_item('1', cover: 'https://img/0.jpg'), _item('2'), _item('3')];
    var updates = 0;

    await enricher.enrich(items, onUpdated: () => updates++);

    expect(calls, ['https://ex.com/book/2', 'https://ex.com/book/3']);
    expect(items[0].coverUrl, 'https://img/0.jpg');
    expect(items[1].coverUrl, 'https://img/2.jpg');
    expect(items[2].coverUrl, 'https://img/3.jpg');
    expect(updates, 2);
  });

  test('a second list reuses the cached cover without a request', () async {
    var calls = 0;
    final enricher = CoverEnricher(
      fetch: (item) async {
        calls++;
        return 'https://img/x.jpg';
      },
    );

    await enricher.enrich([_item('1')], onUpdated: () {});
    final again = [_item('1')];
    await enricher.enrich(again, onUpdated: () {});

    expect(calls, 1);
    expect(again.first.coverUrl, 'https://img/x.jpg');
  });

  test('a failed lookup is remembered and not retried', () async {
    var calls = 0;
    final enricher = CoverEnricher(
      fetch: (item) async {
        calls++;
        throw StateError('boom');
      },
    );

    await enricher.enrich([_item('1')], onUpdated: () {});
    await enricher.enrich([_item('1')], onUpdated: () {});

    expect(calls, 1);
  });

  test('limit caps how many rows are requested', () async {
    var calls = 0;
    final enricher = CoverEnricher(
      fetch: (item) async {
        calls++;
        return 'https://img/${item.id}.jpg';
      },
    );

    await enricher.enrich([
      for (var i = 0; i < 10; i++) _item('$i'),
    ], limit: 3, onUpdated: () {});

    expect(calls, 3);
  });

  test('never runs more than three lookups at once', () async {
    var inFlight = 0;
    var peak = 0;
    final enricher = CoverEnricher(
      fetch: (item) async {
        inFlight++;
        peak = math.max(peak, inFlight);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return 'https://img/${item.id}.jpg';
      },
    );

    await enricher.enrich([
      for (var i = 0; i < 9; i++) _item('$i'),
    ], onUpdated: () {});

    expect(peak, lessThanOrEqualTo(CoverEnricher.maxConcurrent));
    expect(inFlight, 0);
  });

  test('rows without a book url are ignored', () async {
    var calls = 0;
    final enricher = CoverEnricher(
      fetch: (item) async {
        calls++;
        return 'https://img/x.jpg';
      },
    );

    await enricher.enrich([
      SearchItem(id: 'x', name: '无链接'),
    ], onUpdated: () {});

    expect(calls, 0);
  });
}
