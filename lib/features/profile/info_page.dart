import 'package:langhuan/app/version_label.dart';
import 'package:langhuan/core/storage/local_store.dart';
import 'package:flutter/material.dart';
import 'package:langhuan/core/storage/prefs_keys.dart';

/// Local static notices (no network).
class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return InfoState();
  }
}

class InfoState extends State<InfoPage> {
  @override
  Widget build(BuildContext context) {
    final version = versionDisplayLabel(
      SpUtil.getString(PrefsKeys.version, defValue: ''),
    );
    return Scaffold(
      appBar: AppBar(title: Text("公告"), centerTitle: true, elevation: 0),
      body: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Text(
                  '本地书源模式',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(height: 12),
              Text(
                '请在「书源管理」自行导入书源 JSON。\n\n'
                '请勿导入或使用侵犯他人版权的书源。',
                textAlign: TextAlign.start,
                style: TextStyle(height: 1.5),
              ),
              Spacer(),
              Row(
                children: <Widget>[
                  Expanded(child: Container()),
                  Text(
                    '$version · ${DateUtil.getNowDateStr()}',
                    textAlign: TextAlign.start,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
