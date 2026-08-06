import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/video_search_result_model.dart';
import '../providers/video_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/responsive_center.dart';
import '../widgets/video_search_result_card.dart';

class RecommendationResultsScreen extends StatelessWidget {
  const RecommendationResultsScreen({super.key});

  Future<void> _onResultTap(BuildContext context, VideoProvider videoProvider, VideoSearchResultModel result) async {
    await videoProvider.analyze(result.youtubeUrl);

    if (!context.mounted) return;
    if (videoProvider.state == ViewState.success) {
      Navigator.pushNamed(context, AppRoutes.videoAnalysis);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('추천 브이로그')),
      body: ResponsiveCenter(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Builder(
          builder: (context) {
            if (videoProvider.isSearching) {
              return const LoadingIndicator();
            }
            if (videoProvider.searchState == ViewState.error) {
              return ErrorView(
                message: videoProvider.searchErrorMessage ?? '추천을 불러오지 못했습니다.',
              );
            }
            if (videoProvider.searchResults.isEmpty) {
              return const Center(child: Text('조건에 맞는 추천 영상이 없습니다.'));
            }
            return ListView.builder(
              itemCount: videoProvider.searchResults.length,
              itemBuilder: (context, index) {
                final result = videoProvider.searchResults[index];
                return VideoSearchResultCard(
                  result: result,
                  onTap: () => _onResultTap(context, videoProvider, result),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
