import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../routes/app_routes.dart';

/// Shown in place of a screen's content when it needs a logged-in user but
/// the viewer is a guest -- matches the design handoff's `showLoginRequired`
/// modal (icon, title, message, 로그인하기/회원가입하기 buttons), but laid
/// out inline as the tab's whole content instead of a dimmed overlay, since
/// there is nothing to dim behind it here.
///
/// Also fixes a real bug: before this existed, guest-accessible tabs
/// (북마크/여행) called their APIs anyway, got a 401, and showed
/// `ApiException`'s "로그인이 만료되었습니다" wording -- which is wrong for
/// someone who was never logged in, not just someone whose session expired.
/// Screens should check `AuthProvider.isAuthenticated` and render this
/// instead of attempting the API call at all.
class LoginRequiredCard extends StatelessWidget {
  const LoginRequiredCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.primaryStrong.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 10))],
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 28, color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Text('로그인이 필요해요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                child: const Text('로그인하기'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.signup),
                child: const Text('회원가입하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
