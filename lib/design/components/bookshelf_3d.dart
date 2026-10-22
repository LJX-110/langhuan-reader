import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:langhuan/data/entities/search_item.dart';
import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

/// A compact 3D shelf: books stand on a hairline, the centred one faces the
/// reader, neighbours turn away with perspective. Visual reference only; the
/// interaction is a plain [PageView] with snapping.
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
    _controller = PageController(viewportFraction: .42, initialPage: 0);
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
    final primary = dark ? AppColors.textOnDark : AppColors.textPrimary;
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
    final item = widget.books[_index.clamp(0, widget.books.length - 1)];

    return SizedBox(
      height: 212,
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
                    onPageChanged: (i) => setState(() => _index = i),
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
                          color: primary,
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
        final angle = delta * .55;
        final scale = 1.0 - math.min(delta.abs() * .12, .24);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(0, delta.abs() * 5),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .0014)
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.min(144.0, constraints.maxHeight - 10);
        final width = height * .75;
        return SizedBox(
          width: width,
          height: height + 10,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: width - 12,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0x14141414),
                  borderRadius: BorderRadius.all(Radius.elliptical(48, 5)),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24141414),
                      blurRadius: 12,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          border: Border(
                            right: BorderSide(
                              color: Theme.of(context).colorScheme.secondary,
                              width: .5,
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
                                fontSize: 7,
                                height: 1,
                                letterSpacing: .4,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: PicWidget(
                          item.coverUrl,
                          width: width - 14,
                          height: height,
                          radius: 0,
                        ),
                      ),
                      Container(
                        width: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8E8E8),
                          border: Border(
                            left: BorderSide(
                              color: Color(0xFFDADADA),
                              width: .5,
                            ),
                          ),
                        ),
                      ),
                    ],
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
