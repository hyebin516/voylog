import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../services/legal_document_launcher.dart';
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

  // 동의 문구의 약관·방침을 눌러 열기 위한 것. TapGestureRecognizer는
  // 직접 dispose해야 한다.
  final _legal = const LegalDocumentLauncher();
  late final TapGestureRecognizer _termsTap =
      TapGestureRecognizer()..onTap = () => _openLegalDocument(_legal.openTermsOfService);
  late final TapGestureRecognizer _privacyTap =
      TapGestureRecognizer()..onTap = () => _openLegalDocument(_legal.openPrivacyPolicy);
  String? _verifiedEmail;
  String? _checkedNickname;
  bool? _nicknameAvailable;
  String? _nicknameCheckError;
  String? _rejectedNickname;
  String? _rejectedEmail;
  bool _isCheckingNickname = false;

  bool get _emailVerified => _verifiedEmail != null && _verifiedEmail == _emailController.text.trim();

  bool get _nicknameConfirmedAvailable =>
      _nicknameAvailable == true && _checkedNickname == _nicknameController.text.trim();

  /// What to say under the email field, if anything: that it is verified,
  /// or that it is already registered.
  (String, InlineFieldTone)? _emailFieldMessage(AuthProvider authProvider) {
    if (_emailVerified) return ('인증된 이메일이에요', InlineFieldTone.success);
    if (_rejectedEmail == null || _rejectedEmail != _emailController.text.trim()) {
      return null;
    }
    return (authProvider.errorMessage ?? '이미 가입된 이메일입니다.', InlineFieldTone.error);
  }

  /// The signup call's own rejection of the nickname, which can happen even
  /// after a clean duplicate check: someone else may take the name between
  /// the check and the submit.
  String? _submitNicknameError(AuthProvider authProvider) {
    if (_rejectedNickname == null || _rejectedNickname != _nicknameController.text.trim()) {
      return null;
    }
    return authProvider.errorMessage ?? '이미 사용 중인 닉네임입니다.';
  }

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
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  /// 문서는 서버가 서빙하므로 열리지 않을 수 있다. 조용히 넘어가면
  /// 글자가 고장난 것처럼 보이므로 이유를 알린다.
  Future<void> _openLegalDocument(Future<bool> Function() open) async {
    final opened = await open();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문서를 열지 못했습니다. 네트워크를 확인해 주세요.')),
      );
    }
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
    if (!mounted) return;
    if (!success) {
      setState(() {
        _rejectedEmail = authProvider.errorCode == 'EMAIL_EXISTS' ? email : null;
      });
      return;
    }

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
      return;
    }
    setState(() {
      // Pin the rejection to the value it was about: without this the
      // message outlives the text it refers to and sits there accusing a
      // nickname the user has already changed.
      if (authProvider.errorCode == 'NICKNAME_EXISTS') _rejectedNickname = nickname;
      if (authProvider.errorCode == 'EMAIL_EXISTS') _rejectedEmail = email;
    });
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
                  // nothing at all. A rejection from the signup call itself
                  // wins, since it is the newer verdict.
                  if (_submitNicknameError(authProvider) != null)
                    InlineFieldError(message: _submitNicknameError(authProvider)!)
                  else if (_nicknameCheckMessage != null)
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
                  if (_emailFieldMessage(authProvider) case (final message, final tone)?)
                    InlineFieldError(message: message, tone: tone),
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
                          // 동의를 받으려면 무엇에 동의하는지 열어볼 수
                          // 있어야 한다. 체크박스만 두고 내용을 못 보게
                          // 하면 받은 동의가 의미를 잃는다.
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '[필수] ',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '이용약관',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: _termsTap,
                                  ),
                                  TextSpan(
                                    text: ' 및 ',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '개인정보처리방침',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: _privacyTap,
                                  ),
                                  TextSpan(
                                    text: '에 동의합니다',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
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
                  // Anything a field already reports stays with that field.
                  if (authProvider.state == ViewState.error &&
                      authProvider.errorCode != 'NICKNAME_EXISTS' &&
                      authProvider.errorCode != 'EMAIL_EXISTS') ...[
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
