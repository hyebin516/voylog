import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The app's shared primary CTA -- the handoff's `.btn-primary`: a solid
/// `primary-600` pill with a white bold label and `sh-cta` beneath it.
///
/// v1 filled this with a gradient, which is why it is built by hand rather
/// than from `ElevatedButton` (whose `backgroundColor` takes only a solid
/// [Color]). v2 drops the gradient, but the hand-built version stays: it
/// also carries the exact shadow and the 52px height the handoff specifies.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  // Takes precedence over [icon] when set -- for design-traced glyphs
  // (lib/widgets/nav_icons.dart) that don't have a matching Material icon.
  final Widget? iconWidget;

  /// Floats [icon] at the right edge instead of placing it before the
  /// label, which stays centred in the button. The handoff's onboarding CTA
  /// is drawn that way.
  final bool iconAtEnd;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.iconWidget,
    this.iconAtEnd = false,
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
            color: AppColors.primary,
            boxShadow: disabled ? null : AppColors.ctaShadow(),
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
                    : iconAtEnd
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          if (icon != null)
                            Positioned(
                              right: 22,
                              child: Icon(icon, size: 20, color: Colors.white),
                            ),
                        ],
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
