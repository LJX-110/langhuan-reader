import 'package:langhuan/common/common.dart';
import 'package:langhuan/common/local_store.dart';

/// Reader chrome prefs: menu visibility and left-tap advance.
class ReaderChromeController {
  ReaderChromeController({
    required this.notify,
  });

  final void Function() notify;

  bool showMenu = false;

  bool tapLeftToAdvance =
      SpUtil.getBool(PrefsKeys.leftClickNext, defValue: false);

  void toggleShowMenu() {
    showMenu = !showMenu;
    notify();
  }

  void toggleTapLeftToAdvance() {
    tapLeftToAdvance = !tapLeftToAdvance;
    SpUtil.putBool(PrefsKeys.leftClickNext, tapLeftToAdvance);
    notify();
  }
}
