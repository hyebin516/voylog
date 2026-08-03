import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('앱 이름'),
            trailing: Text('여행 유튜브 요약'),
          ),
          ListTile(
            leading: Icon(Icons.numbers_rounded),
            title: Text('버전'),
            trailing: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}
