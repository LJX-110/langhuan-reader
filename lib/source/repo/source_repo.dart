import 'dart:convert';

import 'package:langhuan/source/import/source_importer.dart';
import 'package:dio/dio.dart';

/// Result of fetching a user-owned source repository manifest.
class SourceRepoFetch {
  const SourceRepoFetch({
    required this.url,
    required this.name,
    required this.version,
    required this.updatedAt,
    required this.parsed,
  });

  final String url;
  final String name;
  final String version;
  final String updatedAt;
  final SourceParseResult parsed;

  int get count => parsed.count;
}

/// Fetches a private book-source repository.
///
/// The app intentionally ships no repository URL and no bundled sources.
/// A repository is any JSON document containing Legado book sources, either
/// as a bare array, `{ "sources": [...] }`, or `{ "data": [...] }`.
class SourceRepo {
  SourceRepo._();

  static Future<SourceRepoFetch> fetch(String url) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('仓库地址必须是 http/https URL');
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        responseType: ResponseType.plain,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'application/json,text/plain,*/*',
        },
      ),
    );

    final response = await dio.get<String>(trimmed);
    final text = response.data ?? '';
    if (text.trim().isEmpty) {
      throw const FormatException('仓库内容为空');
    }

    final parsed = SourceImporter.parseJson(text);
    if (parsed.sources.isEmpty) {
      throw const FormatException('仓库里没有可用的书源');
    }

    var name = uri.host;
    var version = '';
    var updatedAt = '';
    try {
      final root = jsonDecode(text);
      if (root is Map) {
        name = (root['name'] ?? root['repoName'] ?? name).toString().trim();
        version = (root['version'] ?? '').toString().trim();
        updatedAt = (root['updatedAt'] ?? root['updated_at'] ?? '')
            .toString()
            .trim();
      }
    } catch (_) {
      // A bare source array has no metadata; host is a fine fallback.
    }

    return SourceRepoFetch(
      url: trimmed,
      name: name.isEmpty ? uri.host : name,
      version: version,
      updatedAt: updatedAt,
      parsed: parsed,
    );
  }
}
