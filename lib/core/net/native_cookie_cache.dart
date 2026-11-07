/// 阅读内核 Cookie 的 Dart 侧只读缓存。
///
/// 书源请求全部走引擎的 `SharedCookieStore`；封面等同步 header 场景无法等待
/// MethodChannel，因此在每次引擎调用后把当前 host 的 Cookie 缓存到这里。
/// 只做缓存，不负责写入/合并 Cookie。
class NativeCookieCache {
  NativeCookieCache._();

  static final Map<String, String> _jar = {};

  static String? headerForUrl(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return null;
    final cookie = _jar[host];
    return (cookie == null || cookie.isEmpty) ? null : cookie;
  }

  static void put(String url, String cookie) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return;
    if (cookie.isEmpty) {
      _jar.remove(host);
    } else {
      _jar[host] = cookie;
    }
  }

  static void clear() => _jar.clear();
}
