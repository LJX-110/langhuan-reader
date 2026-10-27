import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:langhuan/design/components/shelf_book_view.dart';
import 'package:langhuan/design/components/shelf_geometry.dart';
import 'package:langhuan/design/components/shelf_palette.dart';
import 'package:langhuan/design/components/shelf_pose.dart';
import 'package:langhuan/design/components/shelf_scene.dart';
import 'package:langhuan/design/components/shelf_scroll_physics.dart';
import 'package:langhuan/design/components/shelf_volume.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// 3D 书架：一排书脊 + 景深，滚动位置是唯一时钟。
///
/// 中心的那本从行里「抽」出来（连续抽出波：cos² 权重，左右各到 ±1.48 格），
/// 邻书退回书脊，整排沿行内弧线轻微下沉；松手后先摩擦减速再落回整数格位，
/// 每进入一个格位一次轻触感。书架是有限的：第一本与最后一本都停在正中，
/// 两端不循环，只构建可视窗口内的书。
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
    with SingleTickerProviderStateMixin {
  /// 行框下方留给书名 / 作者 / 计数的固定高度。
  static const double _metaHeight = 76;

  /// 点按邻书后滚到中心的时间，末段带一点点回弹。
  static const Duration _centreDuration = Duration(milliseconds: 280);
  static const Curve _centreCurve = Cubic(.2, 1.06, .35, 1);

  /// 入场装配：整排从后场推上来。
  static const Duration _entryDuration = Duration(milliseconds: 720);

  late final ShelfPose _pose;
  late final ValueNotifier<int> _active;
  late final AnimationController _entry;
  late final Animation<double> _metaFade;
  late final Animation<Offset> _metaSlide;

  ScrollController? _scroll;
  bool _reduced = false;

  /// 需要真实构建的窗口（左闭右开），跟着中心走。
  int _firstSlot = 0;
  int _endSlot = 0;
  bool _windowSyncScheduled = false;
  bool _laneSyncScheduled = false;
  int? _pendingLane;

  /// 视觉中心的书名 id：书目增删时按它把中心找回来。
  String? _focusId;

  /// 触感：一次手势里每进一个格位响一次，不连续震动。
  bool _hapticGesture = false;
  int? _lastDetent;
  int _lastPulse = -1000;
  int _command = 0;

  /// 行内二次确认。
  ShelfBookView? _pendingDelete;
  bool _deleteBusy = false;

  int get _lastSlot => widget.books.isEmpty ? 0 : widget.books.length - 1;

  @override
  void initState() {
    super.initState();
    _pose = ShelfPose(count: widget.books.length);
    _entry = AnimationController(vsync: this, duration: _entryDuration)
      ..value = widget.entryAnimation ? 0 : 1
      ..addListener(_assemble);
    _metaFade = _entry.drive(
      CurveTween(curve: const Interval(.45, 1, curve: Curves.easeOutCubic)),
    );
    _metaSlide = _entry.drive(
      Tween<Offset>(begin: const Offset(0, .16), end: Offset.zero).chain(
        CurveTween(curve: const Interval(.45, 1, curve: Curves.easeOutCubic)),
      ),
    );
    final lane = (_indexOf(widget.initialBookId) ?? 0).clamp(0, _lastSlot);
    _pose.move(lane.toDouble(), notify: false);
    _focusId = widget.books.isEmpty ? null : widget.books[lane].id;
    _active = ValueNotifier<int>(lane);
    _pose.present(_entry.value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (!widget.entryAnimation ||
        _reduced ||
        !TickerMode.valuesOf(context).enabled) {
      _finishEntrance();
    } else if (!_entry.isAnimating && !_entry.isCompleted) {
      _pose.present(_entry.value);
      _entry.forward();
    }
  }

  @override
  void didUpdateWidget(covariant Bookshelf3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pose.count = widget.books.length;
    if (widget.books.isEmpty) {
      _pose.move(0, notify: false);
      _pendingLane = null;
      _focusId = null;
      _pendingDelete = null;
      _deleteBusy = false;
      _pose.endGrab();
      return;
    }
    // 书目变了：按 id 把中心的那本找回来，找不到就退回当前格位。
    final listChanged =
        !identical(oldWidget.books, widget.books) ||
        oldWidget.books.length != widget.books.length;
    if (listChanged) {
      final lane =
          _indexOf(_focusId) ?? _pose.focus.round().clamp(0, _lastSlot);
      _scheduleLaneSync(lane);
    }
    if (_pendingDelete != null &&
        !widget.books.any((book) => book.id == _pendingDelete!.id)) {
      // The parent removed the book while we waited.
      _pendingDelete = null;
      _deleteBusy = false;
    }
    if (_pose.grabbed != null && _pose.grabbed! > _lastSlot) _pose.endGrab();
  }

  @override
  void dispose() {
    _scroll?.removeListener(_scrolled);
    _scroll?.dispose();
    _entry.dispose();
    _pose.dispose();
    _active.dispose();
    super.dispose();
  }

  int? _indexOf(String? id) {
    if (id == null || id.isEmpty) return null;
    for (var i = 0; i < widget.books.length; i++) {
      if (widget.books[i].id == id) return i;
    }
    return null;
  }

  void _assemble() => _pose.present(_entry.value);

  void _finishEntrance() {
    if (!_entry.isCompleted) _entry.value = 1;
  }

  // ---------------------------------------------------------------- 滚动

  /// 把中心、窗口与格位计数对齐到当前滚动位置。
  void _syncFromOffset() {
    if (_scroll?.hasClients != true) return;
    _pose.move(_scroll!.offset / _pose.pitch);
    _syncWindow();
    final lane = _pose.focus.round().clamp(0, _lastSlot);
    if (_active.value != lane) {
      _active.value = lane;
      _focusId = widget.books[lane].id;
    }
  }

  void _scrolled() {
    if (_scroll?.hasClients != true) return;
    _syncFromOffset();
    final lane = _pose.focus.round().clamp(0, _lastSlot);
    // 一次手势里每进一个格位响一次；Flutter 自己会尊重系统的触感开关。
    final now =
        SchedulerBinding.instance.currentSystemFrameTimeStamp.inMilliseconds;
    if (_hapticGesture &&
        widget.books.length > 1 &&
        (_pose.focus - lane).abs() < .12 &&
        lane != _lastDetent &&
        now - _lastPulse >= 65) {
      _lastDetent = lane;
      _lastPulse = now;
      if (!_reduced) unawaited(HapticFeedback.selectionClick());
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _finishEntrance();
      _command++;
      _hapticGesture = true;
      _lastDetent = _pose.focus.round();
    } else if (notification is ScrollStartNotification) {
      _hapticGesture = true;
    } else if (notification is ScrollEndNotification) {
      _hapticGesture = false;
    }
    return false;
  }

  /// 窗口只在中心跨过一格时变化，滚动像素本身不会重建组件树。
  void _syncWindow() {
    if (!mounted) return;
    final window = _pose.window();
    if (window.first == _firstSlot && window.end == _endSlot) return;
    // 布局阶段滚动位置可能自己校正一次并触发回调，此时不能直接 setState。
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_windowSyncScheduled) return;
      _windowSyncScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _windowSyncScheduled = false;
        if (!mounted) return;
        _syncWindow();
      });
      return;
    }
    setState(() {
      _firstSlot = window.first;
      _endSlot = window.end;
    });
  }

  /// 把一个格位落到位：等这一帧布局完（行程也更新了）再跳。
  void _scheduleLaneSync(int lane) {
    _pendingLane = lane;
    if (_laneSyncScheduled) return;
    _laneSyncScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _laneSyncScheduled = false;
      if (!mounted) return;
      final target = _pendingLane;
      if (target == null) return;
      if (_scroll?.hasClients != true) {
        _scheduleLaneSync(target);
        return;
      }
      _pendingLane = null;
      final position = _scroll!.position;
      final pixels = (target * _pose.pitch).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - pixels).abs() > .5) _scroll!.jumpTo(pixels);
    });
  }

  // ---------------------------------------------------------------- 手势

  void _tap(int slot) {
    if (widget.selectable) {
      widget.onToggleSelect?.call(widget.books[slot]);
      return;
    }
    final settled =
        (_pose.focus - slot).abs() < .03 &&
        _scroll?.position.isScrollingNotifier.value == false;
    if (settled) {
      _open(slot);
    } else {
      unawaited(_centre(slot));
    }
  }

  Future<void> _centre(int slot) async {
    if (widget.books.length < 2 || _scroll?.hasClients != true) return;
    _finishEntrance();
    final command = ++_command;
    if (!_hapticGesture) _lastDetent = _pose.focus.round();
    _hapticGesture = true;
    final target = slot * _pose.pitch;
    if (_reduced) {
      _scroll!.jumpTo(target);
    } else {
      await _scroll!.animateTo(
        target,
        duration: _centreDuration,
        curve: _centreCurve,
      );
    }
    if (mounted && command == _command) _hapticGesture = false;
  }

  void _open(int slot) {
    _finishEntrance();
    _command++;
    _hapticGesture = false;
    final position = _scroll?.hasClients == true ? _scroll!.position : null;
    if (position is ScrollPositionWithSingleContext) position.goIdle();
    widget.onOpen(widget.books[slot]);
  }

  void _grabStart(int slot) {
    _pose.beginGrab(slot);
    if (!_reduced) unawaited(HapticFeedback.selectionClick());
  }

  void _grabMove(double dx) {
    final from = _pose.grabbed;
    if (from == null) return;
    final target = (from + (dx / _pose.pitch).round()).clamp(0, _lastSlot);
    final moved = target != _pose.dropTarget;
    _pose.updateGrab(dx, target);
    if (moved && !_reduced) unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _grabEnd() async {
    final from = _pose.grabbed;
    final to = _pose.dropTarget;
    _pose.endGrab();
    if (from == null || to == null || from == to) return;
    await widget.onReorder?.call(from, to);
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

  // ---------------------------------------------------------------- 构建

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) return const SizedBox.shrink();
    final palette = ShelfPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounded = constraints.hasBoundedHeight;
        final height = bounded ? constraints.maxHeight : 420.0;
        final metrics = ShelfMetrics.forSize(
          Size(constraints.maxWidth, height),
          metaHeight: _metaHeight,
        );
        _pose.configure(metrics.viewport, metrics.pitch);
        // 当前已处于 build，不需要 setState；首次构建、书目变化与视口变化
        // 都在这里把窗口对齐。
        final window = _pose.window();
        _firstSlot = window.first;
        _endSlot = window.end;
        _scroll ??= ScrollController(
          initialScrollOffset: _pose.focus * metrics.pitch,
          // 这条横向坐标轴属于书架自己，别让外层的 PageStorage 覆盖它。
          keepScrollOffset: false,
        )..addListener(_scrolled);

        // 行框 + 书名区组成一组，空间富余时整组居中。
        final slack = height - metrics.rowHeight - metrics.metaHeight;
        final top = slack > 0 ? slack / 2 : 0.0;
        final canvas = Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: top,
              height: metrics.rowHeight,
              child: _row(metrics, palette),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: math.min(
                top + metrics.rowHeight,
                math.max(0, height - metrics.metaHeight),
              ),
              height: metrics.metaHeight - 12,
              child: _meta(palette),
            ),
          ],
        );
        return bounded ? canvas : SizedBox(height: height, child: canvas);
      },
    );
  }

  Widget _row(ShelfMetrics metrics, ShelfPalette palette) {
    return NotificationListener<ScrollMetricsNotification>(
      // 行程或视口宽度变化时滚动位置会自己校正（校正本身不通知监听者），
      // 这里跟着把中心与窗口对齐，免得书名区停在上一个格位。
      onNotification: (_) {
        _syncFromOffset();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: ScrollConfiguration(
          // 3D 书架不该被拉伸或发光：越界反馈交给落位物理。
          behavior: ScrollConfiguration.of(
            context,
          ).copyWith(overscroll: false, scrollbars: false),
          child: Scrollable(
            key: const ValueKey('shelf-scroll'),
            controller: _scroll,
            axisDirection: AxisDirection.right,
            physics: widget.books.length < 2
                ? const NeverScrollableScrollPhysics()
                : ShelfSnapPhysics(pose: _pose),
            viewportBuilder: (context, offset) => ShelfScene(
              offset: offset,
              pose: _pose,
              metrics: metrics,
              firstSlot: _firstSlot,
              palette: palette,
              // 孩子按书自身 id 做键：整理页拖动排序后，元素与渲染对象跟着书走。
              children: [
                for (var slot = _firstSlot; slot < _endSlot; slot++)
                  _volume(slot, metrics, palette),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _volume(int slot, ShelfMetrics metrics, ShelfPalette palette) {
    final book = widget.books[slot];
    final reorderable = widget.onReorder != null;
    return ShelfVolume(
      key: ValueKey('shelf-book-${book.id}'),
      book: book,
      pose: _pose,
      slot: slot,
      metrics: metrics,
      palette: palette,
      picked: widget.selectedIds.contains(book.id),
      selectable: widget.selectable,
      onTap: () => _tap(slot),
      onGrabStart: reorderable ? () => _grabStart(slot) : null,
      onGrabMove: reorderable ? _grabMove : null,
      onGrabEnd: reorderable ? _grabEnd : null,
    );
  }

  /// 书名区：中心那本的名字、作者与进度，右端是格位计数与移除入口。
  Widget _meta(ShelfPalette palette) {
    return ValueListenableBuilder<int>(
      valueListenable: _active,
      builder: (context, lane, _) {
        final book = widget.books[lane.clamp(0, _lastSlot)];
        final pending = _pendingDelete;
        return FadeTransition(
          opacity: _metaFade,
          child: SlideTransition(
            position: _metaSlide,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.1,
              child: pending != null
                  ? _confirmRow(palette, pending)
                  : _metaLine(palette, book, lane),
            ),
          ),
        );
      },
    );
  }

  Widget _metaLine(ShelfPalette palette, ShelfBookView book, int lane) {
    final muted = palette.muted;
    final accent = palette.accent;
    final companion = palette.companion;
    final meta = book.progressLabel.isEmpty
        ? book.author
        : '${book.author.isEmpty ? '未知作者' : book.author} · '
              '${book.progressLabel}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.name,
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
              if (book.hasUpdate) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: companion,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '有更新',
                      style: TextStyle(fontSize: 10, color: companion),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (widget.onDelete != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 1),
            child: OutlinedButton(
              key: const ValueKey('shelf-remove'),
              onPressed: _deleteBusy
                  ? null
                  : () => setState(() => _pendingDelete = book),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(
                  color: AppColors.danger.withValues(alpha: .5),
                  width: .8,
                ),
                minimumSize: const Size(0, 26),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('移除'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 2),
          child: Text(
            '${(lane + 1).toString().padLeft(2, '0')} / '
            '${widget.books.length.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 10, letterSpacing: 1, color: muted),
          ),
        ),
      ],
    );
  }

  Widget _confirmRow(ShelfPalette palette, ShelfBookView book) {
    final muted = palette.muted;
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
