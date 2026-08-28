import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/nearby_recommendation_model.dart';
import '../providers/walking_course_provider.dart';
import '../repositories/map_repository.dart';
import '../utils/view_state.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/responsive_center.dart';
import '../widgets/route_summary_card.dart';

class WalkingCourseResultScreen extends StatelessWidget {
  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const WalkingCourseResultScreen({super.key, this.mapRepository = const KakaoMapRepository()});

  void _retry(BuildContext context) {
    final provider = context.read<WalkingCourseProvider>();
    final region = provider.region;
    if (region != null) provider.generate(region);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalkingCourseProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(provider.region != null ? '${provider.region} 뚜벅이 코스' : '뚜벅이 코스')),
      body: Builder(
        builder: (context) {
          if (provider.isLoading) {
            return const LoadingIndicator(message: '코스를 만들고 있어요...');
          }
          if (provider.state == ViewState.error) {
            return ErrorView(
              message: provider.errorMessage ?? '코스를 만들지 못했습니다.',
              onRetry: () => _retry(context),
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

          return SingleChildScrollView(
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
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('추천 이유', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...result.recommendations.map((rec) => _RecommendationCard(recommendation: rec)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final NearbyRecommendationModel recommendation;

  const _RecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(recommendation.name, style: Theme.of(context).textTheme.titleMedium)),
                  // Kakao-sourced candidates ("kakao:...") aren't rows in
                  // our own `places` table, so there's no place_id a
                  // bookmark could reference yet -- only offer bookmarking
                  // for places that came from our own data.
                  if (!recommendation.placeId.startsWith('kakao:'))
                    BookmarkButton(placeId: recommendation.placeId),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(recommendation.reason, style: Theme.of(context).textTheme.bodySmall),
              if (recommendation.matchedTags.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final tag in recommendation.matchedTags)
                      Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
