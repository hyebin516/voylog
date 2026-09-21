import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/saved_walking_course_model.dart';
import '../providers/saved_walking_course_provider.dart';
import '../repositories/map_repository.dart';
import '../services/kakao_map_launcher.dart';
import '../widgets/error_view.dart';
import '../widgets/responsive_center.dart';
import '../widgets/route_summary_card.dart';

class SavedWalkingCourseDetailScreen extends StatefulWidget {
  final SavedWalkingCourseModel course;

  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  /// Opens a leg's directions in Kakao Map. Widget tests inject a fake.
  final KakaoMapLauncher kakaoMapLauncher;

  const SavedWalkingCourseDetailScreen({
    super.key,
    required this.course,
    this.mapRepository = const KakaoMapRepository(),
    this.kakaoMapLauncher = const KakaoMapLauncher(),
  });

  @override
  State<SavedWalkingCourseDetailScreen> createState() =>
      _SavedWalkingCourseDetailScreenState();
}

class _SavedWalkingCourseDetailScreenState
    extends State<SavedWalkingCourseDetailScreen> {
  String? _selectedMarkerId;

  SavedWalkingCourseModel get course => widget.course;
  MapRepository get mapRepository => widget.mapRepository;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('코스 삭제'),
        content: Text('${course.region} 코스를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final provider = context.read<SavedWalkingCourseProvider>();
    final success = await provider.deleteCourse(course.savedCourseId);
    if (!context.mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      final message = provider.errorMessage ?? '코스 삭제에 실패했습니다.';
      showErrorDialog(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A course generated without a hotel is anchored on a virtual
    // region-center point named after the region ("부산") -- a routing
    // artifact, not a place. It's hidden here (and flagged with a notice
    // below) instead of being shown as if it were a real stop. A course
    // generated with a real hotel keeps its hotel cards.
    final hasVirtualAnchor = course.routeData.any(
      (p) => p.isVirtualRegionAnchor,
    );
    // A round trip lists its start point twice (first and last). Showing
    // it once keeps the list readable and gives each map pin a unique id.
    final seenMarkerIds = <String>{};
    final visibleRouteData = course.routeData
        .where((p) => !p.isVirtualRegionAnchor)
        .where((p) => seenMarkerIds.add(p.markerId))
        .toList();

    var stopNumber = 0;
    final routeMarkers = <MapMarkerData>[
      for (final p in visibleRouteData)
        if (p.latitude != null && p.longitude != null)
          MapMarkerData(
            id: p.markerId,
            title: p.name,
            latitude: p.latitude!,
            longitude: p.longitude!,
            label: p.isHotel ? '출발' : '${++stopNumber}',
            kind: p.isHotel ? MapMarkerKind.start : MapMarkerKind.place,
          ),
    ];

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
                  Expanded(
                    child: Text(
                      '${course.region} 코스',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _confirmDelete(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF1F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: ResponsiveCenter(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceTint2,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '장소 ${visibleRouteData.where((p) => !p.isHotel).length}곳'
                                '${course.totalDistanceM != null ? ' · ${(course.totalDistanceM! / 1000).toStringAsFixed(1)}km' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (routeMarkers.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 320,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: mapRepository.buildMap(
                              initialLatitude: routeMarkers.first.latitude,
                              initialLongitude: routeMarkers.first.longitude,
                              markers: routeMarkers,
                              drawRoutePolyline: true,
                              focusedMarkerId: _selectedMarkerId,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        '저장된 순서',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (hasVirtualAnchor) ...[
                        const _NoHotelNotice(),
                        const SizedBox(height: 8),
                      ],
                      RouteSummaryCard(
                        isRoundTrip: course.isRoundTrip,
                        showRouteTypeChip: !course.isPlaceToPlace,
                        transportMode: course.transportMode,
                        totalDurationSec: course.totalDurationSec,
                        totalDistanceM: course.totalDistanceM,
                        routeData: visibleRouteData,
                        kakaoMapLauncher: widget.kakaoMapLauncher,
                        selectedPointId: _selectedMarkerId,
                        onPointTap: (markerId) =>
                            setState(() => _selectedMarkerId = markerId),
                      ),
                    ],
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

/// Shown for a course that was generated before/without picking a hotel:
/// its start/end point is the region's center, not a real place, so the
/// saved snapshot has no hotel to display.
class _NoHotelNotice extends StatelessWidget {
  const _NoHotelNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hotel_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '시작·도착 호텔이 없는 코스예요.\n새로 만들 때 호텔을 선택하면 호텔에서 출발해 돌아오는 동선으로 만들어드려요.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
