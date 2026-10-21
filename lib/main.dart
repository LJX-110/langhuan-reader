import 'package:langhuan/app/bootstrap.dart';
import 'package:langhuan/design/brand/app_brand.dart';
import 'package:langhuan/app/router/routes.dart';
import 'package:langhuan/app/providers.dart';
import 'package:langhuan/app/shell/main_shell.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() => AppInit.init().then(
      (value) => runApp(const ProviderScope(child: MyApp())),
    );

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Cold-start: register the saved reader font with FontLoader + resolve path.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(colorModelProvider).ensureCurrentFontLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(colorModelProvider);
    return MaterialApp(
      title: AppBrand.name,
      home: const MainShell(),
      builder: BotToastInit(),
      navigatorObservers: [
        BotToastNavigatorObserver(),
      ],
      onGenerateRoute: Routes.router.generator,
      theme: model.theme,
    );
  }
}
