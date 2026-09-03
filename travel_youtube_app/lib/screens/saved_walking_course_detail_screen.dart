import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/saved_walking_course_model.dart';
import '../providers/saved_walking_course_provider.dart';
import '../repositories/map_repository.dart';
import '../widgets/error_view.dart';
import '../widgets/responsive_center.dart';
import '../widgets/route_summary_card.dart';

class SavedWalkingCourseDetailScreen extends StatelessWidget {
  final SavedWalkingCourseModel course;

  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const SavedWalkingCourseDetailScreen({
    super.key,
    required this.course,
    this.mapRepository = const KakaoMapRepository(),
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('코스 삭제'),
        content: Text('${course.region} 코스를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
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
    final routeMarkers = course.routeData
        .where((p) => p.latitude != null && p.longitude != null)
        .map(
          (p) => MapMarkerData(
            id: p.placeId ?? p.hotelId ?? p.name,
            title: p.name,
            latitude: p.latitude!,
            longitude: p.longitude!,
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${course.region} 코스'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: '삭제',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RouteSummaryCard(
                isRoundTrip: course.isRoundTrip,
                transportMode: course.transportMode,
                totalDurationSec: course.totalDurationSec,
                totalDistanceM: course.totalDistanceM,
                routeData: course.routeData,
              ),
              if (routeMarkers.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 320,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: mapRepository.buildMap(
                      initialLatitude: routeMarkers.first.latitude,
                      initialLongitude: routeMarkers.first.longitude,
                      markers: routeMarkers,
                      drawRoutePolyline: true,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
