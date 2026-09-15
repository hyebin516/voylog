import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/nearby_recommendation_model.dart';
import '../models/place_model.dart';
import '../providers/location_provider.dart';
import '../providers/recommendation_provider.dart';
import '../repositories/map_repository.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/app_card.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/data_source_attribution.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/nav_icons.dart';
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
  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const NearbyRecommendationsScreen({super.key, this.mapRepository = const KakaoMapRepository()});

  @override
  State<NearbyRecommendationsScreen> createState() =>
      _NearbyRecommendationsScreenState();
}

class _NearbyRecommendationsScreenState
    extends State<NearbyRecommendationsScreen> {
  late final LocationProvider _locationProvider;

  @override
  void initState() {
    super.initState();
    _locationProvider = context.read<LocationProvider>();
    _locationProvider.addListener(_onLocationChanged);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _locationProvider.start(),
    );
  }

  void _onLocationChanged() {
    final location = _locationProvider.currentLocation;
    if (location == null) return;
    context.read<RecommendationProvider>().loadNearby(
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  @override
  void dispose() {
    _locationProvider.removeListener(_onLocationChanged);
    _locationProvider.stop();
    super.dispose();
  }

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
                    '내 주변 추천',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _NearbyRecommendationsBody(mapRepository: widget.mapRepository)),
          ],
        ),
      ),
    );
  }
}

// Filter pill label -> the backend's categoryGroup (null = all). Which
// categories belong to each group is decided on the server.
const Map<String, String?> _nearbyFilterGroups = {
  '전체 추천': null,
  '음식점': 'restaurant',
  '카페': 'cafe',
  '놀거리': 'play',
};

class _NearbyRecommendationsBody extends StatefulWidget {
  const _NearbyRecommendationsBody({required this.mapRepository});

  final MapRepository mapRepository;

  @override
  State<_NearbyRecommendationsBody> createState() =>
      _NearbyRecommendationsBodyState();
}

class _NearbyRecommendationsBodyState
    extends State<_NearbyRecommendationsBody> {

  void _showOnMap(RecommendationProvider provider, NearbyRecommendationModel rec) {
    provider.recordMapView(rec);
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
              Text(rec.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: widget.mapRepository.buildMap(
                    initialLatitude: rec.latitude,
                    initialLongitude: rec.longitude,
                    markers: [
                      MapMarkerData(
                        id: rec.placeId,
                        title: rec.name,
                        latitude: rec.latitude,
                        longitude: rec.longitude,
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
    final locationProvider = context.watch<LocationProvider>();
    final recommendationProvider = context.watch<RecommendationProvider>();

    return Builder(
      builder: (context) {
        if (locationProvider.state == ViewState.error) {
          return ErrorView(
            message: locationProvider.errorMessage ?? '위치를 확인할 수 없습니다.',
            onRetry: () => locationProvider.start(),
          );
        }
        if (locationProvider.isLoading &&
            locationProvider.currentLocation == null) {
          return const LoadingIndicator();
        }
        final recommendations = recommendationProvider.recommendations;
        final selectedGroup = recommendationProvider.categoryGroup;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  for (final entry in _nearbyFilterGroups.entries) ...[
                    Expanded(
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(entry.key, textAlign: TextAlign.center),
                        ),
                        selected: selectedGroup == entry.value,
                        // The design's pills have no checkmark, and with one
                        // "전체 추천" didn't fit its quarter-width pill.
                        showCheckmark: false,
                        // The default side padding also left too little room;
                        // the design centers the label with none.
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        labelPadding: EdgeInsets.zero,
                        onSelected: (_) => recommendationProvider
                            .selectCategoryGroup(entry.value),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selectedGroup == entry.value
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (entry.key != _nearbyFilterGroups.keys.last)
                      const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            Expanded(
              // Loading/error/empty live under the tabs, so an empty tab never
              // hides the tabs needed to leave it.
              child: recommendationProvider.isLoading && recommendations.isEmpty
                  ? const LoadingIndicator()
                  : recommendationProvider.state == ViewState.error
                  ? ErrorView(
                      message:
                          recommendationProvider.errorMessage ??
                          '추천을 불러오지 못했습니다.',
                      onRetry: () {
                        final location = locationProvider.currentLocation;
                        if (location != null) {
                          recommendationProvider.loadNearby(
                            latitude: location.latitude,
                            longitude: location.longitude,
                          );
                        }
                      },
                    )
                  : recommendations.isEmpty
                  ? Center(
                      child: Text(
                        selectedGroup == null
                            ? '주변에 추천할 장소가 없습니다.'
                            : '해당 카테고리의 추천 장소가 없습니다.',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      // +1 for the public-data source credit after the list.
                      itemCount: recommendations.length + 1,
                      itemBuilder: (context, index) {
                        if (index == recommendations.length) {
                          return const DataSourceAttribution();
                        }
                        final NearbyRecommendationModel rec =
                            recommendations[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            onTap: () {
                              recommendationProvider.recordViewDetail(rec);
                              Navigator.pushNamed(
                                context,
                                AppRoutes.placeDetail,
                                arguments: _toPlaceModel(rec),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rec.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    if (rec.isOpen != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: rec.isOpen!
                                              ? const Color(0xFF5FC2A0)
                                              : AppColors.surfaceTint2,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          rec.isOpen! ? '영업중' : '영업종료',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: rec.isOpen!
                                                ? Colors.white
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    IconButton(
                                      onPressed: () =>
                                          _showOnMap(recommendationProvider, rec),
                                      icon: const MapPinGlyphIcon(
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                      tooltip: '지도 보기',
                                    ),
                                    BookmarkButton(
                                      placeId: rec.placeId,
                                      onBookmarked: () => recommendationProvider
                                          .recordBookmark(rec),
                                    ),
                                    IconButton(
                                      onPressed: () => recommendationProvider
                                          .markNotInterested(rec),
                                      icon: const Icon(
                                        Icons.visibility_off_outlined,
                                      ),
                                      tooltip: '관심 없음',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  rec.reason,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (rec.matchedTags.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Wrap(
                                    spacing: AppSpacing.xs,
                                    runSpacing: AppSpacing.xs,
                                    children: [
                                      for (final tag in rec.matchedTags)
                                        TagChip(label: tag),
                                    ],
                                  ),
                                ],
                                if (rec.isOpen != null &&
                                    rec.isOpenEstimated) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '* 영업시간은 영상 정보 기반 추정치예요.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
