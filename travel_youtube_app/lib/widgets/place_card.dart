import 'package:flutter/material.dart';

import '../utils/timestamp_format.dart';
import 'bookmark_button.dart';

class PlaceCard extends StatelessWidget {
  final String placeId;
  final String name;
  final String? address;
  final int? timestampSec;
  final VoidCallback? onTap;
  final VoidCallback? onTimestampTap;
  final VoidCallback? onMapTap;
  final bool showBookmarkButton;

  /// When non-null, the card renders a selection checkbox for route
  /// planning (e.g. picking bookmarked places for the itinerary).
  final bool? selected;
  final ValueChanged<bool?>? onSelectedChanged;

  const PlaceCard({
    super.key,
    required this.placeId,
    required this.name,
    this.address,
    this.timestampSec,
    this.onTap,
    this.onTimestampTap,
    this.onMapTap,
    this.showBookmarkButton = true,
    this.selected,
    this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (selected != null)
                Checkbox(value: selected, onChanged: onSelectedChanged),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (address != null && address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address!,
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (timestampSec != null) ...[
                      const SizedBox(height: 8),
                      ActionChip(
                        avatar: const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 18,
                        ),
                        label: Text(formatTimestamp(timestampSec!)),
                        onPressed: onTimestampTap,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onMapTap,
                icon: const Icon(Icons.map_outlined),
                tooltip: '지도 보기',
              ),
              if (showBookmarkButton) BookmarkButton(placeId: placeId),
            ],
          ),
        ),
      ),
    );
  }
}
