import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/nearby_recommendation_model.dart';
import '../models/place_model.dart';
import '../providers/location_provider.dart';
import '../providers/recommendation_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/app_card.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/tag_chip.dart';

PlaceModel _toPlaceModel(NearbyRecommendationModel rec) {
  return PlaceModel(
    placeId: rec.placeId,
    name: rec.name,
    timestampSec: null,
    latitude: rec.latitude,
    longitude: rec.longitude,
    address: null,
    source: 'nearby',
    confidence: 1.0,
  );
}

class NearbyRecommendationsScreen extends StatefulWidget {
  const NearbyRecommendationsScreen({super.key});

  @override
  State<NearbyRecommendationsScreen> createState() => _NearbyRecommendationsScreenState();
}

class _NearbyRecommendationsScreenState extends State<NearbyRecommendationsScreen> {
  late final LocationProvider _locationProvider;

  @override
  void initState() {
    super.initState();
    _locationProvider = context.read<LocationProvider>();
    _locationProvider.addListener(_onLocationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _locationProvider.start());
  }

  void _onLocationChanged() {
    final location = _locationProvider.currentLocation;
    if (location == null) return;
    context.read<RecommendationProvider>().loadNearby(latitude: location.latitude, longitude: location.longitude);
  }

  @override
  void dispose() {
    _locationProvider.removeListener(_onLocationChanged);
    _locationProvider.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final recommendationProvider = context.watch<RecommendationProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('내 주변 추천')),
      body: Builder(
        builder: (context) {
          if (locationProvider.state == ViewState.error) {
            return ErrorView(
              message: locationProvider.errorMessage ?? '위치를 확인할 수 없습니다.',
              onRetry: () => locationProvider.start(),
            );
          }
          if (locationProvider.isLoading && locationProvider.currentLocation == null) {
            return const LoadingIndicator();
          }
          if (recommendationProvider.isLoading && recommendationProvider.recommendations.isEmpty) {
            return const LoadingIndicator();
          }
          if (recommendationProvider.state == ViewState.error) {
            return ErrorView(
              message: recommendationProvider.errorMessage ?? '추천을 불러오지 못했습니다.',
              onRetry: () {
                final location = locationProvider.currentLocation;
                if (location != null) {
                  recommendationProvider.loadNearby(latitude: location.latitude, longitude: location.longitude);
                }
              },
            );
          }
          if (recommendationProvider.state == ViewState.success && recommendationProvider.recommendations.isEmpty) {
            return const Center(child: Text('주변에 추천할 장소가 없습니다.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: recommendationProvider.recommendations.length,
            itemBuilder: (context, index) {
              final NearbyRecommendationModel rec = recommendationProvider.recommendations[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () {
                    recommendationProvider.recordViewDetail(rec);
                    Navigator.pushNamed(context, AppRoutes.placeDetail, arguments: _toPlaceModel(rec));
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(rec.name, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          if (rec.isOpen != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: rec.isOpen! ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                rec.isOpen! ? '영업중' : '영업종료',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: rec.isOpen! ? AppColors.primary : AppColors.ink.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          BookmarkButton(
                            placeId: rec.placeId,
                            onBookmarked: () => recommendationProvider.recordBookmark(rec),
                          ),
                          IconButton(
                            onPressed: () => recommendationProvider.markNotInterested(rec),
                            icon: const Icon(Icons.visibility_off_outlined),
                            tooltip: '관심 없음',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(rec.reason, style: Theme.of(context).textTheme.bodySmall),
                      if (rec.matchedTags.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [for (final tag in rec.matchedTags) TagChip(label: tag)],
                        ),
                      ],
                      if (rec.isOpen != null && rec.isOpenEstimated) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '* 영업시간은 영상 정보 기반 추정치예요.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
