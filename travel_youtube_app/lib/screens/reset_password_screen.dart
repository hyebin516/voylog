import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/error_view.dart';
import '../widgets/inline_field_error.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';

/// Step 3 (final) of the forgot-password flow: set a new password once the
/// email OTP has been verified.
class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  String? _inputError;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _onSubmitPressed(AuthProvider authProvider) async {
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    if (password.length < 8) {
      setState(() => _inputError = '비밀번호는 8자 이상 입력해 주세요.');
      return;
    }
    if (passwordConfirm != password) {
      setState(() => _inputError = '비밀번호가 일치하지 않아요.');
      return;
    }
    setState(() => _inputError = null);

    final success = await authProvider.resetPassword(email: widget.email, newPassword: password);
    if (!mounted || !success) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('비밀번호가 변경됐어요'),
        content: const Text('새 비밀번호로 다시 로그인해 주세요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('확인')),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AuthBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            child: ResponsiveCenter(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 40, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const AuthBackButton(),
                      const SizedBox(width: AppSpacing.sm),
                      Text('새 비밀번호 설정', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('새 비밀번호를 입력해 주세요', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '8자 이상으로 설정해 주세요',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.primary.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('resetPasswordField'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '새 비밀번호',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const Key('resetPasswordConfirmField'),
                    controller: _passwordConfirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '새 비밀번호 확인',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  if (_inputError != null) InlineFieldError(message: _inputError!),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: '비밀번호 변경',
                    isLoading: authProvider.isLoading,
                    onPressed: () => _onSubmitPressed(authProvider),
                  ),
                  if (authProvider.state == ViewState.error) ...[
                    const SizedBox(height: AppSpacing.md),
                    ErrorView(message: authProvider.errorMessage ?? '비밀번호 변경에 실패했습니다.'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
