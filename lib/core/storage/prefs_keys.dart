/// Canonical SpUtil key strings used across the app.
///
/// Prefer these over string literals so prefs stay discoverable.
class PrefsKeys {
  PrefsKeys._();

  static const dark = 'dark';
  static const themeIndex = 'theme_index';
  static const version = 'version';
  static const coverGrid = 'cover';

  /// Shelf view: `3d` | `grid` | `list`. Falls back to [coverGrid] when absent.
  static const shelfView = 'shelf_view';

  /// Local page: true shows the 3D shelf instead of the list.
  static const local3d = 'local_3d';
  static const leftClickNext = 'leftClickNext';
  static const pageTurnMode = 'turnPageAnima';
  static const readerTextAlign = 'reader_text_align';

  /// Neighbor chapter prefetch range (chapters before / after the current).
  static const readerPrefetchBack = 'reader_prefetch_back';
  static const readerPrefetchForward = 'reader_prefetch_forward';
  static const bookSearchHistory = 'book_search_history';
  static const readingStyle = 'READINGSTYLE';
  static const fonts = 'fonts';
  static const bookPicWidth = 'book_pic_width';
  static const topSafeHeight = 'top_safe_height';
  static const shimmerNums = 'shimmer_nums';
  static const sourceDisclaimerAgreed = 'source_disclaimer_agreed';
  static const sourceRepoUrl = 'source_repo_url';
  static const sourceRepoName = 'source_repo_name';
  static const sourceRepoLastSync = 'source_repo_last_sync';

  /// Optional GitHub token for a **private** source repository. Stored in
  /// plain prefs on this device only; never logged and never sent to
  /// non-GitHub hosts.
  static const sourceRepoToken = 'source_repo_token';

  /// High-risk opt-in: allow a source's `X-Langhuan-Insecure-TLS` header to
  /// trigger the lenient certificate retry. Default is strict validation.
  static const allowInsecureTls = 'allow_insecure_tls';

  /// Last successful update check (ms). Auto check stays silent for 24h after.
  static const updateLastCheck = 'update_last_check';
}
