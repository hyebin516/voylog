import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Shared pill-shaped tag display, used both for read-only tag lists (place
/// detail, nearby/walking-course recommendation matched tags) and for
/// selectable tag pickers (taste preference survey). Tag values are the raw
/// codes from [TastePreferenceOptions.tags] / the AI worker's tag catalog --
/// codes and display labels are the same Korean string on both ends, so no
/// separate lookup table is needed.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surfaceTint3Alt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.primaryStrong,
          fontWeight: FontWeight.w600,
          fontSize: 11.5,
        ),
      ),
    );

    if (onTap == null) return chip;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: chip,
    );
  }
}
