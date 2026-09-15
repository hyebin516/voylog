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

/// Step 1 of the forgot-password flow: enter the account email to receive
/// a 6-digit OTP (reuses the same email OTP infrastructure as signup).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? _inputError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSendCodePressed(AuthProvider authProvider) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _inputError = '이메일을 입력해 주세요.');
      return;
    }
    setState(() => _inputError = null);

    final success = await authProvider.requestPasswordResetOtp(email);
    if (!mounted || !success) return;

    final verified = await Navigator.pushNamed<bool>(context, AppRoutes.passwordResetOtp, arguments: email);
    if (!mounted || verified != true) return;

    Navigator.pushReplacementNamed(context, AppRoutes.resetPassword, arguments: email);
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
                      Text('비밀번호 찾기', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('가입한 이메일을 입력해 주세요', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '인증코드를 보내드릴게요',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.primary.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('forgotPasswordEmailField'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: '이메일',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  if (_inputError != null) InlineFieldError(message: _inputError!),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: '인증코드 받기',
                    isLoading: authProvider.isLoading,
                    onPressed: () => _onSendCodePressed(authProvider),
                  ),
                  if (authProvider.state == ViewState.error) ...[
                    const SizedBox(height: AppSpacing.md),
                    ErrorView(message: authProvider.errorMessage ?? '요청에 실패했습니다.'),
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
