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
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';
import '../widgets/video_search_result_card.dart';
import '../widgets/voylog_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  String? _inputError;

  @override
  void dispose() {
    _urlController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  Future<void> _onAnalyzePressed(VideoProvider videoProvider) async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() => _inputError = 'URL을 먼저 입력해 주세요.');
      return;
    }
    setState(() => _inputError = null);

    await videoProvider.analyze(url);

    if (!mounted) return;
    if (videoProvider.state == ViewState.success) {
      Navigator.pushNamed(context, AppRoutes.videoAnalysis);
    }
  }

  void _onSearchPressed(VideoProvider videoProvider) {
    final hashtag = _hashtagController.text.trim();
    if (hashtag.isEmpty) return;
    videoProvider.searchByHashtag(hashtag);
  }

  Future<void> _onSearchResultTap(VideoProvider videoProvider, VideoSearchResultModel result) async {
    await videoProvider.analyze(result.youtubeUrl);

    if (!mounted) return;
    if (videoProvider.state == ViewState.success) {
      Navigator.pushNamed(context, AppRoutes.videoAnalysis);
    }
  }

  void _onRecommendationWizardPressed() {
    context.read<RecommendationWizardProvider>().reset();
    Navigator.pushNamed(context, AppRoutes.recommendationRegion);
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            VoylogLogoMark(size: 32),
            SizedBox(width: AppSpacing.sm),
            VoylogWordmark(fontSize: 18),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.near_me_outlined),
            tooltip: '내 주변 추천',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.nearbyRecommendations),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded),
            tooltip: '북마크',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.bookmarks),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: '마이페이지',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.myPage),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.tripList),
        tooltip: '내 여행',
        backgroundColor: AppColors.primary,
        shape: const StadiumBorder(),
        child: const Icon(Icons.map_rounded, color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '브이로그로 동선을\n만들어드려요',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '분석할 유튜브 영상 URL을 입력하세요',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.primary.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('urlField'),
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: '브이로그 URL을 붙여넣으세요',
                  errorText: _inputError,
                  prefixIcon: const Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: '분석하기',
                icon: Icons.auto_awesome_rounded,
                isLoading: videoProvider.isLoading,
                onPressed: () => _onAnalyzePressed(videoProvider),
              ),
              if (videoProvider.state == ViewState.error) ...[
                const SizedBox(height: AppSpacing.lg),
                ErrorView(
                  message: videoProvider.errorMessage ?? '분석에 실패했습니다.',
                  onRetry: () => _onAnalyzePressed(videoProvider),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Text('해시태그로 브이로그 탐색', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('hashtagField'),
                controller: _hashtagController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: '#부산여행',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                onSubmitted: (_) => _onSearchPressed(videoProvider),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: '탐색하기',
                icon: Icons.search_rounded,
                isLoading: videoProvider.isSearching,
                onPressed: () => _onSearchPressed(videoProvider),
              ),
              if (videoProvider.isSearching) ...[
                const SizedBox(height: AppSpacing.lg),
                const LoadingIndicator(),
              ] else if (videoProvider.searchState == ViewState.error) ...[
                const SizedBox(height: AppSpacing.lg),
                ErrorView(
                  message: videoProvider.searchErrorMessage ?? '탐색에 실패했습니다.',
                  onRetry: () => _onSearchPressed(videoProvider),
                ),
              ] else if (videoProvider.searchState == ViewState.success) ...[
                const SizedBox(height: AppSpacing.lg),
                if (videoProvider.searchResults.isEmpty)
                  const Text('검색 결과가 없습니다.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: videoProvider.searchResults.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final result = videoProvider.searchResults[index];
                      return VideoSearchResultCard(
                        result: result,
                        onTap: () => _onSearchResultTap(videoProvider, result),
                      );
                    },
                  ),
              ],
              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Text('지역/테마로 브이로그 추천받기', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                key: const Key('recommendationWizardButton'),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('추천 마법사 시작하기'),
                onPressed: _onRecommendationWizardPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
