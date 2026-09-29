import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Shared card surface for the Voylog design system: white background,
/// 20px rounded corners, a 1.5px border and the teal-tinted `sh-card-soft`
/// shadow instead of Material's grey elevation. Replaces bare `Card` usage
/// across the app so every card looks consistent.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = 20,
    this.color,
    this.borderColor,
    this.shadow,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? color;

  /// Overrides the default `border` token -- used to mark a card out, as the
  /// shared feed does for the viewer's own posts.
  final Color? borderColor;

  /// Overrides `sh-card-soft`, for the few cards the handoff gives the
  /// stronger `sh-card`.
  final List<BoxShadow>? shadow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? AppColors.dividerStrong, width: 1.5),
        boxShadow: shadow ?? AppColors.cardSoftShadow(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
