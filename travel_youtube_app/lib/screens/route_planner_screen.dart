import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../utils/route_paths.dart';
import '../models/map_view_types.dart';
import '../providers/hotel_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/trip_provider.dart';
import '../repositories/map_repository.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';
import '../widgets/route_summary_card.dart';
import 'hotel_search_screen.dart';

class RoutePlannerScreen extends StatelessWidget {
  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const RoutePlannerScreen({
    super.key,
    this.mapRepository = const KakaoMapRepository(),
  });

  Future<void> _pickHotel(BuildContext context, HotelSelectionRole role) {
    return Navigator.pushNamed(
      context,
      AppRoutes.hotelSearch,
      arguments: HotelSearchScreenArgs(role: role),
    );
  }

  Future<void> _optimize(BuildContext context) async {
    final hotelProvider = context.read<HotelProvider>();
    final itineraryProvider = context.read<ItineraryProvider>();
    final tripProvider = context.read<TripProvider>();

    final startHotel = hotelProvider.selectedStartHotel;
    final endHotel = hotelProvider.selectedEndHotel;
    final tripId = tripProvider.activeTripId;
    final dayNumber = tripProvider.activeDayNumber;
    if (startHotel == null ||
        endHotel == null ||
        tripId == null ||
        dayNumber == null) {
      return;
    }

    await itineraryProvider.optimize(
      tripId: tripId,
      dayNumber: dayNumber,
      startHotelId: startHotel.hotelId,
      endHotelId: endHotel.hotelId,
    );
  }

