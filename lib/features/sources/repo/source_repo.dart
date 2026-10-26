import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:langhuan/features/sources/import/source_importer.dart';
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
///
/// Private GitHub repositories need [token]: raw.githubusercontent no longer
/// serves private files with URL/basic auth, so GitHub URLs are rewritten to
/// the Contents API with an `Authorization: Bearer` header.
class SourceRepo {
  SourceRepo._();

  static Future<SourceRepoFetch> fetch(String url, {String token = ''}) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('仓库地址必须是 http/https URL');
    }

    final request = resolveRequest(trimmed, token);
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
          ...request.headers,
        },
      ),
    );

    final response = await dio.get<String>(request.url);
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

  /// Map the user-entered repository URL to the effective request.
  ///
  /// Without a token the URL is fetched as-is (public raw JSON). With a token,
  /// GitHub hosts are rewritten to `api.github.com/repos/.../contents/...`;
  /// the token is **only** ever attached to GitHub hosts.
  @visibleForTesting
  static ({String url, Map<String, String> headers}) resolveRequest(
    String url,
    String token,
  ) {
    final trimmed = url.trim();
    final key = token.trim();
    if (key.isEmpty) return (url: trimmed, headers: const {});

    final uri = Uri.tryParse(trimmed);
    final host = uri?.host.toLowerCase() ?? '';
    const githubHosts = {
      'github.com',
      'www.github.com',
      'raw.githubusercontent.com',
      'api.github.com',
    };
    if (!githubHosts.contains(host)) {
      throw const FormatException('Token 只用于 GitHub 仓库；其它地址请留空 Token');
    }
    final headers = <String, String>{
      'Authorization': 'Bearer $key',
      'Accept': 'application/vnd.github.raw+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    if (host == 'api.github.com') {
      return (url: trimmed, headers: headers);
    }

    final segs = uri!.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length < 4) {
      throw const FormatException(
        'GitHub 地址需要包含 owner/仓库/分支/文件路径',
      );
    }
    final owner = segs[0];
    final repo = segs[1];
    var rest = segs.sublist(2);
    if (host != 'raw.githubusercontent.com') {
      if (rest.isEmpty || (rest.first != 'blob' && rest.first != 'raw')) {
        throw const FormatException(
          'GitHub 地址格式应为 .../blob/<分支>/<文件>',
        );
      }
      rest = rest.sublist(1);
    }
    if (rest.length < 2) {
      throw const FormatException('GitHub 地址缺少分支或文件路径');
    }
    final ref = rest.first;
    final path = rest.sublist(1).join('/');
    final apiUrl = Uri.https('api.github.com', '/repos/$owner/$repo/contents/$path', {
      'ref': ref,
    });
    return (url: apiUrl.toString(), headers: headers);
  }
}
