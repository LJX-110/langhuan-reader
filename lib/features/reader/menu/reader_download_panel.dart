import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';

import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/data/repositories/chapter_repository.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/reader/menu/reader_chrome.dart';
import 'package:langhuan/features/reader/model/download_center.dart';
import 'package:langhuan/features/reader/read_model.dart';

/// 缓存面板：离线下载的队列状态、暂停 / 继续、失败重试、清除缓存与
/// 「仅 WiFi」。机制对齐 Wenku8 的离线下载：一次跑一本书、暂停保留进度、
/// 重试只补缺的章节、清缓存不动书架与阅读进度。
class ReaderDownloadPanel extends StatefulWidget {
  const ReaderDownloadPanel({
    super.key,
    required this.readModel,
    required this.chrome,
  });

  final ReadModel readModel;
  final ReaderChrome chrome;

  @override
  State<ReaderDownloadPanel> createState() => _ReaderDownloadPanelState();
}

class _ReaderDownloadPanelState extends State<ReaderDownloadPanel> {
  final DownloadCenter _center = DownloadCenter.instance;

  ({int total, int withBody})? _stats;
  bool _lastActive = false;

  String? get _bookId => widget.readModel.book?.id;

  BookDownload? get _job {
    final id = _bookId;
    return id == null ? null : _center.jobOf(id);
  }

  @override
  void initState() {
    super.initState();
    _center.addListener(_onCenterChanged);
    _reloadStats();
  }

  @override
  void dispose() {
    _center.removeListener(_onCenterChanged);
    super.dispose();
  }

  void _onCenterChanged() {
    if (!mounted) return;
    final active = _job?.active ?? false;
    // 状态行被任务占用时不查库；任务结束后再刷新一次统计。
    if (active || _lastActive) _reloadStats();
    _lastActive = active;
    setState(() {});
  }

  Future<void> _reloadStats() async {
    final id = _bookId;
    if (id == null) return;
    final stats = await ChapterRepository.instance.bodyStats(id);
    if (!mounted || _bookId != id) return;
    setState(() => _stats = stats);
  }

  bool get _wifiOnly {
    try {
      return SpUtil.getBool(PrefsKeys.downloadWifiOnly, defValue: false);
    } catch (_) {
      return false;
    }
  }

  Future<void> _startDownload({required bool fromCurrent}) async {
    final model = widget.readModel;
    final book = model.book;
    if (book == null) return;
    if (model.chapters.isEmpty) {
      BotToast.showText(text: '目录还没加载，稍后再试');
      return;
    }
    final start = fromCurrent
        ? book.chapterIndex.clamp(0, model.chapters.length - 1)
        : 0;
    await model.downloadAll(start);
    if (mounted) _reloadStats();
  }

  Future<void> _clearCache() async {
    final model = widget.readModel;
    final book = model.book;
    if (book == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: Text('删除《${book.name}》已缓存的章节正文？\n书架、阅读进度与书签都会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await model.clearDownloadCache();
    if (mounted) _reloadStats();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    final job = _job;
    final activeJob = (job != null && job.active) ? job : null;
    final resumableJob = (job != null && job.resumable) ? job : null;
    final stats = _stats;
    final hasCache = (stats?.withBody ?? 0) > 0 || job != null;

    final statsLine = stats == null
        ? '正在读取缓存状态…'
        : stats.total == 0
        ? '目录还没加载'
        : '缓存 ${stats.withBody} / ${stats.total} 章';
    // 有任务就显示任务状态（对齐文库：完成 / 暂停 / 失败都有明确文案），
    // 没任务时才退回「缓存 n / N 章」。
    final statusText = job?.label ?? statsLine;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            statusText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: chrome.muted),
          ),
          if (activeJob != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: activeJob.total > 0
                    ? activeJob.completed / activeJob.total
                    : null,
                minHeight: 3,
                backgroundColor: chrome.divider,
                color: AppColors.accentOf(context),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: activeJob != null
                    ? _actionBtn(
                        '暂停下载',
                        () => _center.pause(activeJob.bookId),
                      )
                    : resumableJob != null
                    ? _actionBtn(
                        '继续下载',
                        () => _center.resume(resumableJob.bookId),
                      )
                    : _actionBtn(
                        '从当前缓存',
                        () => _startDownload(fromCurrent: true),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionBtn(
                  '全本缓存',
                  activeJob != null
                      ? null
                      : () => _startDownload(fromCurrent: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              TextButton(
                onPressed: hasCache ? _clearCache : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  '清除本缓存',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasCache
                        ? AppColors.danger
                        : chrome.muted.withValues(alpha: .6),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '仅 WiFi',
                style: TextStyle(fontSize: 12, color: chrome.fg),
              ),
              SizedBox(
                height: 30,
                child: Switch.adaptive(
                  value: _wifiOnly,
                  activeTrackColor: AppColors.accentOn(context, chrome.panelBg),
                  onChanged: (value) {
                    SpUtil.putBool(PrefsKeys.downloadWifiOnly, value);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback? onTap) {
    final chrome = widget.chrome;
    final enabled = onTap != null;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? chrome.fg : chrome.muted.withValues(alpha: .5),
        side: BorderSide(color: chrome.divider),
        backgroundColor: chrome.chipBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.symmetric(vertical: 11),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
