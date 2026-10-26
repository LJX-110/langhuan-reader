import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/components/shelf_book_view.dart';
import 'package:langhuan/design/components/shelf_geometry.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// Continuous 3D shelf.
///
/// The focused volume faces the reader; neighbours turn away until their
/// spines carry the row. The shelf is finite (first / last book stop in the
/// middle, no wrap-around) and each volume is a solid: spine, cover, page
/// edge and a top face that shares vertices with the spine and cover.
class Bookshelf3D extends StatefulWidget {
  const Bookshelf3D({
    super.key,
    required this.books,
    required this.onOpen,
    this.initialBookId,
    this.onDelete,
    this.deleteWarning = '',
    this.selectable = false,
    this.selectedIds = const <String>{},
    this.onToggleSelect,
    this.onReorder,
    this.entryAnimation = true,
  });

  final List<ShelfBookView> books;
  final ValueChanged<ShelfBookView> onOpen;

  /// Book focused on first build (usually the most recently read one).
  final String? initialBookId;

  /// When set, the focused volume shows a small remove button and deletes go
  /// through an inline confirm row.
  final Future<void> Function(ShelfBookView book)? onDelete;

  /// Extra warning inside the inline confirm row (e.g. 本地书不可撤销).
  final String deleteWarning;

  /// Sort mode: tap toggles selection instead of opening the book.
  final bool selectable;
  final Set<String> selectedIds;
  final ValueChanged<ShelfBookView>? onToggleSelect;

  /// Sort mode: long-press drag reports the new position.
  final Future<void> Function(int oldIndex, int newIndex)? onReorder;

  /// Staggered rise/fade on first layout; disabled by [MediaQuery.disableAnimations].
  final bool entryAnimation;

  @override
  State<Bookshelf3D> createState() => _Bookshelf3DState();
}

