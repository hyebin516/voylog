import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/shared_route_model.dart';
import '../repositories/map_repository.dart';
import '../widgets/data_source_attribution.dart';
import '../widgets/pinned_map_sliver.dart';
import '../widgets/responsive_center.dart';
import '../widgets/route_summary_card.dart';

/// FR-21: the route behind a card in the home feed "다른 유저의 추천 동선" --
/// its stops on a map and in order, the same map + stop-card layout as a
/// walking course. Opened with the feed's own [SharedRouteModel], which
/// already carries the stops, so nothing is fetched here.
class SharedRouteDetailScreen extends StatefulWidget {
  final SharedRouteModel route;

  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const SharedRouteDetailScreen({
    super.key,
    required this.route,
    this.mapRepository = const KakaoMapRepository(),
  });

  @override
  State<SharedRouteDetailScreen> createState() =>
      _SharedRouteDetailScreenState();
}

class _SharedRouteDetailScreenState extends State<SharedRouteDetailScreen> {
  String? _selectedMarkerId;

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final stops = route.routeData.where((p) => !p.isHotel).toList();
    final markers = <MapMarkerData>[
      for (var i = 0; i < stops.length; i++)
        if (stops[i].latitude != null && stops[i].longitude != null)
          MapMarkerData(
            id: stops[i].markerId,
            title: stops[i].name,
            latitude: stops[i].latitude!,
            longitude: stops[i].longitude!,
            label: '${i + 1}',
          ),
    ];
    final author = route.authorNickname ?? '알 수 없음';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTint2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '추천 동선',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: ResponsiveCenter(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${route.isOwner ? '$author (나)' : author} · 장소 ${stops.length}곳 · 좋아요 ${route.likeCount}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            if (route.matchPercent != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceTint2,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '취향 일치 ${route.matchPercent}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (markers.isNotEmpty)
                    PinnedMapSliver(
                      map: widget.mapRepository.buildMap(
                        initialLatitude: markers.first.latitude,
                        initialLongitude: markers.first.longitude,
                        markers: markers,
                        drawRoutePolyline: true,
                        focusedMarkerId: _selectedMarkerId,
                      ),
                    )
                  else
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: ResponsiveCenter(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            RouteSummaryCard(
                              isRoundTrip: false,
                              showRouteTypeChip: false,
                              transportMode: route.transportMode,
                              totalDurationSec: route.totalDurationSec,
                              totalDistanceM: route.totalDistanceM,
                              routeData: stops,
                              selectedPointId: _selectedMarkerId,
                              onPointTap: (markerId) =>
                                  setState(() => _selectedMarkerId = markerId),
                            ),
                            const DataSourceAttribution(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
