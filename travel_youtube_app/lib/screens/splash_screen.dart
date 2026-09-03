import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/voylog_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final isAuthenticated = await context.read<AuthProvider>().restoreSession();
    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      isAuthenticated ? AppRoutes.home : AppRoutes.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackdrop(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const VoylogLogoMark(size: 64),
              const SizedBox(height: AppSpacing.md),
              const VoylogWordmark(fontSize: 26),
              const SizedBox(height: AppSpacing.xl),
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
