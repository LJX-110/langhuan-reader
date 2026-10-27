import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/components/shelf_book_view.dart';
import 'package:langhuan/design/components/shelf_geometry.dart';
import 'package:langhuan/design/components/shelf_palette.dart';
import 'package:langhuan/design/components/shelf_pose.dart';
import 'package:langhuan/design/components/shelf_scene.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// 一本书：书脊 + 封面 + 顶面，三块共享同一批顶点。
///
/// 书身在自己的局部坐标里是静止的；抽出行程、行内弧线与入场位移都由
/// [ShelfScene] 在绘制时加进来，所以滚动与拖动排序不会重建这棵子树。
class ShelfVolume extends StatelessWidget {
  const ShelfVolume({
    super.key,
    required this.book,
    required this.pose,
    required this.slot,
    required this.metrics,
    required this.palette,
    required this.picked,
    required this.selectable,
    required this.onTap,
    this.onGrabStart,
    this.onGrabMove,
    this.onGrabEnd,
  });

  final ShelfBookView book;
  final ShelfPose pose;
  final int slot;
  final ShelfMetrics metrics;
  final ShelfPalette palette;

  /// 整理页里已勾选。
  final bool picked;
  final bool selectable;

  final VoidCallback onTap;
  final VoidCallback? onGrabStart;
  final ValueChanged<double>? onGrabMove;
  final VoidCallback? onGrabEnd;

  @override
  Widget build(BuildContext context) {
    return _VolumeBody(
      pose: pose,
      slot: slot,
      spec: ShelfVolumeSpec(
        metrics: metrics,
        palette: palette,
        selected: picked,
        label: _semanticLabel(book, picked),
        hint: _hint(),
        textDirection: Directionality.of(context),
        onTap: onTap,
        onGrabStart: onGrabStart,
        onGrabMove: onGrabMove,
        onGrabEnd: onGrabEnd,
      ),
      children: [
        _CoverPanel(
          book: book,
          pose: pose,
          slot: slot,
          metrics: metrics,
          palette: palette,
          code: _code(slot + 1),
          selectable: selectable,
          picked: picked,
        ),
        _SpinePanel(
          book: book,
          palette: palette,
          code: _code(slot + 1),
          selected: selectable && picked,
        ),
      ],
    );
  }

  String _hint() {
    if (selectable) return '点按选择';
    return onGrabStart == null ? '点按阅读' : '点按阅读，长按可拖动排序';
  }

  static String _semanticLabel(ShelfBookView book, bool picked) {
    final author = book.author.isEmpty ? '未知作者' : book.author;
    final progress = book.progressLabel.isEmpty ? '' : '，${book.progressLabel}';
    return '《${book.name}》，$author$progress${picked ? '，已选择' : ''}';
  }

  static String _code(int number) => number.toString().padLeft(2, '0');
}

class _VolumeBody extends MultiChildRenderObjectWidget {
  const _VolumeBody({
    required this.pose,
    required this.slot,
    required this.spec,
    required super.children,
  });

  final ShelfPose pose;
  final int slot;
  final ShelfVolumeSpec spec;

  @override
  ShelfVolumeRender createRenderObject(BuildContext context) =>
      ShelfVolumeRender._(pose, slot, spec);

  @override
  void updateRenderObject(BuildContext context, ShelfVolumeRender renderObject) {
    renderObject.update(pose: pose, slot: slot, spec: spec);
  }
}

/// 一本书与渲染有关的一切输入；整体比较，改一处就重画一处。
@immutable
class ShelfVolumeSpec {
  const ShelfVolumeSpec({
    required this.metrics,
    required this.palette,
    required this.selected,
    required this.label,
    required this.hint,
    required this.textDirection,
    required this.onTap,
    this.onGrabStart,
    this.onGrabMove,
    this.onGrabEnd,
  });

  final ShelfMetrics metrics;
  final ShelfPalette palette;
  final bool selected;
  final String label;
  final String hint;
  final TextDirection textDirection;
  final VoidCallback onTap;
  final VoidCallback? onGrabStart;
  final ValueChanged<double>? onGrabMove;
  final VoidCallback? onGrabEnd;

