import 'package:flutter/services.dart';

/// Folder chosen through Android's Storage Access Framework.
class PickedFolder {
  const PickedFolder({required this.uri, required this.name});

  final String uri;
  final String name;
}

/// One TXT copied into the app cache by the native folder scanner.
class ScannedTxtFile {
  const ScannedTxtFile({
    required this.name,
    required this.path,
    required this.uri,
    required this.size,
  });

  final String name;
  final String path;
  final String uri;
  final int size;

  factory ScannedTxtFile.fromMap(Map<Object?, Object?> map) {
    return ScannedTxtFile(
      name: (map['name'] as String?) ?? '',
      path: (map['path'] as String?) ?? '',
      uri: (map['uri'] as String?) ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class FolderScanResult {
  const FolderScanResult({required this.folderName, required this.files});

  final String folderName;
  final List<ScannedTxtFile> files;
}

/// Android-only SAF bridge; picking a folder grants a persistable read URI.
class FolderScanService {
  static const MethodChannel _channel = MethodChannel('langhuan/folder');

  Future<PickedFolder?> pickFolder() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'pickFolder',
    );
    if (result == null) return null;
    final uri = result['uri'] as String?;
    if (uri == null || uri.isEmpty) return null;
    return PickedFolder(uri: uri, name: (result['name'] as String?) ?? '文件夹');
  }

  Future<FolderScanResult> scanFolder(String uri) async {
    final payload = await _channel.invokeMapMethod<Object?, Object?>(
      'scanFolder',
      {'uri': uri},
    );
    if (payload == null) {
      throw const FormatException('文件夹扫描没有返回结果');
    }
    final rawFiles = (payload['files'] as List<Object?>?) ?? const [];
    final files = rawFiles
        .whereType<Map<Object?, Object?>>()
        .map(ScannedTxtFile.fromMap)
        .where((file) => file.path.isNotEmpty)
        .toList(growable: false);
    return FolderScanResult(
      folderName: (payload['name'] as String?) ?? '文件夹',
      files: files,
    );
  }
}
