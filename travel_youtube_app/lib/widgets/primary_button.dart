import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The app's shared primary CTA -- matches the design handoff's `.btn-primary`
/// class exactly: `linear-gradient(135deg, #5fc2e8, #2f8fd0)` fill, pill
/// shape, white bold label. Built by hand (not `ElevatedButton`) because
/// `ElevatedButton`'s `backgroundColor` only accepts a solid [Color], not a
/// [Gradient] -- using it here silently flattened every primary button in
/// the app to a solid color instead of the design's gradient.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  // Takes precedence over [icon] when set -- for design-traced glyphs
  // (lib/widgets/nav_icons.dart) that don't have a matching Material icon.
  final Widget? iconWidget;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.iconWidget,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.accentCyan, AppColors.primaryStrong],
            ),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primaryStrong.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: InkWell(
            onTap: disabled ? null : onPressed,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (iconWidget != null) ...[
                            iconWidget!,
                            const SizedBox(width: 8),
                          ] else if (icon != null) ...[
                            Icon(icon, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
