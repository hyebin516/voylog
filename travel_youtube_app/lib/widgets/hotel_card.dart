import 'package:flutter/material.dart';

import '../models/hotel_model.dart';

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

    return Card(
      color: selected ? colorScheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(Icons.hotel_rounded, color: colorScheme.primary),
        title: Text(hotel.name),
        subtitle: Text(hotel.address, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) Icon(Icons.check_circle_rounded, color: colorScheme.primary),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                tooltip: '삭제',
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
