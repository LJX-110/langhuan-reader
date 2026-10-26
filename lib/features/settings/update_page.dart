import 'package:flutter/material.dart';
import 'package:langhuan/design/tokens/app_colors.dart';
import 'package:langhuan/features/settings/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// 检查更新：检查 GitHub Releases，打开对应发布页（不在应用内下载/安装）。
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key, this.service});

  /// Test hook; production uses the default GitHub-backed service.
  final UpdateService? service;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  late final UpdateService _service = widget.service ?? UpdateService();

  bool _checking = true;
  UpdateInfo? _info;
  String _local = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _checking = true;
      _error = '';
    });
    final local = await _service.localVersion();
    try {
      final info = await _service.check(force: true);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _local = local;
        _info = info;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _local = local;
        _error = '检查失败，请检查网络后重试。';
      });
    }
  }

  Future<void> _openRelease(UpdateInfo info) async {
    final uri = Uri.tryParse(info.pageUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开浏览器，请手动访问发布页')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.textOnDark : AppColors.ink;
    final muted = dark ? AppColors.textMutedDark : AppColors.inkMute;
    final accent = AppColors.accentOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('检查更新')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            _local.isEmpty ? '当前版本' : '当前版本 $_local',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 16),
          if (_checking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error.isNotEmpty) ...[
            Text(_error, style: TextStyle(fontSize: 13, color: primary)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _run,
                child: const Text('重试'),
              ),
            ),
          ] else if (_info == null)
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  '已是最新版本',
                  style: TextStyle(fontSize: 14, color: primary),
                ),
              ],
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: AppColors.companionOf(context).withValues(alpha: .45),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '发现新版本 ${_info!.version}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  if (_info!.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: SingleChildScrollView(
                        child: Text(
                          _info!.notes.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: muted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openRelease(_info!),
                child: const Text('前往下载'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '将打开浏览器中的发布页，由你自行下载安装。',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
