import 'dart:async';

import 'package:langhuan/core/events/event.dart';
import 'package:langhuan/features/shelf/book_shelf.dart';
import 'package:langhuan/features/discover/explore_page.dart';
import 'package:langhuan/features/profile/me_page.dart';
import 'package:flutter/material.dart';

import 'glass_dock.dart';

/// App root shell: 书架 / 发现 / 我.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  StreamSubscription<NavEvent>? _navSub;

  @override
  void initState() {
    super.initState();
    _navSub = eventBus.on<NavEvent>().listen((e) {
      final i = e.idx.clamp(0, 2);
      if (mounted && i != _index) {
        setState(() => _index = i);
      }
    });
  }

  @override
  void dispose() {
    _navSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          BookShelf(),
          const ExplorePage(),
          Me(embedded: true),
        ],
      ),
      bottomNavigationBar: LanhuanDock(
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
