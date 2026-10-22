import 'dart:convert';

import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/data/repositories/book_repository.dart';
import 'package:langhuan/core/platform/screen.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:langhuan/data/entities/book_info.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/features/detail/source_switch_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readmore/readmore.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';

/// 书籍详情（微信读书风格）
class BookDetail extends ConsumerStatefulWidget {
  final BookInfo _bookInfo;

  const BookDetail(this._bookInfo, {super.key});

  @override
  ConsumerState<BookDetail> createState() => _BookDetailState();
}

class _BookDetailState extends ConsumerState<BookDetail> {
  late Book book;

  BookInfo get info => widget._bookInfo;

  @override
  void initState() {
    super.initState();
    book = info.toBook();
  }

  bool get _dark => SpUtil.getBool(PrefsKeys.dark);

  Color get _scaffold => _dark ? AppColors.scaffoldDark : AppColors.scaffold;
  Color get _surface => _dark ? AppColors.surfaceDark : AppColors.surface;
  Color get _primary => _dark ? AppColors.textOnDark : AppColors.textPrimary;
  Color get _secondary =>
      _dark ? AppColors.textMutedDark : AppColors.textSecondary;
  Color get _divider => _dark ? AppColors.dividerDark : AppColors.divider;

  @override
  Widget build(BuildContext context) {
    final bottomBarH = AppDimens.ctaHeight + Screen.bottomSafeHeight + 20;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _scaffold,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _heroCard(),
                      const SizedBox(height: 12),
                      _sectionCard(title: '简介', child: _descBody()),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title: '目录',
                        trailing: Text(
                          '查看',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.accentOf(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTrailingTap: _openRead,
                        child: _catalogBody(),
                      ),
                      if (info.relatedBooks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _sectionCard(title: '作者还写过', child: _sameAuthorBody()),
                      ],
                      SizedBox(height: bottomBarH + 16),
                    ],
                  ),
                ),
              ],
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // App bar (plain, no colored / blurred header)
  // ---------------------------------------------------------------------------

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: _scaffold,
      foregroundColor: _primary,
      leading: IconButton(
        tooltip: '返回',
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        onPressed: () => _back(context),
      ),
      systemOverlayStyle: _dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }

  /// Detail can be reached from a replaced reader route, so fall back to the
  /// shell when there is nothing to pop.
  Future<void> _back(BuildContext context) async {
    final popped = await Navigator.maybePop(context);
    if (!popped && context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ---------------------------------------------------------------------------
  // Hero card (cover + meta)
  // ---------------------------------------------------------------------------

  Widget _heroCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: AppShadows.cover,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: PicWidget(book.coverUrl, height: 136, width: 98),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayText(book.name, fallback: '未知书名'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _displayText(book.author, fallback: '佚名'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _secondary),
                ),
                if (_hasText(book.category)) ...[
                  const SizedBox(height: 3),
                  Text(
                    book.category.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: _secondary),
                  ),
                ],
                if (_hasText(book.originName)) ...[
                  const SizedBox(height: 3),
                  Text(
                    book.originName.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: _secondary),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (info.status.isNotEmpty)
                      _chip(
                        info.status,
                        bg: AppColors.accentOf(context).withValues(alpha: .09),
                        fg: AppColors.accentOf(context),
                      ),
                    if (info.rating > 0)
                      _chip(
                        '评分 ${info.rating.toStringAsFixed(1)}',
                        bg: AppColors.paperDeep,
                        fg: _secondary,
                      ),
                    if (info.ratingCount > 0)
                      _chip(
                        '${_formatCount(info.ratingCount)} 人气',
                        bg: AppColors.paperDeep,
                        fg: _secondary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: .18), width: .5),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section card shell
  // ---------------------------------------------------------------------------

  Widget _sectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
    VoidCallback? onTrailingTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _divider, width: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(right: 8),
                color: AppColors.accentOf(context),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
              const Spacer(),
              if (trailing != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTrailingTap,
                    borderRadius: BorderRadius.circular(6),
                    child: trailing,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Description
  // ---------------------------------------------------------------------------

  Widget _descBody() {
    final desc = info.description.trim();
    if (desc.isEmpty) {
      return Text(
        '暂无简介',
        style: TextStyle(fontSize: 14, color: _secondary, height: 1.6),
      );
    }
    final accent = AppColors.accentOf(context);
    return ReadMoreText(
      desc,
      trimLines: 4,
      trimMode: TrimMode.Line,
      colorClickableText: accent,
      trimCollapsedText: ' 展开',
      trimExpandedText: ' 收起',
      style: TextStyle(
        fontSize: 14,
        height: 1.7,
        color: _primary.withValues(alpha: 0.88),
      ),
      moreStyle: TextStyle(
        fontSize: 14,
        color: accent,
        fontWeight: FontWeight.w500,
      ),
      lessStyle: TextStyle(
        fontSize: 14,
        color: accent,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Catalog / latest chapter
  // ---------------------------------------------------------------------------

  Widget _catalogBody() {
    final latest = info.latestChapter.trim();
    final time = info.updatedAt.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openRead,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentSoftOf(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  size: 18,
                  color: AppColors.accentOf(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest.isEmpty ? '暂无章节信息' : latest,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _primary,
                      ),
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '更新于 $time',
                        style: TextStyle(fontSize: 12, color: _secondary),
                      ),
                    ] else
                      Text(
                        '最新章节',
                        style: TextStyle(fontSize: 12, color: _secondary),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: _secondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Same author
  // ---------------------------------------------------------------------------

  Widget _sameAuthorBody() {
    final list = info.relatedBooks;
    return Column(
      children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) Divider(height: 1, color: _divider),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.coverRadius),
                  child: PicWidget(list[i].coverUrl, height: 72, width: 52),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayText(list[i].name, fallback: '未知书名'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _displayText(list[i].author, fallback: '佚名'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: _secondary),
                      ),
                      if (_hasText(list[i].latestChapter)) ...[
                        const SizedBox(height: 4),
                        Text(
                          list[i].latestChapter.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom action bar
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    final model = ref.watch(shelfModelProvider);
    final inShelf = model.inShelf(info.id);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border(top: BorderSide(color: _divider, width: .5)),
        ),
        padding: EdgeInsets.fromLTRB(12, 10, 12, Screen.bottomSafeHeight + 10),
        child: Row(
          children: [
            _barIconBtn(
              icon: inShelf
                  ? Icons.bookmark_remove_outlined
                  : Icons.bookmark_add_outlined,
              label: inShelf ? '移出' : '书架',
              onTap: () {
                model.modifyShelf(book);
              },
            ),
            _barIconBtn(
              icon: Icons.swap_horiz,
              label: '换源',
              onTap: () async {
                final readModel = ref.read(readModelProvider);
                // Seed only when idle — don't clobber an active reading session.
                if (!readModel.sessionReady || readModel.book?.id != book.id) {
                  readModel.book = book;
                }
                final ok = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => SourceSwitchSheet(
                    readModel: readModel,
                    onSwitched: (b) {
                      // Keep detail page fields in sync with the new source.
                      book
                        ..sourceUrl = b.sourceUrl
                        ..bookUrl = b.bookUrl
                        ..originName = b.originName
                        ..tocUrl = b.tocUrl
                        ..name = b.name.isNotEmpty ? b.name : book.name
                        ..author = b.author.isNotEmpty ? b.author : book.author
                        ..coverUrl = b.coverUrl.isNotEmpty
                            ? b.coverUrl
                            : book.coverUrl
                        ..description = b.description.isNotEmpty
                            ? b.description
                            : book.description
                        ..latestChapter = b.latestChapter.isNotEmpty
                            ? b.latestChapter
                            : book.latestChapter;
                      info
                        ..sourceUrl = book.sourceUrl
                        ..bookUrl = book.bookUrl
                        ..originName = book.originName
                        ..tocUrl = book.tocUrl
                        ..name = book.name
                        ..author = book.author
                        ..coverUrl = book.coverUrl
                        ..description = book.description
                        ..latestChapter = book.latestChapter;
                      if (mounted) setState(() {});
                    },
                  ),
                );
                if (ok == true && mounted) setState(() {});
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: AppDimens.ctaHeight,
                child: FutureBuilder<bool>(
                  future: BookRepository.instance.exists(book.id),
                  builder: (context, snap) {
                    final hasRead = snap.data == true;
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentOf(context),
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _openRead,
                      child: Text(
                        hasRead ? '继续阅读' : '立即阅读',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barIconBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: _primary),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, color: _secondary)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _openRead() async {
    Book? b = await BookRepository.instance.getById(book.id);
    if (!mounted) return;
    Routes.navigateTo(
      context,
      Routes.read,
      params: {'read': jsonEncode(b ?? book)},
    );
  }

  String _formatCount(int n) {
    if (n >= 10000) {
      final v = n / 10000;
      return v >= 10 ? '${v.toStringAsFixed(0)}万' : '${v.toStringAsFixed(1)}万';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}k';
    }
    return '$n';
  }

  bool _hasText(String? s) {
    if (s == null) return false;
    final t = s.trim();
    return t.isNotEmpty && t != 'null';
  }

  String _displayText(String? s, {String fallback = ''}) {
    if (!_hasText(s)) return fallback;
    return s!.trim();
  }
}
