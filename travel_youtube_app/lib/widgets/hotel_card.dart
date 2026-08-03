import 'package:flutter/material.dart';

import '../models/hotel_model.dart';

class HotelCard extends StatelessWidget {
  final HotelModel hotel;
  final bool selected;
  final VoidCallback onTap;

  const HotelCard({
    super.key,
    required this.hotel,
    required this.onTap,
    this.selected = false,
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
        trailing: selected ? Icon(Icons.check_circle_rounded, color: colorScheme.primary) : null,
        onTap: onTap,
      ),
    );
  }
}
