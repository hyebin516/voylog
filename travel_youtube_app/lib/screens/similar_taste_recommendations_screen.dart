import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/place_model.dart';
import '../models/similar_taste_recommendation_model.dart';
import '../providers/similar_taste_provider.dart';
import '../providers/taste_preference_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/app_card.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/primary_button.dart';

PlaceModel _toPlaceModel(SimilarTasteRecommendationModel rec) {
  return PlaceModel(
    placeId: rec.placeId,
    name: rec.name,
    timestampSec: null,
    latitude: rec.latitude,
    longitude: rec.longitude,
    address: rec.address,
    source: 'similar-taste',
    confidence: 1.0,
    category: rec.category,
  );
}

class SimilarTasteRecommendationsScreen extends StatefulWidget {
  const SimilarTasteRecommendationsScreen({super.key});

  @override
  State<SimilarTasteRecommendationsScreen> createState() => _SimilarTasteRecommendationsScreenState();
}

class _SimilarTasteRecommendationsScreenState extends State<SimilarTasteRecommendationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SimilarTasteProvider>().load();
      context.read<TastePreferenceProvider>().loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SimilarTasteProvider>();

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
                      decoration: BoxDecoration(color: AppColors.surfaceTint2, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('취향 맞춤 추천', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ],
              ),
            ),
            Expanded(
              child: Builder(
        builder: (context) {
          if (provider.isLoading && provider.result == null) {
            return const LoadingIndicator();
          }
          if (provider.state == ViewState.error) {
            return ErrorView(
              message: provider.errorMessage ?? '추천을 불러오지 못했습니다.',
              onRetry: () => provider.load(),
            );
          }

          final result = provider.result;
          if (result == null) return const SizedBox.shrink();

          if (!result.hasPreference) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '취향 설정을 하면 나와 비슷한 취향의 사용자가 북마크한 장소를 추천받을 수 있어요.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: '취향 설정하러 가기',
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.tastePreferences),
                    ),
                  ],
                ),
              ),
            );
          }

          if (result.recommendations.isEmpty) {
            return const Center(child: Text('아직 비슷한 취향의 사용자가 없어요.'));
          }

          final myTags = context.watch<TastePreferenceProvider>().selectedTags;

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: result.recommendations.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '비슷한 취향의 여행자들이\n많이 저장한 곳이에요',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.3),
                      ),
                      if (myTags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tag in myTags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: AppColors.surfaceTint2, borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              }
              final SimilarTasteRecommendationModel rec = result.recommendations[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.placeDetail, arguments: _toPlaceModel(rec)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(rec.name, style: Theme.of(context).textTheme.titleMedium)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceTint2,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_alt_rounded, size: 13, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${rec.contributorCount}명',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          BookmarkButton(placeId: rec.placeId),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(rec.reason, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
            ),
          ],
        ),
      ),
    );
  }
}