  @override
  bool operator ==(Object other) =>
      other is ShelfVolumeSpec &&
      other.metrics == metrics &&
      other.palette == palette &&
      other.selected == selected &&
      other.label == label &&
      other.hint == hint &&
      other.textDirection == textDirection &&
      other.onTap == onTap &&
      other.onGrabStart == onGrabStart &&
      other.onGrabMove == onGrabMove &&
      other.onGrabEnd == onGrabEnd;

  @override
  int get hashCode => Object.hash(
    metrics,
    palette,
    selected,
    label,
    hint,
    textDirection,
    onTap,
    onGrabStart,
    onGrabMove,
    onGrabEnd,
  );
}

/// 一本书的渲染对象：封面、顶面、书脊按固定顺序画在同一个局部坐标里。
///
/// 局部坐标就是「静止的书」的投影包围盒，所以命中测试是一条确定的路径，
/// 邻书压过来时也不会互相抢手势。
class ShelfVolumeRender extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, ShelfSlotParentData> {
  ShelfVolumeRender._(this._pose, this._slot, this._spec)
    : _grabbed = _pose.grabbed == _slot {
    _tap = TapGestureRecognizer(debugOwner: this)..onTap = () => _spec.onTap();
    _longPress = LongPressGestureRecognizer(debugOwner: this)
      ..onLongPressStart = (_) {
        _spec.onGrabStart?.call();
      }
      ..onLongPressMoveUpdate = (details) {
        _spec.onGrabMove?.call(details.offsetFromOrigin.dx);
      }
      ..onLongPressEnd = (_) {
        _spec.onGrabEnd?.call();
      };
    _applyMetrics(_spec.metrics);
  }

  ShelfPose _pose;
  int _slot;
  ShelfVolumeSpec _spec;
  bool _grabbed;

  late final TapGestureRecognizer _tap;
  late final LongPressGestureRecognizer _longPress;

  final LayerHandle<TransformLayer> _coverLayer = LayerHandle<TransformLayer>();
  final LayerHandle<TransformLayer> _spineLayer = LayerHandle<TransformLayer>();

