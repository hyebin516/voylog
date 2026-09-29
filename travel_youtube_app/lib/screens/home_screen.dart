import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/api_exception.dart';
import '../models/place_model.dart';
import '../models/saved_walking_course_model.dart';
import '../models/shared_route_model.dart';
import '../models/similar_taste_recommendation_model.dart';
import '../providers/app_shell_provider.dart';
import '../providers/recommendation_wizard_provider.dart';
import '../providers/saved_walking_course_provider.dart';
import '../providers/shared_route_provider.dart';
import '../providers/similar_taste_provider.dart';
import '../providers/video_provider.dart';
import '../repositories/itinerary_repository.dart';
import '../repositories/trip_repository.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/app_card.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/dashed_border_container.dart';
import '../widgets/error_view.dart';
import '../widgets/nav_icons.dart';
import '../widgets/saved_routes_fab.dart';
import '../utils/place_category_label.dart';

/// Avatar tints for feed authors: the handoff pairs each background with a
/// matching ink, rather than putting one fixed colour on every tint.
class _AuthorPalette {
  const _AuthorPalette(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

const List<_AuthorPalette> _authorPalettes = [
  _AuthorPalette(AppColors.surfaceTint3Alt, AppColors.primary),
  _AuthorPalette(Color(0xFFFDF1EE), AppColors.accentCoral),
  _AuthorPalette(Color(0xFFEFF6E7), Color(0xFF5F8A3A)),
  _AuthorPalette(Color(0xFFF3EEFB), Color(0xFF7059A6)),
];

const Map<String, String> _transportModeLabels = {
  'car': '차 이동',
  'walk': '도보',
  'transit': '대중교통',
  // A bookmark-folder route (FR-11): short legs walked, long ones by bus.
  'mixed': '도보·버스',
};

String _formatSharedRouteMeta(SharedRouteModel route) {
  final transportLabel = _transportModeLabels[route.transportMode] ?? route.transportMode;
  return '장소 ${route.placeCount}곳 · $transportLabel';
}

const List<String> _homeHashtags = ['#제주도', '#부산여행', '#서울맛집', '#강릉바다', '#경주'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  String? _inputError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SimilarTasteProvider>().load();
      context.read<SharedRouteProvider>().load();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
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
      // The result belongs to the 분석 tab, not on top of 홈: the user
      // asked for 홈 to stay free for the next video while the analysis
      // they just ran keeps its own place to come back to.
      _urlController.clear();
      context.read<AppShellProvider>().goToTab(AppShellProvider.analysisTab);
    }
  }

  Future<void> _onHashtagTap(VideoProvider videoProvider, String tag) async {
    // A hand-typed tag may or may not carry the '#', and the search API
    // wants the bare word either way.
    final hashtag = tag.trim().replaceFirst(RegExp(r'^#+'), '').trim();
    if (hashtag.isEmpty) return;

    await videoProvider.searchByHashtag(hashtag);
    if (!mounted) return;
    Navigator.pushNamed(context, AppRoutes.recommendationResults);
  }

  void _onSeeMoreHashtags() {
    context.read<RecommendationWizardProvider>().reset();
    Navigator.pushNamed(context, AppRoutes.recommendationRegion);
  }

