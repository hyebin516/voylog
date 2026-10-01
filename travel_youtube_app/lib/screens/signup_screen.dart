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

/// Single-screen signup (design handoff's `isSignup`) -- nickname (with an
/// inline "중복확인" duplicate-check), email (verified inline via a push to
/// [SignupOtpScreen] that pops back with the verified flag), password,
/// password confirm and terms all live on one screen.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();

  String? _inputError;
  bool _agreedToTerms = false;
  String? _verifiedEmail;
  String? _checkedNickname;
  bool? _nicknameAvailable;
  String? _nicknameCheckError;
  bool _isCheckingNickname = false;

  bool get _emailVerified => _verifiedEmail != null && _verifiedEmail == _emailController.text.trim();

  bool get _nicknameConfirmedAvailable =>
      _nicknameAvailable == true && _checkedNickname == _nicknameController.text.trim();

  /// What the last duplicate check found, or null when none has run for the
  /// nickname currently typed (editing it clears the verdict).
  String? get _nicknameCheckMessage {
    if (_checkedNickname == null || _checkedNickname != _nicknameController.text.trim()) {
      return null;
    }
    return switch (_nicknameAvailable) {
      true => '사용할 수 있는 닉네임이에요',
      false => '이미 사용 중인 닉네임이에요. 다른 닉네임을 입력해주세요',
      // The request itself failed -- saying "available" would be a lie and
      // saying "taken" would be too, so it says neither.
      null => _nicknameCheckError ?? '닉네임을 확인하지 못했어요. 잠시 후 다시 시도해 주세요',
    };
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _onCheckNicknamePressed(AuthProvider authProvider) async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() => _inputError = '닉네임을 입력해 주세요.');
      return;
    }
    setState(() {
      _inputError = null;
      _isCheckingNickname = true;
    });

    final available = await authProvider.checkNicknameAvailable(nickname);
    if (!mounted) return;
    setState(() {
      _isCheckingNickname = false;
      _checkedNickname = nickname;
      _nicknameAvailable = available;
      _nicknameCheckError = available == null ? authProvider.errorMessage : null;
    });
  }

  Future<void> _onVerifyEmailPressed(AuthProvider authProvider) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _inputError = '이메일을 입력해 주세요.');
      return;
    }
    setState(() => _inputError = null);

    final success = await authProvider.requestSignupOtp(email);
    if (!mounted || !success) return;

    final verified = await Navigator.pushNamed<bool>(context, AppRoutes.signupOtp, arguments: email);
    if (!mounted || verified != true) return;
    setState(() => _verifiedEmail = email);
  }

  Future<void> _onSignupPressed(AuthProvider authProvider) async {
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    if (nickname.isEmpty) {
      setState(() => _inputError = '닉네임을 입력해 주세요.');
      return;
    }
    if (!_nicknameConfirmedAvailable) {
      setState(() => _inputError = '닉네임 중복 확인을 해주세요.');
      return;
    }
    if (!_emailVerified) {
      setState(() => _inputError = '이메일 인증을 완료해 주세요.');
      return;
    }
    if (password.length < 8) {
      setState(() => _inputError = '비밀번호는 8자 이상 입력해 주세요.');
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

    final success = await authProvider.signup(email: email, password: password, nickname: nickname);
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
                  Text('시작해볼까요?', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'AI가 동선을 저장하려면 계정이 필요해요',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.primary.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('signupNicknameField'),
                          controller: _nicknameController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: '닉네임',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _nicknameConfirmedAvailable
                          ? const SizedBox(
                              height: 52,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.check_circle_rounded, color: AppColors.accentCyan),
                              ),
                            )
                          : OutlinedButton(
                              key: const Key('checkNicknameButton'),
                              onPressed: (_isCheckingNickname || authProvider.isLoading)
                                  ? null
                                  : () => _onCheckNicknamePressed(authProvider),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                              child: const Text('중복확인'),
                            ),
                    ],
                  ),
                  // Every outcome says something. Before, only "taken"
                  // did, so a free nickname looked like the button had done
                  // nothing at all.
                  if (_nicknameCheckMessage != null)
                    InlineFieldError(
                      message: _nicknameCheckMessage!,
                      tone: _nicknameAvailable == true
                          ? InlineFieldTone.success
                          : InlineFieldTone.error,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('signupEmailField'),
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_emailVerified,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: '이메일',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _emailVerified
                          ? const SizedBox(
                              height: 52,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.check_circle_rounded, color: AppColors.accentCyan),
                              ),
                            )
                          : OutlinedButton(
                              onPressed: authProvider.isLoading ? null : () => _onVerifyEmailPressed(authProvider),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                              child: const Text('인증하기'),
                            ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const Key('signupPasswordField'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '비밀번호',
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
                    label: '가입하기',
                    isLoading: authProvider.isLoading,
                    onPressed: () => _onSignupPressed(authProvider),
                  ),
                  if (authProvider.state == ViewState.error) ...[
                    const SizedBox(height: AppSpacing.md),
                    ErrorView(message: authProvider.errorMessage ?? '회원가입에 실패했습니다.'),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '이미 계정이 있으신가요?',
                        style: textTheme.bodySmall?.copyWith(color: AppColors.primary.withValues(alpha: 0.45)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false),
                        child: const Text('로그인'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