  double _spineW = 0;
  double _coverW = 0;
  double _height = 0;
  double _topInset = 0;
  Matrix4 _spineMatrix = Matrix4.identity();
  Matrix4 _coverMatrix = Matrix4.identity();
  late Path _spinePath;
  late Path _coverPath;
  late Path _topPath;
  late Path _solidPath;
  int debugLayoutCount = 0;
  double get debugOpenFraction => _pose.weightAt(_slot);
  bool get debugGrabbed => _grabbed;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ShelfSlotParentData) {
      child.parentData = ShelfSlotParentData();
    }
  }

  void update({
    required ShelfPose pose,
    required int slot,
    required ShelfVolumeSpec spec,
  }) {
    if (_pose != pose) {
      if (attached) _pose.removeListener(_poseChanged);
      _pose = pose;
      if (attached) _pose.addListener(_poseChanged);
    }
    _slot = slot;
    if (_spec == spec) return;
    final previous = _spec;
    _spec = spec;
    if (previous.palette != spec.palette || previous.selected != spec.selected) {
      markNeedsPaint();
    }
    if (previous.selected != spec.selected ||
        previous.label != spec.label ||
        previous.hint != spec.hint) {
      markNeedsSemanticsUpdate();
    }
    _applyMetrics(spec.metrics);
  }

  void _poseChanged() {
    final grabbed = _pose.grabbed == _slot;
    if (grabbed == _grabbed) return;
    _grabbed = grabbed;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _pose.addListener(_poseChanged);
  }

  @override
  void detach() {
    _pose.removeListener(_poseChanged);
    _coverLayer.layer = null;
    _spineLayer.layer = null;
    super.detach();
  }

  /// 书脊、封面、顶面共享同一批顶点：尺寸一变就一次性重算。
  void _applyMetrics(ShelfMetrics metrics) {
    if (_spineW == metrics.spineW &&
        _coverW == metrics.coverW &&
        _height == metrics.bodyH) {
      return;
    }
    _spineW = metrics.spineW;
    _coverW = metrics.coverW;
    _height = metrics.bodyH;
    _topInset = metrics.topInset;

    final shear = ShelfGeometry.spineShear;
    final spineTop = Offset(0, _topInset);
    final spineTopRight = Offset(_spineW, _topInset + _spineW * shear);
    final depth = Offset(
      _coverW * ShelfGeometry.depthX,
      _coverW * ShelfGeometry.depthY,
    );

    _spineMatrix = Matrix4.identity()
      ..setEntry(1, 0, shear)
      ..setEntry(1, 3, _topInset);
    _coverMatrix = Matrix4.identity()
      ..setEntry(0, 0, ShelfGeometry.depthX)
      ..setEntry(1, 0, ShelfGeometry.depthY)
      ..setEntry(0, 3, spineTopRight.dx)
      ..setEntry(1, 3, spineTopRight.dy);

    _spinePath = Path()
      ..addPolygon([
        spineTop,
        spineTopRight,
        spineTopRight + Offset(0, _height),
        spineTop + Offset(0, _height),
      ], true);
    _coverPath = Path()
      ..addPolygon([
        spineTopRight,
        spineTopRight + depth,
        spineTopRight + depth + Offset(0, _height),
        spineTopRight + Offset(0, _height),
      ], true);
    _topPath = Path()
      ..addPolygon([spineTop, spineTopRight, spineTopRight + depth, spineTop + depth], true);
    _solidPath = Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, _spinePath, _coverPath),
      _topPath,
    );
    markNeedsLayout();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    firstChild!.layout(BoxConstraints.tight(Size(_coverW, _height)));
    lastChild!.layout(BoxConstraints.tight(Size(_spineW, _height)));
    debugLayoutCount++;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_grabbed) {
      // 抓取反馈：整本书离地，投影跟着甩开一点。
      context.canvas.drawShadow(
        _solidPath.shift(offset + const Offset(0, 5)),
        Colors.black,
        7,
        false,
      );
    }
    _coverLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _coverMatrix,
      (context, offset) => context.paintChild(firstChild!, offset),
      oldLayer: _coverLayer.layer,
    );
    _paintTopFace(context.canvas, offset);
    _spineLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _spineMatrix,
      (context, offset) => context.paintChild(lastChild!, offset),
      oldLayer: _spineLayer.layer,
    );
  }

  /// 顶面：纸的暗面到亮面，选中时换成辅助色描边并淡淡染色。
  void _paintTopFace(Canvas canvas, Offset offset) {
    final path = _topPath.shift(offset);
    final palette = _spec.palette;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [palette.paperDeep, palette.paper],
        ).createShader(path.getBounds()),
    );
    if (_spec.selected) {
      canvas.drawPath(
        path,
        Paint()..color = palette.companion.withValues(alpha: .22),
      );
    }
    // 顶面的轮廓用墨色收边：白底上细灰线会糊掉，黑底上又需要一点亮边。
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _spec.selected ? 1.2 : .6
        ..color = _spec.selected
            ? palette.companion
            : palette.ink.withValues(alpha: .26),
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // 一格宽就是这本书的全部命中区：相邻格首尾相接、互不重叠，所以点在哪本书
    // 的格上就落到哪本书；封面画出格外的部分只负责画，不抢邻居的手势。
    if (!size.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is! PointerDownEvent) return;
    _tap.addPointer(event);
    if (_spec.onGrabStart != null) _longPress.addPointer(event);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.isButton = true;
    config.isSelected = _spec.selected;
    config.label = _spec.label;
    config.hint = _spec.hint;
    config.textDirection = _spec.textDirection;
    config.onTap = _spec.onTap;
  }

  @override
  Rect get paintBounds => semanticBounds;

  @override
  Rect get semanticBounds => _solidPath.getBounds();

  @override
  void dispose() {
    _tap.dispose();
    _longPress.dispose();
    _coverLayer.layer = null;
    _spineLayer.layer = null;
    super.dispose();
  }
}

/// 书脊：主题强调色的一条，竖排书名 + 格位编号 + 更新点。
class _SpinePanel extends StatelessWidget {
  const _SpinePanel({
    required this.book,
    required this.palette,
    required this.code,
    required this.selected,
  });

  final ShelfBookView book;
  final ShelfPalette palette;
  final String code;