  void _backToTrip(BuildContext context) {
    final tripProvider = context.read<TripProvider>();
    final tripId = tripProvider.activeTripId;
    tripProvider.clearActiveDay();
    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name == AppRoutes.tripDetail);
    if (tripId != null) tripProvider.loadTrip(tripId);
  }

  void _changeFolder(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hotelProvider = context.watch<HotelProvider>();
    final itineraryProvider = context.watch<ItineraryProvider>();
    final tripProvider = context.watch<TripProvider>();

    if (tripProvider.activeTripId == null ||
        tripProvider.activeDayNumber == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: const Text(
                '여행 상세 화면에서 "날짜 추가"를 눌러 시작해주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        ),
      );
    }

    final startHotel = hotelProvider.selectedStartHotel;
    final endHotel = hotelProvider.selectedEndHotel;
    final canOptimize =
        startHotel != null && endHotel != null && itineraryProvider.canOptimize;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                  Text(
                    itineraryProvider.result == null
                        ? '${tripProvider.activeDayNumber}일차 동선 최적화'
                        : '${tripProvider.activeDayNumber}일차 동선',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: ResponsiveCenter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HotelSelectTile(
                          label: '시작 호텔',
                          hotelName: startHotel?.name,
                          onTap: () =>
                              _pickHotel(context, HotelSelectionRole.start),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _HotelSelectTile(
                          label: '종료 호텔',
                          hotelName: endHotel?.name,
                          onTap: () =>
                              _pickHotel(context, HotelSelectionRole.end),
                        ),
                        if (startHotel != null && endHotel != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Chip(
                              label: Text(
                                startHotel.hotelId == endHotel.hotelId
                                    ? '왕복'
                                    : '호텔 → 호텔',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              backgroundColor: AppColors.surfaceTint2,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                          ),
                          if (startHotel.hotelId == endHotel.hotelId) ...[
                            const SizedBox(height: 4),
                            const Text(
                              '시작·종료가 같아 왕복으로 계산돼요',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                        if (itineraryProvider.result == null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: [
                              ChoiceChip(
                                label: const Text('자동차'),
                                avatar: const Icon(
                                  Icons.directions_car_rounded,
                                  size: 18,
                                ),
                                selected:
                                    itineraryProvider.transportMode == 'car',
                                onSelected: (_) => itineraryProvider
                                    .selectTransportMode('car'),
                                selectedColor: AppColors.surfaceTint3,
                                backgroundColor: AppColors.surfaceTint2,
                                labelStyle: TextStyle(
                                  color:
                                      itineraryProvider.transportMode == 'car'
                                      ? AppColors.primaryStrong
                                      : AppColors.textTertiary,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color:
                                      itineraryProvider.transportMode == 'car'
                                      ? AppColors.selectedBorder
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('도보'),
                                avatar: const Icon(
                                  Icons.directions_walk_rounded,
                                  size: 18,
                                ),
                                selected:
                                    itineraryProvider.transportMode == 'walk',
                                onSelected: (_) => itineraryProvider
                                    .selectTransportMode('walk'),
                                selectedColor: AppColors.surfaceTint3,
                                backgroundColor: AppColors.surfaceTint2,
                                labelStyle: TextStyle(
                                  color:
                                      itineraryProvider.transportMode == 'walk'
                                      ? AppColors.primaryStrong
                                      : AppColors.textTertiary,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color:
                                      itineraryProvider.transportMode == 'walk'
                                      ? AppColors.selectedBorder
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('대중교통'),
                                avatar: const Icon(
                                  Icons.directions_transit_rounded,
                                  size: 18,
                                ),
                                selected:
                                    itineraryProvider.transportMode ==
                                    'transit',
                                onSelected: (_) => itineraryProvider
                                    .selectTransportMode('transit'),
                                selectedColor: AppColors.surfaceTint3,
                                backgroundColor: AppColors.surfaceTint2,
                                labelStyle: TextStyle(
                                  color:
                                      itineraryProvider.transportMode ==
                                          'transit'
                                      ? AppColors.primaryStrong
                                      : AppColors.textTertiary,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color:
                                      itineraryProvider.transportMode ==
                                          'transit'
                                      ? AppColors.selectedBorder
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (itineraryProvider.result == null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${itineraryProvider.sourceFolderName ?? "선택한 폴더"} · ${itineraryProvider.selectedPlaces.length}곳 사용',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InkWell(
                                onTap: () => _changeFolder(context),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    '폴더 변경',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final place
                              in itineraryProvider.selectedPlaces) ...[
                            _SelectedPlaceRow(
                              name: place.name,
                              onRemove: () =>
                                  itineraryProvider.removePlace(place.placeId),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '호텔은 양 끝에 고정되고, 그 사이 장소들의 방문 순서만 최적화돼요',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          PrimaryButton(
                            label: '동선 최적화',
                            icon: Icons.route_rounded,
                            isLoading: itineraryProvider.isLoading,
                            onPressed: canOptimize
                                ? () => _optimize(context)
                                : null,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        if (itineraryProvider.isLoading)
                          const LoadingIndicator(message: '최적 동선을 계산하고 있어요...'),
                        if (itineraryProvider.state == ViewState.error)
                          ErrorView(
                            message:
                                itineraryProvider.errorMessage ??
                                '동선 생성에 실패했습니다.',
                            onRetry: canOptimize
                                ? () => _optimize(context)
                                : null,
                          ),
                        if (itineraryProvider.result != null) ...[
                          RouteSummaryCard(
                            isRoundTrip: itineraryProvider.result!.isRoundTrip,
                            transportMode:
                                itineraryProvider.result!.transportMode,
                            totalDurationSec:
                                itineraryProvider.result!.totalDurationSec,
                            totalDistanceM:
                                itineraryProvider.result!.totalDistanceM,
                            routeData: itineraryProvider.result!.routeData,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Builder(
                            builder: (context) {
                              // One list for both the pins and the line, so
                              // a point dropped for missing coordinates never
                              // leaves the two out of step.
                              final routePoints = itineraryProvider.result!.routeData
                                  .where(
                                    (p) =>
                                        p.latitude != null &&
                                        p.longitude != null,
                                  )
                                  .toList();
                              final routeMarkers = routePoints
                                  .map(
                                    (p) => MapMarkerData(
                                      id: p.placeId ?? p.hotelId ?? p.name,
                                      title: p.name,
                                      latitude: p.latitude!,
                                      longitude: p.longitude!,
                                    ),
                                  )
                                  .toList();

                              return SizedBox(
                                height: 320,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: mapRepository.buildMap(
                                    initialLatitude:
                                        routeMarkers.first.latitude,
                                    initialLongitude:
                                        routeMarkers.first.longitude,
                                    markers: routeMarkers,
                                    drawRoutePolyline: true,
                                    routeLegPaths: routeLegPathsOf(routePoints),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PrimaryButton(
                            label: '저장 완료 — 여행으로 돌아가기',
                            icon: Icons.check_rounded,
                            onPressed: () => _backToTrip(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedPlaceRow extends StatelessWidget {
  final String name;
  final VoidCallback onRemove;

  const _SelectedPlaceRow({required this.name, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint1,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.drag_indicator_rounded,
            size: 16,
            color: AppColors.borderStrong,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 13,
                color: AppColors.borderStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotelSelectTile extends StatelessWidget {
  final String label;
  final String? hotelName;
  final VoidCallback onTap;

  const _HotelSelectTile({
    required this.label,
    required this.hotelName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint1,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.hotel_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hotelName ?? '호텔을 선택하세요',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
