import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/itinerary_model.dart';
import '../models/map_view_types.dart';
import '../repositories/map_repository.dart';
import '../utils/route_format.dart';
import 'app_card.dart';
import 'bookmark_button.dart';
import 'nav_icons.dart';

/// Renders a route's summary (round-trip/hotel-to-hotel chip, transport
/// mode, total time/distance, ordered stops). Takes plain fields rather
/// than an `ItineraryModel` so it can also render an ephemeral,
/// not-yet-saved course (e.g. the region walking-course discovery flow)
/// that has no `itineraryId`/`tripId` of its own.
///
/// Each stop renders as a place card (numbered badge, name, leg
/// distance/time chip, map + bookmark actions) -- the same visual language
/// as the place cards on the video analysis screen -- rather than a bare
/// timeline row, since this widget is shared by both "여행 동선" screens
/// (trip overview, route planner) and the saved walking course detail
/// screen ("내 코스 목록").
class RouteSummaryCard extends StatelessWidget {
  final bool isRoundTrip;
  final String transportMode;
  final int? totalDurationSec;
  final int? totalDistanceM;
  final List<RoutePointModel> routeData;

  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const RouteSummaryCard({
    super.key,
    required this.isRoundTrip,
    required this.transportMode,
    required this.totalDurationSec,
    required this.totalDistanceM,
    required this.routeData,
    this.mapRepository = const KakaoMapRepository(),
  });

  IconData get _transportModeIcon {
    switch (transportMode) {
      case 'walk':
        return Icons.directions_walk_rounded;
      case 'transit':
        return Icons.directions_transit_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    var placeCounter = 0;
    final placeNumbers = routeData.map((p) => p.isHotel ? null : ++placeCounter).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isRoundTrip ? '왕복' : '호텔 → 호텔',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(_transportModeIcon, size: 17, color: AppColors.textTertiary),
              const Spacer(),
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                formatRouteDuration(totalDurationSec),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 14),
              Icon(
                Icons.route_outlined,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                formatRouteDistance(totalDistanceM),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < routeData.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == routeData.length - 1 ? 0 : 10),
              child: _RoutePointCard(
                point: routeData[i],
                placeNumber: placeNumbers[i],
                mapRepository: mapRepository,
              ),
            ),
        ],
      ),
    );
  }
}

class _RoutePointCard extends StatelessWidget {
  const _RoutePointCard({required this.point, required this.placeNumber, required this.mapRepository});

  final RoutePointModel point;
  final int? placeNumber;
  final MapRepository mapRepository;

  void _showOnMap(BuildContext context) {
    if (point.latitude == null || point.longitude == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(point.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: mapRepository.buildMap(
                    initialLatitude: point.latitude!,
                    initialLongitude: point.longitude!,
                    markers: [
                      MapMarkerData(
                        id: point.placeId ?? point.hotelId ?? point.name,
                        title: point.name,
                        latitude: point.latitude!,
                        longitude: point.longitude!,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHotel = point.isHotel;
    final hasCoordinates = point.latitude != null && point.longitude != null;
    final legLabel = (point.legDistanceM != null && point.legDurationSec != null)
        ? '${formatRouteDistance(point.legDistanceM)} · ${formatRouteDuration(point.legDurationSec)}'
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceTint1, borderRadius: BorderRadius.circular(20)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isHotel ? AppColors.danger : AppColors.accentCyan,
              shape: BoxShape.circle,
            ),
            child: isHotel
                ? const Icon(Icons.home_rounded, size: 14, color: Colors.white)
                : Text(
                    '$placeNumber',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                if (legLabel != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.surfaceTint3Alt, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      legLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: hasCoordinates ? () => _showOnMap(context) : null,
                icon: MapPinGlyphIcon(
                  size: 20,
                  color: hasCoordinates ? AppColors.textTertiary : AppColors.textMuted2,
                ),
                tooltip: '지도 보기',
                visualDensity: VisualDensity.compact,
              ),
              if (!isHotel && point.placeId != null) BookmarkButton(placeId: point.placeId!),
            ],
          ),
        ],
      ),
    );
  }
}
