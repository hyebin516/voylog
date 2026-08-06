import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('이메일 인증')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('인증번호를 입력해 주세요', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${widget.email}로 보낸 6자리 인증번호를 5분 이내에 입력해 주세요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('signupOtpField'),
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '123456',
                  errorText: _inputError,
                  prefixIcon: const Icon(Icons.pin_outlined),
                ),
              ),
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
    );
  }
}