class _Bookshelf3DState extends State<Bookshelf3D>
    with TickerProviderStateMixin {
  /// Volumes beyond this distance from the focus are not built.
  static const int _renderWindow = 5;

  /// Fractional focus index: whole numbers sit on a book, values in between
  /// are reached while dragging. Always kept inside `[0, books.length - 1]`.
  double _f = 0;
  String? _focusId;
  int _hapticSlot = 0;

  late final AnimationController _settle;
  double _settleFrom = 0;
  double _settleTo = 0;

  late final AnimationController _entry;

  int? _grabbedIndex;
  double _grabDx = 0;
  int? _reorderTarget;

  ShelfBookView? _pendingDelete;
  bool _deleteBusy = false;

  int get _maxIndex => math.max(0, widget.books.length - 1);

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_onSettleTick);
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    if (widget.entryAnimation) {
      _entry.forward();
    } else {
      _entry.value = 1;
    }
    final initial = _indexOf(widget.initialBookId);
    _f = (initial ?? 0).clamp(0, _maxIndex).toDouble();
    _hapticSlot = _f.round();
    _focusId = widget.books.isEmpty ? null : widget.books[_f.round()].id;
  }

  int? _indexOf(String? id) {
    if (id == null || id.isEmpty) return null;
    for (var i = 0; i < widget.books.length; i++) {
      if (widget.books[i].id == id) return i;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant Bookshelf3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    final listChanged =
        !identical(oldWidget.books, widget.books) ||
        oldWidget.books.length != widget.books.length;
    if (widget.books.isEmpty) {
      _f = 0;
      _focusId = null;
      _pendingDelete = null;
      _grabbedIndex = null;
      _reorderTarget = null;
      return;
    }
    // Keep the focused book selected across filters and reloads.
    if (listChanged) {
      final byId = _indexOf(_focusId);
      if (byId != null) {
        _f = byId.toDouble();
      } else {
        _f = _f.round().clamp(0, _maxIndex).toDouble();
      }
      _focusId = widget.books[_f.round()].id;
    } else {
      _f = _f.clamp(0, _maxIndex).toDouble();
    }
    if (_pendingDelete != null &&
        !widget.books.any((b) => b.id == _pendingDelete!.id)) {
      // The parent removed the book while we waited.
      _pendingDelete = null;
      _deleteBusy = false;
    }
    if (_grabbedIndex != null && _grabbedIndex! > _maxIndex) {
      _grabbedIndex = null;
      _reorderTarget = null;
      _grabDx = 0;
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    _entry.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    if (!mounted) return;
    setState(() {
      _f = _settleFrom + (_settleTo - _settleFrom) * Curves.easeOutCubic.transform(_settle.value);
    });
    _maybeHaptic();
  }

  void _maybeHaptic() {
    final slot = _f.round();
    if (slot == _hapticSlot) return;
    _hapticSlot = slot;
    if (!MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.selectionClick();
    }
  }

  void _startSettle({double? to}) {
    final target = (to ?? _f.round().toDouble()).clamp(
      0.0,
      _maxIndex.toDouble(),
    );
    if ((target - _f).abs() < 0.001) {
      _settle.stop();
      _focusId = widget.books[_f.round()].id;
      return;
    }
    _settleFrom = _f;
    _settleTo = target;
    _settle.forward(from: 0);
    _focusId = widget.books[target.round()].id;
  }

  void _onShelfDragUpdate(DragUpdateDetails details, ShelfMetrics m) {
    if (_grabbedIndex != null) return;
    _settle.stop();
    setState(() {
      _f = (_f - details.delta.dx / m.snapPitch).clamp(
        0.0,
        _maxIndex.toDouble(),
      );
    });
    _maybeHaptic();
  }

  void _onShelfDragEnd() {
    if (_grabbedIndex != null) return;
    _startSettle();
  }

  void _onTapBook(int index) {
    final book = widget.books[index];
    if (widget.selectable) {
      widget.onToggleSelect?.call(book);
      return;
    }
    if (index == _f.round()) {
      widget.onOpen(book);
    } else {
      _startSettle(to: index.toDouble());
    }
  }

  void _onLongPressStart(int index) {
    if (widget.onReorder == null) return;
    _settle.stop();
    setState(() {
      _grabbedIndex = index;
      _grabDx = 0;
      _reorderTarget = index;
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.selectionClick();
    }
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details, ShelfMetrics m) {
    final from = _grabbedIndex;
    if (from == null) return;
    final dx = details.offsetFromOrigin.dx;
    final target = (from + (dx / m.snapPitch).round()).clamp(0, _maxIndex);
    final changed = target != _reorderTarget;
    setState(() {
      _grabDx = dx;
      _reorderTarget = target;
    });
    if (changed && !MediaQuery.disableAnimationsOf(context)) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _onLongPressEnd() async {
    final from = _grabbedIndex;
    final to = _reorderTarget;
    setState(() {
      _grabbedIndex = null;
      _reorderTarget = null;
      _grabDx = 0;
    });
    if (from == null || to == null || from == to) return;
    await widget.onReorder?.call(from, to);
  }

  void _askDelete() {
    if (_pendingDelete != null || _deleteBusy) return;
    final focused = widget.books[_f.round()];
    setState(() => _pendingDelete = focused);
  }

  Future<void> _confirmDelete() async {
    final book = _pendingDelete;
    final onDelete = widget.onDelete;
    if (book == null || onDelete == null || _deleteBusy) return;
    setState(() => _deleteBusy = true);
    try {
      await onDelete(book);
    } finally {
      if (mounted) {
        setState(() {
          _deleteBusy = false;
          _pendingDelete = null;
        });
      }
    }
  }

  double _entryProgressFor(double d) {
    if (!widget.entryAnimation) return 1;
    final order = d.abs().clamp(0.0, _renderWindow.toDouble());
    final delay = order * .12;
    final span = math.max(.35, 1 - delay);
    final t = ((_entry.value - delay) / span).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        final size = Size(
          constraints.maxWidth,
          bounded ? constraints.maxHeight : 420,
        );
        final m = ShelfMetrics.forSize(size);
        final dark = Theme.of(context).brightness == Brightness.dark;
        final focused = widget.books[_f.round()];

        final children = <Widget>[
          // Rail: one hairline the volumes stand on.
          Positioned(
            left: 10,
            right: 10,
            top: m.railY,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                color: dark ? AppColors.dividerDark : AppColors.line,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? .28 : .08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        ];

        // Paint far volumes first so the focused one stays on top.
        final order = <int>[];
        for (var i = 0; i < widget.books.length; i++) {
          final d = i - _f;
          if (d.abs() > _renderWindow + .5) continue;
          order.add(i);
        }
        order.sort((a, b) {
          final da = (a - _f).abs();
          final db = (b - _f).abs();
          final byDistance = db.compareTo(da);
          if (byDistance != 0) return byDistance;
          if (a == _grabbedIndex) return 1;
          if (b == _grabbedIndex) return -1;
          return 0;
        });

        // Insertion marker while reordering.
        final target = _reorderTarget;
        if (target != null && _grabbedIndex != null) {
          final td = target - _f;
          if (td.abs() <= _renderWindow + .5) {
            final tx = m.xForD(td) +
                (td < 0 ? m.boxW - m.spineW / 2 : m.spineW / 2);
            children.add(
              Positioned(
                left: tx - 1,
                top: m.railY - m.bodyH - 6,
                width: 2,
                height: m.bodyH + 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.companionOf(context),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            );
          }
        }

        for (final i in order) {
          final d = i - _f;
          final mirrored = d < 0;
          final x = m.xForD(d);
          final y = m.railY - m.bodyH + m.yForD(d);
          final entry = _entryProgressFor(d);
          final grabbed = i == _grabbedIndex;
          children.add(
            Positioned(
              key: ValueKey('shelf-book-${widget.books[i].id}'),
              left: x,
              top: y - m.depthY,
              width: m.volumeW,
              height: m.volumeH + 8,
              child: Transform.translate(
                offset: Offset(grabbed ? _grabDx : 0, grabbed ? -18 : 0),
                child: Opacity(
                  opacity: entry,
                  child: Transform.translate(
                    offset: Offset(0, (1 - entry) * 16),
                    child: _ShelfVolume(
                      book: widget.books[i],
                      metrics: m,
                      d: d,
                      mirrored: mirrored,
                      focused: i == _f.round(),
                      selectable: widget.selectable,
                      picked: widget.selectedIds.contains(widget.books[i].id),
                      grabbed: grabbed,
                      onTap: () => _onTapBook(i),
                      onLongPressStart: widget.onReorder == null
                          ? null
                          : () => _onLongPressStart(i),
                      onLongPressMove: widget.onReorder == null
                          ? null
                          : (details) => _onLongPressMove(details, m),
                      onLongPressEnd: widget.onReorder == null
                          ? null
                          : _onLongPressEnd,
                      onRemove: widget.onDelete == null || i != _f.round()
                          ? null
                          : _askDelete,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        children.add(
          Positioned(
            left: 16,
            right: 16,
            top: m.railY + 10,
            height: math.max(0, m.metaHeight - 12),
            // The meta block is a fixed-height band: cap text growth so a
            // large system font cannot overflow it (the 3D test matrix covers
            // 1.3× scale).
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.1,
              child: _meta(context, focused, dark),
            ),
          ),
        );

        final canvas = Stack(clipBehavior: Clip.hardEdge, children: children);
        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onHorizontalDragStart: (_) {
            if (_grabbedIndex == null) _settle.stop();
          },
          onHorizontalDragUpdate: (details) =>
              _onShelfDragUpdate(details, m),
          onHorizontalDragEnd: (_) => _onShelfDragEnd(),
          onHorizontalDragCancel: _onShelfDragEnd,
          child: bounded ? canvas : SizedBox(height: size.height, child: canvas),
        );
      },
    );
  }

  Widget _meta(BuildContext context, ShelfBookView focused, bool dark) {
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
    final pending = _pendingDelete;
    if (pending != null) {
      return _confirmRow(context, pending, muted);
    }
    final accent = AppColors.accentOf(context);
    final count =
        '${(_f.round() + 1).toString().padLeft(2, '0')} / '
        '${widget.books.length.toString().padLeft(2, '0')}';
    final meta = focused.progressLabel.isEmpty
        ? focused.author
        : '${focused.author.isEmpty ? '未知作者' : focused.author} · '
              '${focused.progressLabel}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                focused.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, height: 1.35, color: muted),
              ),
              if (focused.hasUpdate) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.companionOf(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '有更新',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.companionOf(context),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Text(
          count,
          style: TextStyle(fontSize: 10, letterSpacing: 1, color: muted),
        ),
      ],
    );
  }

  Widget _confirmRow(BuildContext context, ShelfBookView book, Color muted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: AppColors.danger.withValues(alpha: .55),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '移除《${book.name}》？',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                if (widget.deleteWarning.isNotEmpty)
                  Text(
                    widget.deleteWarning,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('shelf-delete-cancel'),
            onPressed: _deleteBusy
                ? null
                : () => setState(() => _pendingDelete = null),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('取消', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            key: const ValueKey('shelf-delete-confirm'),
            onPressed: _deleteBusy ? null : _confirmDelete,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: AppColors.danger,
            ),
            child: _deleteBusy
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('移除', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// One volume: spine + cover + page edge + top face, rotated around its spine.
class _ShelfVolume extends StatelessWidget {
  const _ShelfVolume({
    required this.book,
    required this.metrics,
    required this.d,
    required this.mirrored,
    required this.focused,
    required this.selectable,
    required this.picked,
    required this.grabbed,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressMove,
    this.onLongPressEnd,
    this.onRemove,
  });

  final ShelfBookView book;
  final ShelfMetrics metrics;
  final double d;
  final bool mirrored;
  final bool focused;
  final bool selectable;
  final bool picked;
  final bool grabbed;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final void Function(LongPressMoveUpdateDetails details)? onLongPressMove;
  final Future<void> Function()? onLongPressEnd;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final m = metrics;
    final turn = m.yawForD(d).abs();
    final angle = mirrored ? -turn : turn;
    final alignment = mirrored ? Alignment.centerRight : Alignment.centerLeft;

    final body = SizedBox(
      width: m.boxW,
      height: m.bodyH,
      child: _volumeBody(context, dark),
    );

    return Semantics(
      label:
          '《${book.name}》，${book.author.isEmpty ? '未知作者' : book.author}'
          '，${book.progressLabel}${picked ? '，已选择' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPressStart:
            onLongPressStart == null ? null : (_) => onLongPressStart!(),
        onLongPressMoveUpdate: onLongPressMove,
        onLongPressEnd:
            onLongPressEnd == null ? null : (_) => onLongPressEnd!(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Top face first so the book body overlaps it cleanly.
            Positioned.fill(
              child: CustomPaint(
                painter: _TopFacePainter(
                  metrics: m,
                  paper: dark ? AppColors.surfaceDark : AppColors.paperWhite,
                  shadow: dark ? AppColors.dividerDark : AppColors.paperDeep,
                  line: dark ? AppColors.dividerDark : AppColors.line,
                  tint: AppColors.companionOf(context),
                  dark: dark,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: m.depthY,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? .34 : .16),
                      blurRadius: grabbed ? 22 : 12,
                      offset: Offset(0, grabbed ? 12 : 7),
                    ),
                  ],
                ),
                child: Transform(
                  alignment: alignment,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0015)
                    ..rotateY(angle),
                  child: body,
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                key: const ValueKey('shelf-remove'),
                left: m.boxW / 2 - 24,
                top: m.depthY + m.bodyH - 26,
                width: 48,
                height: 20,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onRemove,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: .6),
                        ),
                      ),
                      child: const Text(
                        '移除',
                        style: TextStyle(fontSize: 11, color: AppColors.danger),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _volumeBody(BuildContext context, bool dark) {
    final m = metrics;
    final accent = AppColors.accentOf(context);
    final companion = AppColors.companionOf(context);
    final onAccent = AppColors.onColorOf(accent);
    final cover = Expanded(
      child: Stack(
        fit: StackFit.expand,
        children: [
          PicWidget(
            book.coverUrl,
            width: m.coverW,
            height: m.bodyH,
            radius: 0,
            referer: book.referer,
            title: book.name,
          ),
          if (book.hasUpdate)
            Positioned(
              top: 0,
              right: mirrored ? null : 0,
              left: mirrored ? 0 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.updateBadge,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(mirrored ? 0 : 5),
                    bottomRight: Radius.circular(mirrored ? 5 : 0),
                  ),
                ),
                child: const Text(
                  '更新',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (selectable)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: picked
                      ? accent
                      : (dark ? AppColors.surfaceDark : AppColors.paperWhite),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: picked ? accent : companion.withValues(alpha: .8),
                    width: 1.5,
                  ),
                ),
                child: picked
                    ? Icon(Icons.check, size: 13, color: onAccent)
                    : null,
              ),
            ),
        ],
      ),
    );
    final spine = Container(
      width: m.spineW,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.alphaBlend(Colors.black.withValues(alpha: .24), accent),
            accent,
            Color.alphaBlend(Colors.white.withValues(alpha: .14), accent),
          ],
        ),
        border: Border(
          right: mirrored
              ? BorderSide.none
              : BorderSide(color: companion.withValues(alpha: .75), width: .8),
          left: mirrored
              ? BorderSide(color: companion.withValues(alpha: .75), width: .8)
              : BorderSide.none,
        ),
      ),
      child: RotatedBox(
        quarterTurns: 3,
        child: Center(
          child: Text(
            book.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 7.5,
              height: 1,
              letterSpacing: .3,
              color: onAccent,
            ),
          ),
        ),
      ),
    );
    final foreEdge = SizedBox(
      width: 5,
      height: m.bodyH,
      child: CustomPaint(painter: _PageEdgePainter(dark, m)),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: companion.withValues(alpha: focused ? .0 : .35),
          width: .5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: Row(
          children: mirrored
              ? [foreEdge, cover, spine]
              : [spine, cover, foreEdge],
        ),
      ),
    );
  }
}

