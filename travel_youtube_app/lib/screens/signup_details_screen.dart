import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
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
  final TextEditingController _nicknameController = TextEditingController();
  String? _inputError;

  @override
  void dispose() {
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _onSignupPressed(AuthProvider authProvider) async {
    final password = _passwordController.text;
    final nickname = _nicknameController.text.trim();

    if (password.length < 8) {
      setState(() => _inputError = '비밀번호는 8자 이상 입력해 주세요.');
      return;
    }
    if (nickname.isEmpty) {
      setState(() => _inputError = '닉네임을 입력해 주세요.');
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

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('마지막 단계예요', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(widget.email, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('signupPasswordField'),
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호 (8자 이상)',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('signupNicknameField'),
                controller: _nicknameController,
                decoration: InputDecoration(
                  labelText: '닉네임',
                  errorText: _inputError,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
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
    );
  }
}
