import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/itinerary_model.dart';
import '../services/kakao_map_launcher.dart';
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

  /// When set, tapping a stop calls this with its [RoutePointModel.markerId]
  /// instead of just opening the per-stop map bottom sheet -- lets a parent
  /// screen drive a shared map's `focusedMarkerId`. Optional so existing
  /// callers (trip overview, route planner) keep their current behavior.
  final ValueChanged<String>? onPointTap;
  final String? selectedPointId;

  /// The 왕복 / 호텔 → 호텔 chip. Off for a shared route, whose hotels were
  /// stripped on publish, so neither label describes it.
  final bool showRouteTypeChip;

  /// Opens a stop in the Kakao Map app from its map button. Widget tests
  /// inject a fake so nothing is launched.
  final KakaoMapLauncher kakaoMapLauncher;

  const RouteSummaryCard({
    super.key,
    required this.isRoundTrip,
    required this.transportMode,
    required this.totalDurationSec,
    required this.totalDistanceM,
    required this.routeData,
    this.onPointTap,
    this.selectedPointId,
    this.showRouteTypeChip = true,
    this.kakaoMapLauncher = const KakaoMapLauncher(),
  });

  String get _transportModeLabel {
    switch (transportMode) {
      case 'walk':
        return '도보';
      case 'transit':
        return '대중교통';
      case 'mixed':
        return '도보·버스';
      default:
        return '자동차';
    }
  }

  IconData get _transportModeIcon {
    switch (transportMode) {
      case 'walk':
        return Icons.directions_walk_rounded;
      case 'transit':
        return Icons.directions_transit_rounded;
      case 'mixed':
        return Icons.alt_route_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    var placeCounter = 0;
    final placeNumbers = routeData
        .map((p) => p.isHotel ? null : ++placeCounter)
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showRouteTypeChip) ...[
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
              ],
              // Named, not just an icon: with the route-type chip hidden
              // (a shared or bookmark-folder route) a lone icon sat at the
              // left edge with nothing to say what it meant.
              Icon(_transportModeIcon, size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                _transportModeLabel,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
              padding: EdgeInsets.only(
                bottom: i == routeData.length - 1 ? 0 : 10,
              ),
              child: _RoutePointCard(
                point: routeData[i],
                kakaoMapLauncher: kakaoMapLauncher,
                placeNumber: placeNumbers[i],
                isSelected:
                    onPointTap != null &&
                    selectedPointId == routeData[i].markerId,
                onTap: onPointTap == null
                    ? null
                    : () => onPointTap!(routeData[i].markerId),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoutePointCard extends StatelessWidget {
  const _RoutePointCard({
    required this.point,
    required this.kakaoMapLauncher,
    required this.placeNumber,
    this.isSelected = false,
    this.onTap,
  });

  final RoutePointModel point;
  final KakaoMapLauncher kakaoMapLauncher;
  final int? placeNumber;
  final bool isSelected;
  final VoidCallback? onTap;

  /// The stop itself in the Kakao Map app (or its web page without the app)
  /// -- directions, reviews and street view the in-app preview doesn't have.
  Future<void> _openInKakaoMap(BuildContext context) async {
    final opened = await kakaoMapLauncher.open(
      placeId: point.placeId ?? point.hotelId ?? point.name,
      name: point.name,
      latitude: point.latitude!,
      longitude: point.longitude!,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오맵을 열 수 없어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHotel = point.isHotel;
    final hasCoordinates = point.latitude != null && point.longitude != null;
    final legLabel =
        (point.legDistanceM != null && point.legDurationSec != null)
        ? '${_legModePrefix(point)}${formatRouteDistance(point.legDistanceM)} · ${formatRouteDuration(point.legDurationSec)}'
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint1,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.selectedBorder, width: 2)
              : null,
        ),
        // Centered: the number, the name (+ leg), and the icons line up on
        // one axis instead of the number hugging the top while the icons
        // spread down the side.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: point.isUserStartPoint
                    ? AppColors.ink
                    : (isHotel ? AppColors.danger : AppColors.accentCyan),
                shape: BoxShape.circle,
              ),
              // A walking course's start point isn't accommodation, so it
              // gets a flag rather than the house icon trip hotels use --
              // the house read as "a hotel called 성수역".
              child: isHotel
                  ? Icon(
                      point.isUserStartPoint
                          ? Icons.flag_rounded
                          : Icons.home_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : Text(
                      '$placeNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (point.isUserStartPoint) ...[
                    const SizedBox(height: 4),
                    const Text(
                      '출발 · 도착 지점',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (legLabel != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTint3Alt,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        legLabel,
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
            // Side by side: stacked, the two icons made every card twice
            // the height its content needed.
            IconButton(
              onPressed: hasCoordinates ? () => _openInKakaoMap(context) : null,
              icon: MapPinGlyphIcon(
                size: 20,
                color: hasCoordinates
                    ? AppColors.textTertiary
                    : AppColors.textMuted2,
              ),
              tooltip: '카카오맵에서 보기',
              visualDensity: VisualDensity.compact,
            ),
            if (!isHotel && point.placeId != null)
              BookmarkButton(placeId: point.placeId!, compact: true),
          ],
        ),
      ),
    );
  }
}

/// "도보 " / "차량 " before a leg's distance on a route that mixes modes;
/// nothing on a single-mode route, whose header already says how it moves.
String _legModePrefix(RoutePointModel point) {
  switch (point.legTransportMode) {
    case 'walk':
      return '도보 ';
    case 'transit':
      final bus = point.legGuidance?.split(' · ').first;
      return bus == null ? '버스 ' : '버스 $bus · ';
    case 'car':
      return '차량 ';
    default:
      return '';
  }
}