  void _onSimilarTastePlaceTap(SimilarTasteRecommendationModel rec) {
    final place = PlaceModel(
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
    Navigator.pushNamed(context, AppRoutes.placeDetail, arguments: place);
  }

  void _openShareRouteSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => const _ShareRouteSheet(),
    );
  }

  Future<void> _editSharedRouteTitle(SharedRouteModel route) async {
    final controller = TextEditingController(text: route.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('동선 제목 수정'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: const Text('저장')),
        ],
      ),
    );
    if (newTitle == null || newTitle.trim().isEmpty || !mounted) return;

    final ok = await context.read<SharedRouteProvider>().updateTitle(route.sharedRouteId, newTitle.trim());
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제목을 수정하지 못했어요. 잠시 후 다시 시도해 주세요.')));
  }

  Future<void> _unpublishSharedRoute(SharedRouteModel route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('게시 취소'),
        content: Text('"${route.title}" 동선을 더 이상 공개하지 않을까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('게시 취소', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await context.read<SharedRouteProvider>().unpublish(route.sharedRouteId);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('게시 취소에 실패했어요. 잠시 후 다시 시도해 주세요.')));
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();
    final similarTaste = context.watch<SimilarTasteProvider>();
    final sharedRoute = context.watch<SharedRouteProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surfacePage,
      floatingActionButton: SavedRoutesFab(onPressed: () => Navigator.pushNamed(context, AppRoutes.savedWalkingCourses)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeHeader(
              controller: _urlController,
              isAnalyzing: videoProvider.isLoading,
              onAnalyze: () => _onAnalyzePressed(videoProvider),
            ),
            // The white sheet rides 26px up over the gradient so its rounded
            // corners sit on colour rather than on the page. Transform
            // doesn't take part in layout, so the 26px it leaves behind ends
            // up at the very bottom of the scroll, where the trailing
            // padding below absorbs it.
            Transform.translate(
              offset: const Offset(0, -26),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surfacePage,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                ),
                // Bottom padding must clear the fixed `SavedRoutesFab`, which
                // doesn't scroll with this content: whatever ends up last
                // (currently "내 동선 추천하기") needs enough trailing space
                // that it can never land underneath the FAB's ~72dp
                // footprint. 96 measured out to only ~27dp of real clearance
                // on a device, so a tap meant for the button hit the FAB.
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 190),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_inputError != null) ...[
                      Text(_inputError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (videoProvider.state == ViewState.error) ...[
                      ErrorView(
                        message: videoProvider.errorMessage ?? '분석에 실패했습니다.',
                        onRetry: () => _onAnalyzePressed(videoProvider),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_rounded, size: 16, color: AppColors.warningIcon),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '현재는 국내 여행 브이로그만 분석이 가능해요',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warningText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // v1 had these two side by side as cards; v2 makes them
                    // full-width rows with a divider between.
                    _EntryRow(
                      glyph: const LocationPinGlyphIcon(size: 17, color: AppColors.primaryChip),
                      label: '내 주변 추천',
                      caption: '지금 근처 갈 만한 곳',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.nearbyRecommendations),
                    ),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFE5EEEE)),
                    _EntryRow(
                      glyph: const WalkingGlyphIcon(size: 17, color: Color(0xFF2F6B5C)),
                      label: '뚜벅이 코스',
                      caption: '걸어서 도는 코스',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.walkingCourseRegion),
                    ),
                    const SizedBox(height: 26),
                    _SectionHeading(
                      title: '해시태그로 브이로그 찾아보기',
                      actionLabel: '더보기',
                      onActionTap: _onSeeMoreHashtags,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in _homeHashtags)
                          GestureDetector(
                            onTap: () => _onHashtagTap(videoProvider, tag),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHashtag,
                                border: Border.all(color: AppColors.inputBorder),
                                borderRadius: BorderRadius.circular(AppRadius.xs),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryChip,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (similarTaste.result?.hasPreference == true &&
                        (similarTaste.result?.recommendations.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 26),
                      _SectionHeading(
                        title: '취향이 비슷한 사람들의 북마크',
                        actionLabel: '전체보기',
                        onActionTap: () => Navigator.pushNamed(context, AppRoutes.similarTasteRecommendations),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '나와 취향 일치율이 높은 사용자가 저장한 장소예요',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      // Full-bleed carousel: the negative padding undoes the
                      // sheet's 24px side padding so cards run to the edge.
                      SizedBox(
                        height: 92,
                        child: OverflowBox(
                          maxWidth: MediaQuery.sizeOf(context).width,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: similarTaste.result!.recommendations.length.clamp(0, 5),
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final rec = similarTaste.result!.recommendations[i];
                              return SizedBox(
                                width: 272,
                                child: _SimilarTastePlaceCard(
                                  rec: rec,
                                  onTap: () => _onSimilarTastePlaceTap(rec),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    Text(
                      '다른 유저의 추천 동선',
                      style: textTheme.titleSmall?.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '직접 다녀오고 좋았던 동선을 공유한 사람들이에요',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    if (sharedRoute.isLoading && sharedRoute.routes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else if (sharedRoute.routes.isEmpty)
                      const Text('아직 공유된 동선이 없어요', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted))
                    else
                      for (final route in sharedRoute.routes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SharedRouteCard(
                            route: route,
                            onTap: () => Navigator.pushNamed(context, AppRoutes.sharedRouteDetail, arguments: route),
                            onLikeTap: () => context.read<SharedRouteProvider>().toggleLike(route.sharedRouteId),
                            onEditTap: () => _editSharedRouteTitle(route),
                            onDeleteTap: () => _unpublishSharedRoute(route),
                          ),
                        ),
                    GestureDetector(
                      onTap: _openShareRouteSheet,
                      child: DashedBorderContainer(
                        backgroundColor: AppColors.surfaceTint1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add_rounded, size: 15, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('내 동선 추천하기', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The gradient top of the home screen: headline, one-line pitch, and the
/// link card that starts an analysis.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.controller,
    required this.isAnalyzing,
    required this.onAnalyze,
  });

  final TextEditingController controller;
  final bool isAnalyzing;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.homeHeaderGradient),
      padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 24, 24, 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '영상 한 편이면,\n여행 동선 완성',
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: -0.8,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'YouTube 링크만 붙여넣으세요.\n장소 추출부터 동선까지 AI가 해드려요',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.6,
              letterSpacing: -0.3,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 26),
          // A translucent ring around the white card, as in the handoff.
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 7, 7, 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(21),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00323C).withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const LinkGlyphIcon(size: 18, color: AppColors.primaryChip),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('urlField'),
                      controller: controller,
                      keyboardType: TextInputType.url,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: -0.3),
                      decoration: const InputDecoration(
                        hintText: 'YouTube 링크 붙여넣기',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    key: const Key('analyzeButton'),
                    onTap: onAnalyze,
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryStrong,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: isAnalyzing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '분석하기',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A section title with an optional action on the right ("더보기" /
/// "전체보기"), which v2 moves up out of the content below it.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.actionLabel, this.onActionTap});

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: AppColors.ink),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryChip),
            ),
          ),
      ],
    );
  }
}

