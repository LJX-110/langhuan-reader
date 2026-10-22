import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// A compact 3D shelf: books stand on a hairline, the centred one faces the
/// reader, neighbours turn away with perspective. Each volume has a spine,
/// a page edge and a top face so it reads as a solid, not a flat card.
class Bookshelf3D extends StatefulWidget {
  const Bookshelf3D({super.key, required this.books, required this.onOpen});

  final List<SearchItem> books;
  final ValueChanged<SearchItem> onOpen;

  @override
  State<Bookshelf3D> createState() => _Bookshelf3DState();
}

class _Bookshelf3DState extends State<Bookshelf3D> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = 0;
    _controller = PageController(viewportFraction: .40, initialPage: 0);
  }

  @override
  void didUpdateWidget(covariant Bookshelf3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.books.length != oldWidget.books.length &&
        widget.books.isNotEmpty) {
      _index = _index.clamp(0, widget.books.length - 1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = dark ? AppColors.dividerDark : AppColors.line;
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
    final accent = AppColors.accentOf(context);
    final item = widget.books[_index.clamp(0, widget.books.length - 1)];

    return SizedBox(
      height: 252,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 13,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      color: line,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12141414),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  bottom: 13,
                  child: PageView.builder(
                    controller: _controller,
                    clipBehavior: Clip.none,
                    physics: const PageScrollPhysics(),
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = i);
                    },
                    itemCount: widget.books.length,
                    itemBuilder: (context, i) {
                      return _ShelfBook(
                        item: widget.books[i],
                        controller: _controller,
                        index: i,
                        onTap: () {
                          if (i == _index) {
                            widget.onOpen(widget.books[i]);
                          } else {
                            _controller.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.author.isEmpty ? '未知作者' : item.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '上一本',
                  visualDensity: VisualDensity.compact,
                  onPressed: _index == 0
                      ? null
                      : () => _controller.previousPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                        ),
                  icon: Icon(Icons.chevron_left, size: 19, color: muted),
                ),
                Text(
                  '${(_index + 1).toString().padLeft(2, '0')} / ${widget.books.length.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: muted,
                  ),
                ),
                IconButton(
                  tooltip: '下一本',
                  visualDensity: VisualDensity.compact,
                  onPressed: _index >= widget.books.length - 1
                      ? null
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                        ),
                  icon: Icon(Icons.chevron_right, size: 19, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfBook extends StatelessWidget {
  const _ShelfBook({
    required this.item,
    required this.controller,
    required this.index,
    required this.onTap,
  });

  final SearchItem item;
  final PageController controller;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final page = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();
        final delta = (index - page).clamp(-2.0, 2.0).toDouble();
        final angle = delta * .62;
        final scale = 1.0 - math.min(delta.abs() * .14, .30);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, delta.abs() * 8),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .0016)
                  ..rotateY(angle),
                child: child,
              ),
            ),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _BookCard(item: item),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.item});

  final SearchItem item;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppColors.accentOf(context);
    final companion = AppColors.companionOf(context);
    final onAccent = AppColors.onColorOf(accent);
    final topFace = dark ? const Color(0xFF2C2C2C) : const Color(0xFFEFEDE6);
    final topEdge = dark ? const Color(0xFF3D3D3D) : const Color(0xFFD8D4C8);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = math.max(0.0, constraints.maxHeight - 18);
        final maxW = math.max(0.0, constraints.maxWidth - 10);
        var height = math.min(178.0, maxH);
        var width = height * .74;
        if (width > maxW) {
          width = maxW;
          height = width / .74;
        }
        const top = 8.0;

        return SizedBox(
          width: width + 10,
          height: height + top + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 10,
                right: 0,
                bottom: 0,
                height: 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: dark ? .30 : .10),
                    borderRadius: const BorderRadius.all(
                      Radius.elliptical(80, 7),
                    ),
                  ),
                ),
              ),
              // Top face: the block of pages seen from slightly above.
              Positioned(
                left: 14,
                top: 0,
                width: math.max(0.0, width - 4),
                height: top,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [topEdge, topFace],
                    ),
                    border: Border.all(color: topEdge, width: .5),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                top: top,
                width: width,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2A141414),
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2.5),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color.alphaBlend(
                                  Colors.black.withValues(alpha: .24),
                                  accent,
                                ),
                                accent,
                                Color.alphaBlend(
                                  Colors.white.withValues(alpha: .14),
                                  accent,
                                ),
                              ],
                            ),
                            border: Border(
                              right: BorderSide(
                                color: companion.withValues(alpha: .75),
                                width: .8,
                              ),
                            ),
                          ),
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Center(
                              child: Text(
                                item.name,
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
                        ),
                        Expanded(
                          child: PicWidget(
                            item.coverUrl,
                            width: width - 17,
                            height: height,
                            radius: 0,
                          ),
                        ),
                        SizedBox(
                          width: 5,
                          height: height,
                          child: CustomPaint(painter: _PageEdgePainter(dark)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Hairline stack on the fore-edge so the volume reads as paper, not a slab.
class _PageEdgePainter extends CustomPainter {
  const _PageEdgePainter(this.dark);

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = dark ? const Color(0xFFD6D1C4) : const Color(0xFFF7F4EC),
    );
    final line = Paint()
      ..color = const Color(0x22141414)
      ..strokeWidth = .5;
    for (var y = 2.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _PageEdgePainter oldDelegate) =>
      oldDelegate.dark != dark;
}
