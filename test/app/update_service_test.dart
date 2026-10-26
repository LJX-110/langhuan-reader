import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/features/settings/update_page.dart';
import 'package:langhuan/features/settings/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeService extends UpdateService {
  _FakeService({this.info});

  final UpdateInfo? info;

  @override
  Future<String> localVersion() async => '2.0.0+7';

  @override
  Future<UpdateInfo?> check({bool force = false}) async => info;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('version ordering', () {
    test('parses tags, versions and build numbers', () {
      expect(parseVersionTuple('v2.1.0+8'), [2, 1, 0, 8]);
      expect(parseVersionTuple('2.0.0'), [2, 0, 0, 0]);
      expect(parseVersionTuple('1.2+3'), [1, 2, 0, 3]);
      expect(parseVersionTuple('v2.1.0'), [2, 1, 0, 0]);
      expect(parseVersionTuple('garbage'), isNull);
      expect(parseVersionTuple(''), isNull);
    });

    test('orders versions including the build number', () {
      expect(isRemoteNewer(local: '2.0.0+7', remoteTag: 'v2.1.0+8'), isTrue);
      expect(isRemoteNewer(local: '2.1.0+8', remoteTag: 'v2.1.0+8'), isFalse);
      expect(isRemoteNewer(local: '2.1.0+8', remoteTag: 'v2.1.0+9'), isTrue);
      expect(isRemoteNewer(local: '2.2.0+1', remoteTag: 'v2.1.9+99'), isFalse);
      expect(isRemoteNewer(local: '2.0.0+7', remoteTag: 'nope'), isFalse);
      expect(isRemoteNewer(local: '', remoteTag: 'v2.1.0+8'), isFalse);
    });
  });

  group('UpdateService.check', () {
    late HttpServer server;
    late String base;
    var hits = 0;
    var closed = false;
    var payload = <String, dynamic>{};

    setUp(() async {
      // The widget binding stubs every HTTP request with 400; this group talks
      // to a real loopback server, so restore the default client.
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      await SpUtil.getInstance();
      SpUtil.remove(PrefsKeys.updateLastCheck);
      SpUtil.putString(PrefsKeys.version, '2.0.0+7');
      hits = 0;
      closed = false;
      payload = {
        'tag_name': 'v2.1.0+8',
        'html_url': 'https://example.com/releases/2.1.0',
        'body': '更新说明',
      };
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server.port}';
      server.listen((request) async {
        hits++;
        final response = request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(payload));
        await response.close();
      });
    });

    tearDown(() async {
      if (!closed) await server.close(force: true);
    });

    test('reports a newer release with notes and page url', () async {
      final info = await UpdateService(apiBase: base).check(force: true);

      expect(info, isNotNull);
      expect(info!.version, '2.1.0+8');
      expect(info.tag, 'v2.1.0+8');
      expect(info.notes, '更新说明');
      expect(info.pageUrl, 'https://example.com/releases/2.1.0');
      expect(hits, 1);
    });

    test('up-to-date releases return null and start the 24h window', () async {
      payload['tag_name'] = 'v2.0.0+7';
      final service = UpdateService(apiBase: base);

      expect(await service.check(force: true), isNull);
      expect(service.autoCheckDue, isFalse);

      // Throttled auto-check does not touch the network again.
      expect(await service.check(), isNull);
      expect(hits, 1);
    });

    test('unparseable tags never report an update', () async {
      payload['tag_name'] = 'latest';
      expect(await UpdateService(apiBase: base).check(force: true), isNull);
    });

    test('network failures throw for the manual path to report', () async {
      await server.close(force: true);
      closed = true;

      await expectLater(
        UpdateService(apiBase: base).check(force: true),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('UpdatePage', () {
    testWidgets('shows the up-to-date state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: UpdatePage(service: _FakeService())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('已是最新版本'), findsOneWidget);
    });

    testWidgets('shows the newer version and download action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UpdatePage(
            service: _FakeService(
              info: const UpdateInfo(
                tag: 'v2.1.0+8',
                version: '2.1.0+8',
                notes: '更新说明',
                pageUrl: 'https://example.com/releases/2.1.0',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('发现新版本 2.1.0+8'), findsOneWidget);
      expect(find.text('前往下载'), findsOneWidget);
      expect(find.text('更新说明'), findsOneWidget);
    });
  });
}
