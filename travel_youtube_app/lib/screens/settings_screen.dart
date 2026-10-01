import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/error_view.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;

  Future<void> _editNickname(String currentNickname) async {
    final controller = TextEditingController(text: currentNickname);
    final newNickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('닉네임 수정'),
        content: TextField(
          key: const Key('editNicknameField'),
          controller: controller,
          decoration: const InputDecoration(hintText: '닉네임 입력'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('저장')),
        ],
      ),
    );

    if (newNickname == null || newNickname.trim().isEmpty || !mounted) return;
    if (newNickname.trim() == currentNickname) return;

    final ok = await context.read<AuthProvider>().updateNickname(newNickname.trim());
    if (!mounted) return;

    final message = ok ? '닉네임을 변경했어요.' : (context.read<AuthProvider>().errorMessage ?? '닉네임 변경에 실패했습니다.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openChangePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final newConfirmController = TextEditingController();
    String? inputError;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('비밀번호 변경'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('currentPasswordField'),
                controller: currentController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '현재 비밀번호'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('newPasswordField'),
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '새 비밀번호 (8자 이상)'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('newPasswordConfirmField'),
                controller: newConfirmController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '새 비밀번호 확인'),
              ),
              if (inputError != null) ...[
                const SizedBox(height: 8),
                Text(inputError!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            TextButton(
              onPressed: () {
                if (newController.text.length < 8) {
                  setDialogState(() => inputError = '새 비밀번호는 8자 이상 입력해 주세요.');
                  return;
                }
                if (newController.text != newConfirmController.text) {
                  setDialogState(() => inputError = '새 비밀번호가 일치하지 않아요.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('변경'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) return;

    final ok = await context.read<AuthProvider>().changePassword(
          currentPassword: currentController.text,
          newPassword: newController.text,
        );
    if (!mounted) return;

    final message = ok ? '비밀번호를 변경했어요.' : (context.read<AuthProvider>().errorMessage ?? '비밀번호 변경에 실패했습니다.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

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
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.surfaceTint2, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('계정 설정', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ],
              ),
            ),
            Expanded(
              child: user == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      children: [
                        const _SettingsSectionLabel('프로필'),
                        _SettingsRow(
                          label: '닉네임',
                          trailingText: user.nickname,
                          showChevron: true,
                          onTap: () => _editNickname(user.nickname),
                        ),
                        const SizedBox(height: 8),
                        _SettingsRow(label: '이메일', trailingText: user.email ?? '-'),
                        const _SettingsSectionLabel('로그인 및 보안'),
                        if (user.isKakaoAccount)
                          const _SettingsRow(label: '카카오 계정 연동', trailingText: '연동됨')
                        else ...[
                          _SettingsRow(
                            label: '비밀번호 변경',
                            showChevron: true,
                            onTap: _openChangePassword,
                          ),
                          const SizedBox(height: 8),
                          const _SettingsRow(label: '카카오 계정 연동', trailingText: '연동 안 됨'),
                        ],
                        const _SettingsSectionLabel('기타'),
                        _SettingsRow(
                          label: '이용약관 및 개인정보 처리방침',
                          showChevron: true,
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('이용약관 및 개인정보 처리방침'),
                              content: const Text('Voylog는 여행 브이로그 요약과 동선 계획을 위해 필요한 최소한의 정보만 수집·이용합니다.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SettingsRow(
                          label: '회원 탈퇴',
                          danger: true,
                          trailing: _isDeleting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : null,
                          onTap: _isDeleting ? null : _confirmDeleteAccount,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    this.trailingText,
    this.trailing,
    this.showChevron = false,
    this.danger = false,
    this.onTap,
  });

  final String label;
  final String? trailingText;
  final Widget? trailing;
  final bool showChevron;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.dividerStrong, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: danger ? AppColors.danger : AppColors.ink,
                ),
              ),
            ),
            if (trailingText != null)
              Text(trailingText!, style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted)),
            ?trailing,
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
            ],
          ],
        ),
      ),
    );
  }
}
