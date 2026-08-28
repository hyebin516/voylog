import 'package:flutter/material.dart';

import '../models/itinerary_model.dart';

class RouteSummaryCard extends StatelessWidget {
  final ItineraryModel itinerary;

  const RouteSummaryCard({super.key, required this.itinerary});

  String _formatDuration(int? seconds) {
    if (seconds == null) return '-';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '$hours시간 $minutes분';
    return '$minutes분';
  }

  String _formatDistance(int? meters) {
    if (meters == null) return '-';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
    return '${meters}m';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(itinerary.isRoundTrip ? '왕복' : '호텔 → 호텔')),
                const SizedBox(width: 8),
                Icon(
                  itinerary.isWalk ? Icons.directions_walk_rounded : Icons.directions_car_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const Spacer(),
                Icon(Icons.timer_outlined, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(_formatDuration(itinerary.totalDurationSec), style: textTheme.bodyMedium),
                const SizedBox(width: 16),
                Icon(Icons.route_outlined, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(_formatDistance(itinerary.totalDistanceM), style: textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...itinerary.routeData.map((point) {
              final isHotel = point.isHotel;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isHotel ? colorScheme.primary : colorScheme.secondaryContainer,
                      child: Icon(
                        isHotel ? Icons.hotel_rounded : Icons.place_rounded,
                        size: 14,
                        color: isHotel ? colorScheme.onPrimary : colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(point.name, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
