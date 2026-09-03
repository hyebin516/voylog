import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/hotel_model.dart';
import 'app_card.dart';

class HotelCard extends StatelessWidget {
  final HotelModel hotel;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const HotelCard({
    super.key,
    required this.hotel,
    required this.onTap,
    this.selected = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      color: selected ? AppColors.surfaceSoft : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.hotel_rounded, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hotel.name, style: textTheme.titleMedium),
                Text(
                  hotel.address,
                  style: textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_circle_rounded, color: colorScheme.primary),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
              tooltip: '삭제',
            ),
        ],
      ),
    );
  }
}
