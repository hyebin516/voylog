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

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
