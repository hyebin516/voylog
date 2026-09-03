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

class SignupOtpScreen extends StatefulWidget {
  final String email;

  const SignupOtpScreen({super.key, required this.email});

  @override
  State<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends State<SignupOtpScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _inputError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onVerifyPressed(AuthProvider authProvider) async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _inputError = '6자리 인증번호를 입력해 주세요.');
      return;
    }
    setState(() => _inputError = null);

    final success = await authProvider.verifySignupOtp(widget.email, code);
    if (!mounted) return;
    if (success) {
      Navigator.pushNamed(context, AppRoutes.signupDetails, arguments: widget.email);
    }
  }

  Future<void> _onResendPressed(AuthProvider authProvider) async {
    await authProvider.requestSignupOtp(widget.email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인증번호를 다시 보냈어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final textTheme = Theme.of(context).textTheme;
    final code = _codeController.text;

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
                      Text('이메일 인증', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppColors.softShadow(opacity: 0.18, blurRadius: 18, offset: const Offset(0, 8)),
                    ),
                    child: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('인증코드를 보냈어요', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.email}\n으로 전송된 6자리 코드를 입력해주세요',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.primary.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) {
                          final filled = i < code.length;
                          return Container(
                            width: 44,
                            height: 52,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceTint,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: filled ? AppColors.accentCyan : AppColors.surfaceSoft,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              filled ? code[i] : '',
                              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          );
                        }),
                      ),
                      Opacity(
                        opacity: 0,
                        child: TextField(
                          key: const Key('signupOtpField'),
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(counterText: ''),
                        ),
                      ),
                    ],
                  ),
                  if (_inputError != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Center(child: InlineFieldError(message: _inputError!)),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('코드를 못 받으셨나요?', style: textTheme.bodySmall?.copyWith(color: AppColors.primary.withValues(alpha: 0.45))),
                      TextButton(
                        onPressed: authProvider.isLoading ? null : () => _onResendPressed(authProvider),
                        child: const Text('재전송'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: '인증하기',
                    isLoading: authProvider.isLoading,
                    onPressed: () => _onVerifyPressed(authProvider),
                  ),
                  if (authProvider.state == ViewState.error) ...[
                    const SizedBox(height: AppSpacing.md),
                    ErrorView(message: authProvider.errorMessage ?? '인증에 실패했습니다.'),
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
