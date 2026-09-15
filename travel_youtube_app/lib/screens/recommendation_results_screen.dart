import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/video_search_result_model.dart';
import '../providers/recommendation_wizard_provider.dart';
import '../providers/video_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/responsive_center.dart';
import '../widgets/video_search_result_card.dart';

class RecommendationResultsScreen extends StatelessWidget {
  const RecommendationResultsScreen({super.key});

  Future<void> _onResultTap(
    BuildContext context,
    VideoProvider videoProvider,
    VideoSearchResultModel result,
  ) async {
    await videoProvider.analyze(result.youtubeUrl);

    if (!context.mounted) return;
    if (videoProvider.state == ViewState.success) {
      Navigator.pushNamed(context, AppRoutes.videoAnalysis);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final wizard = context.watch<RecommendationWizardProvider>();
    final filterTags = [
      ...wizard.selectedRegions,
      ...wizard.selectedThemes,
      if (wizard.selectedDuration != null) wizard.selectedDuration!,
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
                  const Text(
                    '추천 브이로그',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (filterTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: ResponsiveCenter(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in filterTags)
                          Text(
                            '#${tag.replaceAll(' ', '')}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryStrong,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ResponsiveCenter(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Builder(
                  builder: (context) {
                    if (videoProvider.isSearching) {
                      return const LoadingIndicator();
                    }
                    if (videoProvider.searchState == ViewState.error) {
                      return ErrorView(
                        message:
                            videoProvider.searchErrorMessage ??
                            '추천을 불러오지 못했습니다.',
                      );
                    }
                    if (videoProvider.searchResults.isEmpty) {
                      return const Center(
                        child: Text(
                          '조건에 맞는 추천 영상이 없습니다.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: videoProvider.searchResults.length,
                            itemBuilder: (context, index) {
                              final result = videoProvider.searchResults[index];
                              return VideoSearchResultCard(
                                result: result,
                                onTap: () => _onResultTap(
                                  context,
                                  videoProvider,
                                  result,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst),
                            child: const Text(
                              '홈으로 돌아가기',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
