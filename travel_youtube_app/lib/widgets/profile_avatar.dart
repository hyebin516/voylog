import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// The user's Kakao profile photo, falling back to the app's gradient circle
/// with a person glyph.
///
/// The fallback is not an edge case: a Kakao account only has a photo when
/// the user consented to sharing it, and an email account never has one. It
/// is also what shows while the image loads and if loading fails, so the
/// avatar never collapses or flashes empty.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.size = 60,
    this.shadow = false,
  });

  final String? imageUrl;
  final double size;

  /// The floating shadow the my-page header's avatar carries; the dialog's
  /// copy sits on a flat surface and doesn't.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        boxShadow: shadow ? AppColors.floatingButtonShadow() : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? _fallback
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallback,
              // Keeps the gradient visible instead of a blank circle while
              // the photo downloads.
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                  frame == null && !wasSynchronouslyLoaded ? _fallback : child,
            ),
    );
  }

  Widget get _fallback => Icon(Icons.person_rounded, size: size * 0.47, color: Colors.white);
}