  /// 整理页里已勾选：书脊底端换成实心方块。
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ink = palette.onAccent;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.alphaBlend(Colors.black.withValues(alpha: .24), palette.accent),
            palette.accent,
            Color.alphaBlend(Colors.white.withValues(alpha: .14), palette.accent),
          ],
        ),
      ),
      // 书脊只有十几像素宽：字号固定，跟随系统字号会让它溢出。
      child: MediaQuery.withNoTextScaling(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 9),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 8.5,
                    height: 1.2,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                    color: ink.withValues(alpha: .78),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: Text(
                    _verticalTitle(book.name),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.08,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // 书脊底端的小标记：整理页选中时是一个实心方块 —— 书脊永远是
              // 看得见的那一条，勾选状态必须落在这里才不会丢。
              Container(
                width: selected ? 6 : 5,
                height: selected ? 6 : 5,
                decoration: BoxDecoration(
                  color: selected
                      ? palette.companion
                      : (book.hasUpdate
                            ? palette.companion
                            : ink.withValues(alpha: .40)),
                  shape: selected ? BoxShape.rectangle : BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 竖排标题：一行一个字，过长收成省略号，最多七行。
  static String _verticalTitle(String name) {
    final glyphs = name.characters.toList();
    final kept = glyphs.take(7).toList();
    return [...kept, if (glyphs.length > 7) '…'].join('\n');
  }
}

/// 封面：档案栏位的纸面 + 真封面图 + 作者行。
class _CoverPanel extends StatelessWidget {
  const _CoverPanel({
    required this.book,
    required this.pose,
    required this.slot,
    required this.metrics,
    required this.palette,
    required this.code,
    required this.selectable,
    required this.picked,
  });

  final ShelfBookView book;
  final ShelfPose pose;
  final int slot;
  final ShelfMetrics metrics;
  final ShelfPalette palette;
  final String code;
  final bool selectable;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final muted = palette.muted;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.paper,
        border: Border.all(color: palette.line, width: .5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
        child: MediaQuery.withNoTextScaling(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.2,
                    letterSpacing: 1.05,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: metrics.coverImageW,
                    height: metrics.coverImageH,
                    child: _CoverWindow(
                      pose: pose,
                      slot: slot,
                      builder: (near) => near
                          ? PicWidget(
                              book.coverUrl,
                              width: metrics.coverImageW,
                              height: metrics.coverImageH,
                              radius: 0,
                              referer: book.referer,
                              title: book.name,
                            )
                          : const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      book.author.isEmpty ? '未知作者' : book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 9, height: 1.3, color: muted),
                    ),
                  ),
                  if (selectable) _SelectionMark(picked: picked),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 封面窗口：只有中心一本与它的左右邻挂真图。
///
/// 窗口跟着中心走，越界的书立刻退回纸面，所以一次最多三张封面在网络与
/// 内存里；跨越格位时只重建这一小块，不惊动整排书。
class _CoverWindow extends StatefulWidget {
  const _CoverWindow({
    required this.pose,
    required this.slot,
    required this.builder,
  });

  final ShelfPose pose;
  final int slot;
  final Widget Function(bool near) builder;

  @override
  State<_CoverWindow> createState() => _CoverWindowState();
}

class _CoverWindowState extends State<_CoverWindow> {
  /// 中心两侧各一本。
  static const int _reach = 1;

  late bool _near = _isNear();

  bool _isNear() => (widget.slot - widget.pose.focus.round()).abs() <= _reach;

  @override
  void initState() {
    super.initState();
    widget.pose.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _CoverWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose != widget.pose) {
      oldWidget.pose.removeListener(_changed);
      widget.pose.addListener(_changed);
    }
    _near = _isNear();
  }

  @override
  void dispose() {
    widget.pose.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final near = _isNear();
    if (near == _near) return;
    setState(() => _near = near);
  }

  @override
  Widget build(BuildContext context) => widget.builder(_near);
}

/// 整理页的选中标记：封面栏位右端一个小方格。
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.picked});

  final bool picked;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Container(
      width: 13,
      height: 13,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: picked ? accent : Colors.transparent,
        border: Border.all(
          color: picked ? accent : AppColors.companionOf(context),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: picked
          ? Icon(Icons.check, size: 9, color: AppColors.onColorOf(accent))
          : null,
    );
  }
}
