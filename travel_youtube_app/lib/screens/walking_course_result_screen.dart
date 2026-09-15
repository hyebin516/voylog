import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/itinerary_model.dart';
import '../models/nearby_recommendation_model.dart';
import '../models/start_point_model.dart';
import '../providers/walking_course_provider.dart';
import '../routes/app_routes.dart';
import '../repositories/map_repository.dart';
import '../utils/route_format.dart';
import '../utils/view_state.dart';
import '../widgets/data_source_attribution.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';
import '../utils/place_category_label.dart';

/// Matches the `isWalkingCourse` screen in the Voylog design handoff
/// (`Voylog UI/design_handoff_voylog/voylog-prototype-source.dc.html`):
/// static "뚜벅이 코스" header, a big title + region/count/duration subtitle,
/// a map, a numbered stop list with inter-stop walk-time rows, and a
/// "다시 생성" + "코스 저장하기" footer.
class WalkingCourseResultScreen extends StatelessWidget {
  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const WalkingCourseResultScreen({
    super.key,
    this.mapRepository = const KakaoMapRepository(),
  });

  @override
  Widget build(BuildContext context) {
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
                    '뚜벅이 코스',
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
              child: _WalkingCourseResultBody(mapRepository: mapRepository),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkingCourseResultBody extends StatefulWidget {
  const _WalkingCourseResultBody({required this.mapRepository});

  final MapRepository mapRepository;

  @override
  State<_WalkingCourseResultBody> createState() =>
      _WalkingCourseResultBodyState();
}

class _WalkingCourseResultBodyState extends State<_WalkingCourseResultBody> {
  String? _selectedMarkerId;

  Future<void> _onRegeneratePressed(BuildContext context) {
    return context.read<WalkingCourseProvider>().regenerate();
  }

  /// Re-runs the course anchored on a point the user picks instead of the
  /// region's center.
  Future<void> _onPickStartPointPressed(BuildContext context) async {
    final picked = await Navigator.pushNamed<Object?>(
      context,
      AppRoutes.startPointPicker,
    );
    if (picked is! StartPointModel || !context.mounted) return;
    await context.read<WalkingCourseProvider>().regenerateWithStartPoint(
      picked,
    );
  }

  Future<void> _onSavePressed(BuildContext context) async {
    final provider = context.read<WalkingCourseProvider>();
    final success = await provider.save();
    if (!context.mounted) return;

    final message = success
        ? '코스를 저장했어요.'
        : (provider.saveErrorMessage ?? '코스를 저장하지 못했습니다.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalkingCourseProvider>();

    if (provider.isLoading) {
      return const LoadingIndicator(message: '코스를 만들고 있어요...');
    }
    if (provider.state == ViewState.error) {
      return ErrorView(
        message: provider.errorMessage ?? '코스를 만들지 못했습니다.',
        onRetry: () => _onRegeneratePressed(context),
      );
    }

    final result = provider.result;
    if (result == null) {
      return const Center(child: Text('지역을 먼저 선택해주세요.'));
    }
    if (result.course == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            '아직 이 지역엔 걸어서 묶을 만한 장소가 충분하지 않아요.\n다른 지역을 선택해보세요.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final course = result.course!;
    final placeStops = course.routeData.where((p) => !p.isHotel).toList();
    final startPoint = course.routeData
        .where((p) => p.isHotel && !p.isVirtualRegionAnchor)
        .firstOrNull;
    final recommendationByPlaceId = {
      for (final r in result.recommendations) r.placeId: r,
    };

    // The region-center anchor is a routing artifact and stays hidden, but
    // a start point the user picked is a real place the walk begins at, so
    // it gets its own "출발" pin. Hiding it made choosing one look like it
    // changed nothing.
    final routeMarkers = <MapMarkerData>[
      if (startPoint != null &&
          startPoint.isUserStartPoint &&
          startPoint.latitude != null &&
          startPoint.longitude != null)
        MapMarkerData(
          id: startPoint.markerId,
          title: startPoint.name,
          latitude: startPoint.latitude!,
          longitude: startPoint.longitude!,
          label: '출발',
          kind: MapMarkerKind.start,
        ),
      for (var i = 0; i < placeStops.length; i++)
        if (placeStops[i].latitude != null && placeStops[i].longitude != null)
          MapMarkerData(
            id: placeStops[i].markerId,
            title: placeStops[i].name,
            latitude: placeStops[i].latitude!,
            longitude: placeStops[i].longitude!,
            label: '${i + 1}',
          ),
    ];

    final stopListItems = <Widget>[];
    for (var i = 0; i < placeStops.length; i++) {
      final markerId = placeStops[i].markerId;
      stopListItems.add(
        _StopRow(
          index: i + 1,
          point: placeStops[i],
          recommendation: recommendationByPlaceId[placeStops[i].placeId],
          isFirst: i == 0,
          isSelected: markerId == _selectedMarkerId,
          onTap: () => setState(() => _selectedMarkerId = markerId),
        ),
      );
      if (i < placeStops.length - 1) {
        stopListItems.add(
          _WalkTimeRow(durationSec: placeStops[i + 1].legDurationSec),
        );
      }
    }

    return SingleChildScrollView(
      child: ResponsiveCenter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                10,
                AppSpacing.md,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '걸어서 도는 코스예요',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${provider.region ?? ''} · 도보 ${placeStops.length}곳 · 약 ${formatRouteDuration(course.totalDurationSec)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StartPointRow(
                    pointName: startPoint?.name,
                    onPickStartPoint: () => _onPickStartPointPressed(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (routeMarkers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(
                  height: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: widget.mapRepository.buildMap(
                      initialLatitude: routeMarkers.first.latitude,
                      initialLongitude: routeMarkers.first.longitude,
                      markers: routeMarkers,
                      drawRoutePolyline: true,
                      focusedMarkerId: _selectedMarkerId,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < stopListItems.length; i++) ...[
                    stopListItems[i],
                    if (i < stopListItems.length - 1)
                      const SizedBox(height: 10),
                  ],
                  const DataSourceAttribution(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => _onRegeneratePressed(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '다시 생성',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: provider.saved ? '저장됨' : '코스 저장하기',
                      isLoading: provider.isSaving,
                      onPressed: provider.saved
                          ? null
                          : () => _onSavePressed(context),
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

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.index,
    required this.point,
    required this.recommendation,
    required this.isFirst,
    required this.isSelected,
    required this.onTap,
  });

  final int index;
  final RoutePointModel point;
  final NearbyRecommendationModel? recommendation;
  final bool isFirst;
  final bool isSelected;
  final VoidCallback onTap;

  String? get _subtitle {
    final parts = <String>[];
    final category = placeCategoryLabel(recommendation?.category);
    if (category != null) parts.add(category);

    if (isFirst) {
      parts.add('도보 시작');
    } else if (recommendation?.isOpen != null) {
      parts.add(recommendation!.isOpen! ? '지금 영업중' : '영업 종료');
    }

    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint1,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: AppColors.selectedBorder, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkTimeRow extends StatelessWidget {
  const _WalkTimeRow({required this.durationSec});

  final int? durationSec;

  @override
  Widget build(BuildContext context) {
    final seconds = durationSec;
    if (seconds == null) return const SizedBox.shrink();

    final minutes = (seconds / 60).round().clamp(1, 999);
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          const Icon(
            Icons.directions_walk_rounded,
            size: 14,
            color: AppColors.textMuted2,
          ),
          const SizedBox(width: 8),
          Text(
            '도보 $minutes분',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the course's start/end point, or prompts to pick one. A course
/// generated without one is anchored on the region's center point -- a
/// routing artifact, so there's no real place to show here.
class _StartPointRow extends StatelessWidget {
  const _StartPointRow({
    required this.pointName,
    required this.onPickStartPoint,
  });

  final String? pointName;
  final VoidCallback onPickStartPoint;

  @override
  Widget build(BuildContext context) {
    final name = pointName;
    return InkWell(
      key: const Key('walkingCourseResultStartPointRow'),
      onTap: onPickStartPoint,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              name == null
                  ? Icons.add_location_alt_outlined
                  : Icons.hotel_rounded,
              size: 15,
              color: name == null ? AppColors.textMuted2 : AppColors.primary,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                name == null ? '시작 지점 정하기' : '$name에서 출발·도착',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: name == null ? FontWeight.w500 : FontWeight.w700,
                  color: name == null ? AppColors.textMuted2 : AppColors.ink,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: AppColors.textMuted2,
            ),
          ],
        ),
      ),
    );
  }
}
