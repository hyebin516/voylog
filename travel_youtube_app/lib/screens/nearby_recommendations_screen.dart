import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/nearby_recommendation_model.dart';
import '../providers/location_provider.dart';
import '../providers/recommendation_provider.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';

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
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(rec.name, style: Theme.of(context).textTheme.titleMedium),
                            ),
                            if (rec.isOpen != null)
                              Chip(
                                label: Text(rec.isOpen! ? '영업중' : '영업종료', style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: rec.isOpen!
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(rec.reason, style: Theme.of(context).textTheme.bodySmall),
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
