import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/features/local/folder_scan_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('langhuan/folder');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'pickFolder':
          return {'uri': 'content://tree/books', 'name': '小说'};
        case 'scanFolder':
          return {
            'name': '小说',
            'files': [
              {
                'name': 'a.txt',
                'path': '/tmp/a.txt',
                'uri': 'content://a',
                'size': 3,
              },
              {'name': 'b.txt', 'path': '', 'uri': 'content://b', 'size': 4},
              {
                'name': 'c.md',
                'path': '/tmp/c.md',
                'uri': 'content://c',
                'size': 5,
              },
            ],
          };
        default:
          return null;
      }
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('pickFolder returns the SAF tree uri and display name', () async {
    final folder = await FolderScanService().pickFolder();
    expect(folder?.uri, 'content://tree/books');
    expect(folder?.name, '小说');
  });

  test('pickFolder returns null when the user cancels', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(await FolderScanService().pickFolder(), isNull);
  });

  test('scanFolder parses files and keeps only readable paths', () async {
    final result = await FolderScanService().scanFolder('content://tree/books');
    expect(result.folderName, '小说');
    expect(result.files, hasLength(2));
    expect(result.files.first.name, 'a.txt');
    expect(result.files.first.size, 3);
    expect(result.files[1].name, 'c.md');
  });
}
