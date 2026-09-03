import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/app_card.dart';
import '../widgets/error_view.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('회원 탈퇴 시 계정 정보와 북마크, 호텔, 동선 기록에 더 이상 접근할 수 없습니다.\n계속하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('탈퇴')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final success = await context.read<AuthProvider>().deleteAccount();
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    } else {
      final message = context.read<AuthProvider>().errorMessage ?? '회원 탈퇴에 실패했습니다.';
      showErrorDialog(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded, color: AppColors.primary),
                  title: Text('앱 이름'),
                  trailing: Text('Voylog'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const ListTile(
                  leading: Icon(Icons.numbers_rounded, color: AppColors.primary),
                  title: Text('버전'),
                  trailing: Text('1.0.0'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                  title: const Text('알림 설정'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.notificationSettings),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: AppColors.coral),
              title: const Text('회원 탈퇴', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w600)),
              trailing: _isDeleting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: _isDeleting ? null : _confirmDeleteAccount,
            ),
          ),
        ],
      ),
    );
  }
}