/// Quad connecting the spine top and the cover top to the shelf's top face.
class _TopFacePainter extends CustomPainter {
  const _TopFacePainter({
    required this.metrics,
    required this.paper,
    required this.shadow,
    required this.line,
    required this.tint,
    required this.dark,
  });

  final ShelfMetrics metrics;
  final Color paper;
  final Color shadow;
  final Color line;
  final Color tint;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final m = metrics;
    final boxW = m.boxW;
    final top = Color.alphaBlend(
      tint.withValues(alpha: dark ? .10 : .05),
      paper,
    );
    final quad = Path()
      ..moveTo(0, m.depthY)
      ..lineTo(boxW, m.depthY)
      ..lineTo(boxW + m.depthX, 0)
      ..lineTo(m.depthX, 0)
      ..close();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [shadow, top],
      ).createShader(Rect.fromLTWH(0, 0, size.width, m.depthY + 2));
    canvas.drawPath(quad, paint);
    canvas.drawPath(
      quad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5
        ..color = line,
    );
    // The front edge (where top face meets spine / cover) reads as a seam.
    canvas.drawLine(
      Offset(0, m.depthY),
      Offset(boxW, m.depthY),
      Paint()
        ..strokeWidth = .6
        ..color = line,
    );
  }

  @override
  bool shouldRepaint(covariant _TopFacePainter oldDelegate) =>
      oldDelegate.paper != paper ||
      oldDelegate.tint != tint ||
      oldDelegate.metrics != metrics;
}

/// Hairline stack on the fore-edge so the volume reads as paper, not a slab.
class _PageEdgePainter extends CustomPainter {
  const _PageEdgePainter(this.dark, this.metrics);

  final bool dark;
  final ShelfMetrics metrics;

  @override
  void paint(Canvas canvas, Size size) {
    // Paper tones derive from the existing tokens; no fixed swatches so the
    // 12 themes stay untouched while dark mode keeps a light page edge.
    final paper = dark
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: .68),
            AppColors.surfaceDark,
          )
        : AppColors.paperWhite;
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final line = Paint()
      ..color = Colors.black.withValues(alpha: .10)
      ..strokeWidth = .5;
    for (var y = 2.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _PageEdgePainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.metrics != metrics;
}
