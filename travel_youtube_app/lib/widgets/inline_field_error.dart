import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Small coral error caption shown directly under a form field, matching
/// the Voylog design prototype's inline validation style.
class InlineFieldError extends StatelessWidget {
  const InlineFieldError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_rounded, size: 14, color: AppColors.coral),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.coral, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
