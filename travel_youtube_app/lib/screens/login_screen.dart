import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../services/kakao_auth_service.dart';
import '../utils/view_state.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/error_view.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';
import '../widgets/voylog_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onEmailLoginPressed(AuthProvider authProvider) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    await authProvider.loginWithEmail(email, password);
    if (!mounted || authProvider.state != ViewState.error) return;

    // A dialog, the same way a failed Kakao login already reports. The
    // message used to sit under the form, where a wrong password looked
    // like part of the page rather than an answer to the button just
    // pressed.
    await showErrorDialog(context, authProvider.errorMessage ?? '로그인에 실패했습니다.');
  }

  Future<void> _onKakaoLoginPressed(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();

    String kakaoAccessToken;
    try {
      kakaoAccessToken = await KakaoAuthService.login();
    } on KakaoClientException catch (e) {
      if (e.reason == ClientErrorCause.cancelled) return; // user backed out
      if (context.mounted) await showErrorDialog(context, '카카오 로그인에 실패했습니다.');
      return;
    } catch (e) {
      // The reason (a Kakao auth error, a platform hand-off failure) is only
      // useful to us, never to the user, who gets one plain message.
      debugPrint('Kakao login failed: $e');
      if (context.mounted) await showErrorDialog(context, '카카오 로그인에 실패했습니다.');
      return;
    }

    if (!context.mounted) return;
    await authProvider.loginWithKakao(kakaoAccessToken);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final textTheme = Theme.of(context).textTheme;

    if (authProvider.state == ViewState.success && authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    }

    return Scaffold(
      body: AuthBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: ResponsiveCenter(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 48, AppSpacing.lg, AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  const Row(
                    children: [
                      VoylogLogoMark(),
                      SizedBox(width: AppSpacing.sm),
                      VoylogWordmark(),
                    ],
                  ),
                  const SizedBox(height: 52),
                  Text('반가워요!', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('로그인하고 일정을 이어가요', style: textTheme.bodyMedium?.copyWith(color: AppColors.primary.withValues(alpha: 0.55))),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    key: const Key('loginEmailField'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: '이메일',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    key: const Key('loginPasswordField'),
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '비밀번호',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textMuted, padding: EdgeInsets.zero),
                      child: const Text('비밀번호를 잊으셨나요?'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: '로그인',
                    isLoading: authProvider.isLoading,
                    onPressed: () => _onEmailLoginPressed(authProvider),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: authProvider.isLoading ? null : () => _onKakaoLoginPressed(context),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                      label: const Text('카카오로 3초만에 로그인'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE500),
                        foregroundColor: const Color(0xFF3A2B1A),
                        side: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.dividerStrong),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('비회원으로 둘러보기'),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Voylog가 처음이신가요?', style: textTheme.bodySmall?.copyWith(color: AppColors.primary.withValues(alpha: 0.45))),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.signup),
                        child: const Text('회원가입'),
                      ),
                    ],
                  ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
