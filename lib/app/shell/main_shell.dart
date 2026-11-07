import 'dart:async';

import 'package:langhuan/core/events/event.dart';
import 'package:langhuan/core/platform/system_ui.dart';
import 'package:langhuan/features/settings/update_service.dart';
import 'package:langhuan/features/shelf/book_shelf.dart';
import 'package:langhuan/features/discover/explore_page.dart';
import 'package:langhuan/features/local/local_page.dart';
import 'package:langhuan/features/profile/me_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_dock.dart';
import 'package:langhuan/design/components/feedback.dart';

/// App root shell: 书架 / 发现 / 本地 / 我.
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
      final i = e.idx.clamp(0, 3);
      if (mounted && i != _index) {
        setState(() => _index = i);
      }
    });
    // Silent startup check: 24h throttle, failures ignored, non-blocking hint.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    try {
      final info = await UpdateService().check();
      if (info == null || !mounted) return;
      showFeedback('发现新版本 ${info.version}，可在「我的」页查看');
    } catch (_) {
      // Silent: the manual entry in 我的 reports errors instead.
    }
  }

  @override
  void dispose() {
    _navSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiHelper.overlayStyle(context),
      child: Scaffold(
        // 懒构建：首次进入某标签才创建该页（避免启动时 4 页全建、
        // 发现页本地页的初始化抢占书架首屏）。
        body: _LazyIndexedStack(
          index: _index,
          builders: [
            () => BookShelf(),
            () => const ExplorePage(),
            () => const LocalPage(),
            () => Me(embedded: true),
          ],
        ),
        // 轻小说文库式悬浮胶囊：居中、底部留白（槽位细节与坑见 DockBar）。
        bottomNavigationBar: DockBar(
          index: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

/// 懒加载版 IndexedStack：未访问过的标签页不构建；
/// 一旦构建保持存活（页面状态不丢，切回不重建）。
class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({required this.index, required this.builders});

  final int index;
  final List<Widget Function()> builders;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<Widget?> _built = List<Widget?>.filled(
    widget.builders.length,
    null,
  );

  @override
  Widget build(BuildContext context) {
    _built[widget.index] ??= widget.builders[widget.index]();
    return IndexedStack(
      index: widget.index,
      children: [for (final child in _built) child ?? const SizedBox.shrink()],
    );
  }
}
