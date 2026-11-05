import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/sources/engine/native_engine.dart';
import 'package:langhuan/features/sources/engine/native_engine_bridge.dart';

/// 「原生引擎（实验）」开关行（我的 → 其他）。
///
/// 自持状态（[Me] 是无状态页）；开启前先探活 MethodChannel，
/// 未接入通道的旧包会给出提示并保持关闭。
class NativeEngineSwitchRow extends StatefulWidget {
  const NativeEngineSwitchRow({super.key, required this.line});

  final Color line;

  @override
  State<NativeEngineSwitchRow> createState() => _NativeEngineSwitchRowState();
}

class _NativeEngineSwitchRowState extends State<NativeEngineSwitchRow> {
  bool _value = NativeEngineBridge.enabled;

  Future<void> _toggle(bool value) async {
    if (!value) {
      SpUtil.putBool(PrefsKeys.nativeEngineEnabled, false);
      setState(() => _value = false);
      return;
    }
    final ok = await NativeEngine.ping();
    if (!ok) {
      BotToast.showText(text: '当前安装包未接入原生引擎通道');
      return;
    }
    SpUtil.putBool(PrefsKeys.nativeEngineEnabled, true);
    setState(() => _value = true);
    BotToast.showText(text: '已开启：详情 / 目录 / 正文优先走原生引擎');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggle(!_value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '原生引擎（实验）',
                      style: TextStyle(
                        fontSize: 15,
                        color: primary,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Switch.adaptive(value: _value, onChanged: _toggle),
                ],
              ),
            ),
          ),
        ),
        Divider(height: .5, color: widget.line),
      ],
    );
  }
}
