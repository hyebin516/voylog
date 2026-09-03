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

class SignupDetailsScreen extends StatefulWidget {
  final String email;

  const SignupDetailsScreen({super.key, required this.email});

  @override
  State<SignupDetailsScreen> createState() => _SignupDetailsScreenState();
}

class _SignupDetailsScreenState extends State<SignupDetailsScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  String? _inputError;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _onSignupPressed(AuthProvider authProvider) async {
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;
    final nickname = _nicknameController.text.trim();

    if (password.length < 8) {
      setState(() => _inputError = '비밀번호는 8자 이상 입력해 주세요.');
      return;
    }
    if (nickname.isEmpty) {
      setState(() => _inputError = '닉네임을 입력해 주세요.');
      return;
    }
    if (passwordConfirm != password) {
      setState(() => _inputError = '비밀번호가 일치하지 않아요.');
      return;
    }
    if (!_agreedToTerms) {
      setState(() => _inputError = '이용약관에 동의해 주세요.');
      return;
    }
    setState(() => _inputError = null);

    final success = await authProvider.signup(email: widget.email, password: password, nickname: nickname);
    if (!mounted) return;
    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
    }
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
                      Text('회원가입', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Text('마지막 단계예요', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(widget.email, style: textTheme.bodyMedium?.copyWith(color: AppColors.primary.withValues(alpha: 0.55))),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('signupPasswordField'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '비밀번호 (8자 이상)',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const Key('signupPasswordConfirmField'),
                    controller: _passwordConfirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '비밀번호 확인',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const Key('signupNicknameField'),
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      hintText: '닉네임',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  if (_inputError != null) InlineFieldError(message: _inputError!),
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    key: const Key('signupTermsCheckbox'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _agreedToTerms ? AppColors.accentCyan : AppColors.surfaceTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _agreedToTerms
                                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '이용약관 및 개인정보 처리방침에 동의합니다',
                              style: textTheme.bodySmall?.copyWith(color: AppColors.primary.withValues(alpha: 0.7)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: '회원가입 완료',
                    isLoading: authProvider.isLoading,
                    onPressed: () => _onSignupPressed(authProvider),
                  ),
                  if (authProvider.state == ViewState.error) ...[
                    const SizedBox(height: AppSpacing.md),
                    ErrorView(message: authProvider.errorMessage ?? '회원가입에 실패했습니다.'),
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
