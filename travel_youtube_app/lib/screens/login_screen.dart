import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../services/kakao_auth_service.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/primary_button.dart';

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
  }

  Future<void> _onKakaoLoginPressed(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();

    String kakaoAccessToken;
    try {
      kakaoAccessToken = await KakaoAuthService.login(context);
    } on KakaoClientException catch (e) {
      if (e.reason == ClientErrorCause.cancelled) return; // user dismissed the chooser
      if (context.mounted) await showErrorDialog(context, '카카오 로그인에 실패했습니다.');
      return;
    } catch (_) {
      if (context.mounted) await showErrorDialog(context, '카카오 로그인에 실패했습니다.');
      return;
    }

    if (!context.mounted) return;
    await authProvider.loginWithKakao(kakaoAccessToken);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.state == ViewState.success && authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.travel_explore_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text('여행 유튜브 요약', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '유튜브 영상 속 장소를 찾고, 최적의 여행 동선을 계획하세요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
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
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: '이메일로 로그인',
                isLoading: authProvider.isLoading,
                onPressed: () => _onEmailLoginPressed(authProvider),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.signupEmail),
                child: const Text('이메일로 회원가입'),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: '카카오로 로그인',
                icon: Icons.chat_bubble_rounded,
                isLoading: authProvider.isLoading,
                onPressed: () => _onKakaoLoginPressed(context),
              ),
              if (authProvider.state == ViewState.error) ...[
                const SizedBox(height: AppSpacing.md),
                ErrorView(message: authProvider.errorMessage ?? '로그인에 실패했습니다.'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
