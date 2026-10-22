import 'package:langhuan/core/storage/prefs_keys.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:langhuan/features/sources/repo/source_repo.dart';
import 'package:langhuan/app/providers.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Private source repository: user supplies the URL, app ships nothing.
class SourceRepoPage extends ConsumerStatefulWidget {
  const SourceRepoPage({super.key});

  @override
  ConsumerState<SourceRepoPage> createState() => _SourceRepoPageState();
}

class _SourceRepoPageState extends ConsumerState<SourceRepoPage> {
  final _urlCtrl = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  String _savedName = '';
  String _lastSync = '';

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = SpUtil.getString(PrefsKeys.sourceRepoUrl, defValue: '');
    _savedName = SpUtil.getString(PrefsKeys.sourceRepoName, defValue: '');
    _lastSync = SpUtil.getString(PrefsKeys.sourceRepoLastSync, defValue: '');
    _agreed = SpUtil.getBool(PrefsKeys.sourceDisclaimerAgreed);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save({required bool sync}) async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      BotToast.showText(text: '请先填写仓库地址');
      return;
    }
    if (!_agreed) {
      BotToast.showText(text: '请先确认书源使用声明');
      return;
    }

    setState(() => _busy = true);
    try {
      if (!sync) {
        SpUtil.putString(PrefsKeys.sourceRepoUrl, url);
        BotToast.showText(text: '仓库地址已保存');
        return;
      }

      final fetched = await SourceRepo.fetch(url);
      final model = ref.read(sourceModelProvider);
      final count = await model.importParsed(
        fetched.parsed,
        agreed: true,
        silent: true,
      );
      await model.load();

      SpUtil.putString(PrefsKeys.sourceRepoUrl, url);
      SpUtil.putString(PrefsKeys.sourceRepoName, fetched.name);
      SpUtil.putString(
        PrefsKeys.sourceRepoLastSync,
        DateTime.now().toIso8601String(),
      );
      _savedName = fetched.name;
      _lastSync = SpUtil.getString(PrefsKeys.sourceRepoLastSync, defValue: '');

      BotToast.showText(text: '已同步「${fetched.name}」：$count 个书源');
    } catch (e) {
      BotToast.showText(text: '同步失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除仓库地址'),
        content: const Text('只清除本机保存的仓库地址，不会删除已导入的书源。'),
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

    SpUtil.remove(PrefsKeys.sourceRepoUrl);
    SpUtil.remove(PrefsKeys.sourceRepoName);
    SpUtil.remove(PrefsKeys.sourceRepoLastSync);
    _urlCtrl.clear();
    if (mounted) {
      setState(() {
        _savedName = '';
        _lastSync = '';
      });
    }
  }

  String get _lastSyncLabel {
    if (_lastSync.isEmpty) return '尚未同步';
    final parsed = DateTime.tryParse(_lastSync);
    if (parsed == null) return _lastSync;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(sourceModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('私有书源仓库')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Text(
            '应用不内置、不提供任何书源。这里只保存你自己的仓库地址，'
            '同步时由你主动触发。',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '仓库 JSON 地址',
              hintText: 'https://example.com/sources.json',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '我确认该仓库由我本人维护，书源内容与使用责任由我承担',
              style: TextStyle(fontSize: 13),
            ),
            value: _agreed,
            onChanged: (v) {
              setState(() => _agreed = v ?? false);
              SpUtil.putBool(PrefsKeys.sourceDisclaimerAgreed, _agreed);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _save(sync: true),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(_busy ? '同步中…' : '保存并同步'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _save(sync: false),
                child: const Text('仅保存'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _savedName.isEmpty ? '未配置仓库' : _savedName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('上次同步：$_lastSyncLabel'),
                  const SizedBox(height: 4),
                  Text('本机书源：${model.sources.length} 个'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '仓库格式：Legado 书源数组，或 '
            '{"name":"…","version":"…","sources":[…]}。'
            '应用不会自动联网更新，也不会内置任何默认地址。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _busy ? null : _clear,
            icon: const Icon(Icons.delete_outline),
            label: const Text('清除仓库地址'),
          ),
        ],
      ),
    );
  }
}
