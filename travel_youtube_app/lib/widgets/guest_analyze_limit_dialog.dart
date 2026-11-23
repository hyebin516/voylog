import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Shown when a guest has used up the analyses the backend allows without
/// logging in (FR-01, `ANALYZE_LIMIT_GUEST`).
///
/// It replaces the generic "요청을 처리하지 못했습니다" error, which gave
/// no way forward: retrying only hits the same limit, while logging in moves
/// the user to their own, larger allowance. The wording deliberately leaves
/// out how many analyses a guest gets -- that number lives on the server.
///
/// Returns true when the user chose 로그인하기. Navigation is left to the
/// caller, because one caller has to close its own screen first.
Future<bool> showGuestAnalyzeLimitDialog(BuildContext context) async {
  final wantsLogin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.lock_outline_rounded, size: 26, color: Colors.white),
      ),
      title: const Text(
        '이용 횟수를 다 사용했어요',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      content: const Text(
        '로그인하지 않고 쓸 수 있는 분석 횟수를 모두 사용했어요.\n로그인하면 계속 분석할 수 있어요.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('나중에'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('로그인하기'),
        ),
      ],
    ),
  );
  return wantsLogin ?? false;
}
