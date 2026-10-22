import 'package:langhuan/design/components/pic_widget.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/data/entities/book.dart';
import 'package:flutter/material.dart';

class HasUpdateIconImg extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  final bool sorting;
  final bool picked;

  const HasUpdateIconImg({
    super.key,
    required this.book,
    required this.width,
    required this.height,
    this.sorting = false,
    this.picked = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PicWidget(book.coverUrl, height: height, width: width),
          ),
          if (book.hasUpdate == 1)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppColors.updateBadge,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
                child: const Text(
                  '更新',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          if (sorting)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: picked ? accent : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: picked ? accent : Colors.white70,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: picked
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