/// One of the two full-width entry rows under the banner (내 주변 추천 /
/// 뚜벅이 코스). v1 drew these as a pair of side-by-side cards.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.glyph, required this.label, required this.caption, required this.onTap});

  final Widget glyph;
  final String label;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Color(0xFFE6F4F3), shape: BoxShape.circle),
              child: glyph,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF9FB2B5)),
          ],
        ),
      ),
    );
  }
}



class _SimilarTastePlaceCard extends StatelessWidget {
  const _SimilarTastePlaceCard({required this.rec, required this.onTap});

  final SimilarTasteRecommendationModel rec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final matchPercent = (rec.score.clamp(0, 1) * 100).round();

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [AppColors.surfaceSoft, AppColors.surfaceTint3Alt]),
            ),
            child: const Icon(Icons.image_outlined, size: 20, color: AppColors.textTertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(rec.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                if (placeCategoryLabel(rec.category) != null) ...[
                  const SizedBox(height: 4),
                  Text(placeCategoryLabel(rec.category)!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.surfaceTint3Alt, borderRadius: BorderRadius.circular(999)),
                      child: Text('취향 일치 $matchPercent%', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primaryStrong)),
                    ),
                    const SizedBox(width: 6),
                    Text('${rec.contributorCount}명이 저장', style: const TextStyle(fontSize: 11, color: AppColors.textMuted2)),
                  ],
                ),
              ],
            ),
          ),
          BookmarkButton(placeId: rec.placeId),
        ],
      ),
    );
  }
}

class _SharedRouteCard extends StatelessWidget {
  const _SharedRouteCard({
    required this.route,
    required this.onTap,
    required this.onLikeTap,
    required this.onEditTap,
    required this.onDeleteTap,
  });

  final SharedRouteModel route;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;

