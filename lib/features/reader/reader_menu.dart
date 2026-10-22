import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:langhuan/app/providers.dart';
import 'package:langhuan/core/events/event.dart';
import 'package:langhuan/design/theme/color_model.dart';
import 'package:langhuan/features/reader/menu/reader_bottom_bar.dart';
import 'package:langhuan/features/reader/menu/reader_chapter_panel.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/menu/reader_download_panel.dart';
import 'package:langhuan/features/reader/menu/reader_settings_panel.dart';
import 'package:langhuan/features/reader/menu/reader_top_bar.dart';
import 'package:langhuan/features/reader/read_model.dart';
import 'package:langhuan/features/reader/settings/read_setting.dart';

/// Reader chrome overlay: top bar plus a bottom panel whose content switches
/// between chapters, settings, layout and download.
class ReaderMenu extends ConsumerStatefulWidget {
  const ReaderMenu({super.key});

  @override
  ConsumerState<ReaderMenu> createState() => _MenuState();
}

enum Type { SLIDE, MORE_SETTING, DOWNLOAD, LAYOUT }

class _MenuState extends ConsumerState<ReaderMenu> {
  Type type = Type.SLIDE;
  late ReadModel _readModel;
  late ColorModel _colorModel;

  @override
  void initState() {
    super.initState();
    _readModel = ref.read(readModelProvider);
    _colorModel = ref.read(colorModelProvider);
  }

  /// Match reader paper so chrome doesn't clash with the page underneath.
  ReaderChrome get _chrome => ReaderChrome(_readModel.paperTheme);

  Widget _bottomHead(ReaderChrome chrome) {
    switch (type) {
      case Type.MORE_SETTING:
        return ReaderSettingsPanel(
          readModel: _readModel,
          colorModel: _colorModel,
          chrome: chrome,
          onChanged: () => setState(() {}),
          onOpenLayout: () => setState(() => type = Type.LAYOUT),
        );
      case Type.LAYOUT:
        return ReaderLayoutPanel(
          readModel: _readModel,
          chrome: chrome,
          onChanged: () => setState(() {}),
          onBack: () => setState(() => type = Type.MORE_SETTING),
        );
      case Type.DOWNLOAD:
        return ReaderDownloadPanel(readModel: _readModel, chrome: chrome);
      default:
        return ReaderChapterPanel(
          readModel: _readModel,
          chrome: chrome,
          onChanged: () => setState(() {}),
        );
    }
  }

  void _dismissMenu() {
    type = Type.SLIDE;
    if (_readModel.showMenu) {
      _readModel.toggleShowMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when theme or reader chrome-relevant fields change.
    _colorModel = ref.watch(colorModelProvider);
    ref.watch(
      readModelProvider.select(
        (m) => (
          m.book?.chapterIndex,
          m.book?.name,
          m.tapLeftToAdvance,
          m.paperTheme,
          m.currentAnimationMode,
          m.chapters.length,
        ),
      ),
    );
    _readModel = ref.read(readModelProvider);

    final chrome = _chrome;
    final isNight = _colorModel.dark;

    // Full-screen stack: dimmed/tap-to-dismiss layer under chrome, so the
    // blank reading area always closes the menu (including when settings is open).
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Catch taps on the reading area.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissMenu,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          // Top chrome
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ReaderTopBar(readModel: _readModel, chrome: chrome),
          ),
          // Bottom panel (settings / chapter / download)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: chrome.panelBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x1A000000),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 2),
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: chrome.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      _bottomHead(chrome),
                      Divider(height: 1, color: chrome.divider),
                      ReaderBottomBar(
                        chrome: chrome,
                        night: isNight,
                        downloadActive: type == Type.DOWNLOAD,
                        settingsActive: type == Type.MORE_SETTING,
                        onChapters: () {
                          eventBus.fire(OpenChapters('dd'));
                          _readModel.toggleShowMenu();
                        },
                        onToggleNight: () async {
                          ref.read(colorModelProvider).switchModel();
                          final night = ref.read(colorModelProvider).dark;
                          await _readModel.setPaperTheme(
                            night ? PaperTheme.night : PaperTheme.cream,
                          );
                          setState(() {});
                        },
                        onDownload: () {
                          setState(() {
                            type = type == Type.DOWNLOAD
                                ? Type.SLIDE
                                : Type.DOWNLOAD;
                          });
                        },
                        onSettings: () {
                          setState(() {
                            type = type == Type.MORE_SETTING
                                ? Type.SLIDE
                                : Type.MORE_SETTING;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
