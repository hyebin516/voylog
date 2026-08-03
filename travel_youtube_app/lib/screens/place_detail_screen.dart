import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/place_model.dart';
import '../repositories/map_repository.dart';
import '../utils/timestamp_format.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/primary_button.dart';

class PlaceDetailScreen extends StatelessWidget {
  final PlaceModel place;

  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const PlaceDetailScreen({
    super.key,
    required this.place,
    this.mapRepository = const KakaoMapRepository(),
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [BookmarkButton(placeId: place.placeId)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: place.hasCoordinates
                  ? mapRepository.buildMap(
                      initialLatitude: place.latitude!,
                      initialLongitude: place.longitude!,
                      markers: [
                        MapMarkerData(
                          id: place.placeId,
                          title: place.name,
                          latitude: place.latitude!,
                          longitude: place.longitude!,
                        ),
                      ],
                    )
                  : ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(child: Text('위치 정보가 없습니다.')),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(place.name, style: textTheme.headlineSmall),
          if (place.address != null && place.address!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(place.address!, style: textTheme.bodyMedium)),
              ],
            ),
          ],
          if (place.timestampSec != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.schedule_outlined, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text('영상 ${formatTimestamp(place.timestampSec!)} 지점에 등장', style: textTheme.bodyMedium),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (place.timestampSec != null)
            PrimaryButton(
              label: '영상에서 이 장면 보기',
              icon: Icons.play_circle_outline_rounded,
              onPressed: () => Navigator.pop(context, place.timestampSec),
            ),
        ],
      ),
    );
  }
}
