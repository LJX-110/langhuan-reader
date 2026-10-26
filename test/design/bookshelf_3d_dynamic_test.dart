import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langhuan/design/components/bookshelf_3d.dart';
import 'package:langhuan/design/components/shelf_book_view.dart';
import 'package:langhuan/design/tokens/app_colors.dart';

List<ShelfBookView> _books(int count) {
  return List.generate(
    count,
    (i) => ShelfBookView(
      id: 'b$i',
      name: '书名 ${i + 1}',
      author: '作者 ${i + 1}',
      coverUrl: '',
    ),
  );
}

class _ShelfHost extends StatefulWidget {
  const _ShelfHost({
    required this.initial,
    this.initialFocus,
    this.onOpen,
    this.onDelete,
    this.onToggleSelect,
    this.onReorder,
    super.key,
  });

  final List<ShelfBookView> initial;
  final String? initialFocus;
  final ValueChanged<ShelfBookView>? onOpen;
  final Future<void> Function(ShelfBookView)? onDelete;
  final ValueChanged<ShelfBookView>? onToggleSelect;
  final Future<void> Function(int, int)? onReorder;

  @override
  State<_ShelfHost> createState() => _ShelfHostState();
}

class _ShelfHostState extends State<_ShelfHost> {
  late List<ShelfBookView> _items = List.of(widget.initial);

  void replace(List<ShelfBookView> items) {
    setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLanghuanTheme(dark: false),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 640,
            child: Bookshelf3D(
              books: _items,
              initialBookId: widget.initialFocus,
              onOpen: widget.onOpen ?? (_) {},
              onDelete: widget.onDelete,
              selectable: widget.onToggleSelect != null,
              onToggleSelect: widget.onToggleSelect,
              onReorder: widget.onReorder,
            ),
          ),
        ),
      ),
    );
  }
}

Future<_ShelfHostState> _pumpHost(
  WidgetTester tester, {
  required List<ShelfBookView> initial,
  String? initialFocus,
  ValueChanged<ShelfBookView>? onOpen,
  Future<void> Function(ShelfBookView)? onDelete,
  ValueChanged<ShelfBookView>? onToggleSelect,
  Future<void> Function(int, int)? onReorder,
}) async {
  final key = GlobalKey<_ShelfHostState>();
  await tester.pumpWidget(
    _ShelfHost(
      key: key,
      initial: initial,
      initialFocus: initialFocus,
      onOpen: onOpen,
      onDelete: onDelete,
      onToggleSelect: onToggleSelect,
      onReorder: onReorder,
    ),
  );
  await tester.pump();
  return key.currentState!;
}

void main() {
  testWidgets('initial focus lands on the requested book', (tester) async {
    await _pumpHost(tester, initial: _books(5), initialFocus: 'b2');

    expect(find.text('03 / 05'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('growing the list keeps the focused book', (tester) async {
    final host = await _pumpHost(
      tester,
      initial: _books(5),
      initialFocus: 'b2',
    );
    expect(find.text('03 / 05'), findsOneWidget);

    host.replace(_books(8));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('03 / 08'), findsOneWidget);
  });

  testWidgets('shrinking past the focused book clamps to the last book', (
    tester,
  ) async {
    final host = await _pumpHost(
      tester,
      initial: _books(5),
      initialFocus: 'b2',
    );

    host.replace(_books(2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('02 / 02'), findsOneWidget);
  });

  testWidgets('clearing and restoring the list rebuilds the shelf', (
    tester,
  ) async {
    final host = await _pumpHost(tester, initial: _books(3));

    host.replace(const []);
    await tester.pumpAndSettle();
    expect(find.textContaining('书名'), findsNothing);

    host.replace(_books(3));
    await tester.pumpAndSettle();
    expect(find.text('01 / 03'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the focused book opens it', (tester) async {
    final opened = <String>[];
    await _pumpHost(
      tester,
      initial: _books(5),
      initialFocus: 'b2',
      onOpen: (book) => opened.add(book.id),
    );

    await tester.tap(find.byKey(const ValueKey('shelf-book-b2')));
    await tester.pumpAndSettle();

    expect(opened, ['b2']);
  });

  testWidgets('tapping a side book re-centres instead of opening', (
    tester,
  ) async {
    final opened = <String>[];
    await _pumpHost(
      tester,
      initial: _books(5),
      initialFocus: 'b2',
      onOpen: (book) => opened.add(book.id),
    );

    await tester.tap(find.byKey(const ValueKey('shelf-book-b3')));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(find.text('04 / 05'), findsOneWidget);
  });

  testWidgets('delete asks inline and cancel keeps the book', (tester) async {
    var deletes = 0;
    await _pumpHost(
      tester,
      initial: _books(3),
      initialFocus: 'b1',
      onDelete: (_) async => deletes++,
    );

    await tester.tap(find.byKey(const ValueKey('shelf-remove')));
    await tester.pump();
    expect(find.text('移除《书名 2》？'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shelf-delete-cancel')));
    await tester.pump();
    expect(find.text('移除《书名 2》？'), findsNothing);
    expect(deletes, 0);
  });

  testWidgets('confirming delete calls the callback exactly once', (
    tester,
  ) async {
    var deletes = 0;
    await _pumpHost(
      tester,
      initial: _books(3),
      initialFocus: 'b1',
      onDelete: (_) async => deletes++,
    );

    await tester.tap(find.byKey(const ValueKey('shelf-remove')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shelf-delete-confirm')));
    await tester.pumpAndSettle();

    expect(deletes, 1);
    expect(find.text('移除《书名 2》？'), findsNothing);
  });

  testWidgets('no remove button without an onDelete callback', (tester) async {
    await _pumpHost(tester, initial: _books(2));
    expect(find.byKey(const ValueKey('shelf-remove')), findsNothing);
  });

  testWidgets('selectable mode toggles selection instead of opening', (
    tester,
  ) async {
    final picked = <String>[];
    final opened = <String>[];
    await _pumpHost(
      tester,
      initial: _books(3),
      onToggleSelect: (book) => picked.add(book.id),
      onOpen: (book) => opened.add(book.id),
    );

    await tester.tap(find.byKey(const ValueKey('shelf-book-b0')));
    await tester.pump();

    expect(picked, ['b0']);
    expect(opened, isEmpty);
  });

  testWidgets('long-press drag reports a reorder', (tester) async {
    final reorders = <(int, int)>[];
    await _pumpHost(
      tester,
      initial: _books(5),
      initialFocus: 'b2',
      onReorder: (from, to) async => reorders.add((from, to)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('shelf-book-b2'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(reorders, isNotEmpty);
    expect(reorders.first.$1, 2);
    expect(reorders.first.$2, greaterThan(2));
  });

  testWidgets('shelf fits a narrow screen with large text', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLanghuanTheme(dark: false),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: Bookshelf3D(
            books: _books(5),
            onOpen: (_) {},
            onDelete: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('shelf-remove')), findsOneWidget);
  });
}