  @override
  Widget build(BuildContext context) {
    final authorName = route.authorNickname ?? '알 수 없음';
    final authorInitial = authorName.characters.isEmpty ? '?' : authorName.characters.first;
    final palette = _authorPalettes[authorName.hashCode.abs() % _authorPalettes.length];
    final isOwner = route.isOwner;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      // Your own post is marked out by the emphasis border, not only by a
      // label. It also keeps the stronger `sh-card` shadow.
      borderColor: isOwner ? AppColors.selectedBorder : null,
      shadow: isOwner ? AppColors.cardShadow() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Author row: avatar, name, then either the "내 추천" badge or the
          // like button at the far end.
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isOwner ? AppColors.primary : palette.background,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  authorInitial,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isOwner ? Colors.white : palette.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  authorName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint3,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text(
                    '내 추천',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                )
              else
                GestureDetector(
                  onTap: onLikeTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    child: Row(
                      children: [
                        HeartGlyphIcon(
                          size: 16,
                          filled: route.likedByMe,
                          // An unliked heart is an outline in the muted text
                          // colour; only a liked one goes red.
                          color: route.likedByMe ? AppColors.danger : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${route.likeCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: route.likedByMe ? AppColors.danger : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Title row: on your own card the edit/delete buttons sit here,
          // beside the title and under the "내 추천" badge.
          Row(
            children: [
              Expanded(
                child: Text(
                  route.title,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOwner) ...[
                const SizedBox(width: 6),
                _CardIconButton(
                  glyph: const PencilGlyphIcon(size: 15, color: AppColors.primary),
                  background: AppColors.surfaceTint2,
                  tooltip: '제목 수정',
                  onTap: onEditTap,
                ),
                const SizedBox(width: 6),
                _CardIconButton(
                  glyph: const TrashGlyphIcon(size: 15, color: AppColors.danger),
                  background: AppColors.dangerBg,
                  tooltip: '추천 취소',
                  onTap: onDeleteTap,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatSharedRouteMeta(route),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted),
          ),
          if (route.matchPercent != null) ...[
            const SizedBox(height: 10),
            // A chip in the row the handoff fills with mood tags. We have no
            // such tags -- nothing in the data backs them -- so the match
            // percentage stands alone here.
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint2,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '취향 일치 ${route.matchPercent}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The 30x30 boxed buttons on your own feed card (제목 수정 / 추천 취소).
class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.glyph,
    required this.background,
    required this.tooltip,
    required this.onTap,
  });

  final Widget glyph;
  final Color background;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.xxs),
          ),
          child: glyph,
        ),
      ),
    );
  }
}

/// A trip day-itinerary flattened to just what the publish picker needs to
/// show/publish -- built client-side from `TripRepository.listTrips()` +
/// one `getTrip()` per trip (no bulk "all my itineraries" endpoint exists),
/// since `TripProvider`'s state model only tracks one `currentTrip` at a
/// time and calling `loadTrip()` per trip would clobber it. Instantiating
/// `TripRepository()` directly (bypassing Provider) for a one-shot,
/// screen-local fetch mirrors the existing `PlaceSummaryRepository()` call
/// in `video_analysis_screen.dart`.
class _PublishableItinerary {
  const _PublishableItinerary({
    required this.itineraryId,
    required this.tripName,
    required this.dayNumber,
    required this.transportMode,
    required this.placeCount,
  });

  final String itineraryId;
  final String tripName;
  final int dayNumber;
  final String transportMode;
  final int placeCount;

  String get defaultTitle => '$tripName $dayNumber일차';
}

/// "내 동선 추천하기" bottom sheet -- lets the user pick one of their own
/// saved walking courses (FR-17) or a trip's day itinerary (FR-07) to
/// publish to the shared-route feed (FR-21).
class _ShareRouteSheet extends StatefulWidget {
  const _ShareRouteSheet();

  @override
  State<_ShareRouteSheet> createState() => _ShareRouteSheetState();
}

class _ShareRouteSheetState extends State<_ShareRouteSheet> {
  String? _publishingCourseId;
  String? _publishingItineraryId;

  List<_PublishableItinerary>? _itineraries;
  bool _itinerariesFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavedWalkingCourseProvider>().loadCourses();
      _loadItineraries();
    });
  }

  Future<void> _loadItineraries() async {
    try {
      final trips = await TripRepository().listTrips();
      final details = await Future.wait(trips.map((t) => TripRepository().getTrip(t.tripId)));
      final itineraries = <_PublishableItinerary>[
        for (final trip in details)
          for (final day in trip.days)
            _PublishableItinerary(
              itineraryId: day.itineraryId,
              tripName: trip.name,
              dayNumber: day.dayNumber,
              transportMode: day.transportMode,
              placeCount: day.routeData.where((p) => !p.isHotel).length,
            ),
      ];
      if (!mounted) return;
      setState(() => _itineraries = itineraries);
    } catch (_) {
      if (!mounted) return;
      setState(() => _itinerariesFailed = true);
    }
  }

  Future<String?> _promptForTitle(String defaultTitle) {
    final controller = TextEditingController(text: defaultTitle);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('동선 제목'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 제주 서쪽 카페 코스'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: const Text('공유하기')),
        ],
      ),
    );
  }

  Future<void> _publishCourse(SavedWalkingCourseModel course) async {
    final title = await _promptForTitle(course.region);
    if (title == null || title.trim().isEmpty || !mounted) return;

    setState(() => _publishingCourseId = course.savedCourseId);
    final ok = await context.read<SavedWalkingCourseProvider>().publishCourse(
          savedCourseId: course.savedCourseId,
          title: title.trim(),
        );
    if (!mounted) return;
    setState(() => _publishingCourseId = null);
    _handlePublishResult(ok, errorMessage: context.read<SavedWalkingCourseProvider>().errorMessage);
  }

  Future<void> _publishItinerary(_PublishableItinerary itinerary) async {
    final title = await _promptForTitle(itinerary.defaultTitle);
    if (title == null || title.trim().isEmpty || !mounted) return;

    setState(() => _publishingItineraryId = itinerary.itineraryId);
    bool ok;
    String? errorMessage;
    try {
      await ItineraryRepository().publish(itineraryId: itinerary.itineraryId, title: title.trim());
      ok = true;
    } on ApiException catch (e) {
      ok = false;
      errorMessage = e.friendlyMessage;
    }
    if (!mounted) return;
    setState(() => _publishingItineraryId = null);
    _handlePublishResult(ok, errorMessage: errorMessage);
  }

  void _handlePublishResult(bool ok, {String? errorMessage}) {
    if (ok) {
      Navigator.of(context).pop();
      context.read<SharedRouteProvider>().load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('동선이 공유됐어요.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage ?? '공유에 실패했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<SavedWalkingCourseProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: AppColors.dividerStrong, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text('내 동선 추천하기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.surfaceTint2, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('추천할 동선을 고르면 다른 유저에게 공개돼요', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('저장한 뚜벅이 코스', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    if (courseProvider.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else if (courseProvider.courses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          '아직 저장한 뚜벅이 코스가 없어요.',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      )
                    else
                      for (var i = 0; i < courseProvider.courses.length; i++) ...[
                        Builder(builder: (context) {
                          final course = courseProvider.courses[i];
                          final isPublishing = _publishingCourseId == course.savedCourseId;
                          return _SavedCoursePickerRow(
                            course: course,
                            isPublishing: isPublishing,
                            onTap: isPublishing ? null : () => _publishCourse(course),
                          );
                        }),
                        if (i < courseProvider.courses.length - 1) const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 20),
                    const Text('여행 동선', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    if (_itineraries == null && !_itinerariesFailed)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else if (_itinerariesFailed)
                      const Text(
                        '여행 동선을 불러오지 못했어요.',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      )
                    else if (_itineraries!.isEmpty)
                      const Text(
                        '아직 만든 여행 동선이 없어요.',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      )
                    else
                      for (var i = 0; i < _itineraries!.length; i++) ...[
                        Builder(builder: (context) {
                          final itinerary = _itineraries![i];
                          final isPublishing = _publishingItineraryId == itinerary.itineraryId;
                          return _ItineraryPickerRow(
                            itinerary: itinerary,
                            isPublishing: isPublishing,
                            onTap: isPublishing ? null : () => _publishItinerary(itinerary),
                          );
                        }),
                        if (i < _itineraries!.length - 1) const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItineraryPickerRow extends StatelessWidget {
  const _ItineraryPickerRow({required this.itinerary, required this.isPublishing, required this.onTap});

  final _PublishableItinerary itinerary;
  final bool isPublishing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final transportLabel = _transportModeLabels[itinerary.transportMode] ?? itinerary.transportMode;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${itinerary.tripName} · ${itinerary.dayNumber}일차',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text('장소 ${itinerary.placeCount}곳 · $transportLabel', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (isPublishing)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            const Icon(Icons.ios_share_rounded, size: 16, color: AppColors.primaryStrong),
        ],
      ),
    );
  }
}

class _SavedCoursePickerRow extends StatelessWidget {
  const _SavedCoursePickerRow({required this.course, required this.isPublishing, required this.onTap});

  final SavedWalkingCourseModel course;
  final bool isPublishing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final placeCount = course.routeData.where((p) => p.type == 'place').length;
    final transportLabel = _transportModeLabels[course.transportMode] ?? course.transportMode;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(course.region, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text('장소 $placeCount곳 · $transportLabel', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (isPublishing)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            const Icon(Icons.ios_share_rounded, size: 16, color: AppColors.primaryStrong),
        ],
      ),
    );
  }
}
