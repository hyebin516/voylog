import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Whether an inline caption is reporting a problem or confirming something.
enum InlineFieldTone { error, success }

/// Small caption shown directly under a form field: a 14px filled icon, a
/// 6px gap and 12px/500 text, as the design prototype draws it.
///
/// [InlineFieldTone.success] exists because a check that only speaks up when
/// something is wrong leaves "it worked" indistinguishable from "nothing
/// happened" -- which is how the nickname duplicate check read.
class InlineFieldError extends StatelessWidget {
  const InlineFieldError({
    super.key,
    required this.message,
    this.tone = InlineFieldTone.error,
  });

  final String message;
  final InlineFieldTone tone;

  @override
  Widget build(BuildContext context) {
    final isError = tone == InlineFieldTone.error;
    final color = isError ? AppColors.danger : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.error_rounded : Icons.check_circle_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
