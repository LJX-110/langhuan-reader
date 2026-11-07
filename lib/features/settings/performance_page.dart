import 'package:flutter/material.dart';

import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';

/// 低性能模式：关闭书架入场动画与封面预取，保留主题、排版与阅读体验。
/// 切换后从下一次进入书架开始生效。
class PerformancePage extends StatefulWidget {
  const PerformancePage({super.key});

  @override
  State<PerformancePage> createState() => _PerformancePageState();
}

class _PerformancePageState extends State<PerformancePage> {
  late bool _enabled = SpUtil.getBool(PrefsKeys.lowPerformance);

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await SpUtil.putBool(PrefsKeys.lowPerformance, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('低性能模式'), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('低性能模式'),
              subtitle: const Text('关闭书架入场动画与封面预取，减少低端机卡顿'),
              value: _enabled,
              onChanged: _toggle,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '不影响：12 套主题、阅读排版、分页、书源与下载。\n'
            '切换后下一次进入书架生效。',
            style: TextStyle(fontSize: 12, height: 1.7, color: muted),
          ),
        ],
      ),
    );
  }
}
