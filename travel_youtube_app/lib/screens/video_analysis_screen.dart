import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/place_model.dart';
import '../models/place_summary_model.dart';
import '../providers/video_provider.dart';
import '../repositories/map_repository.dart';
import '../repositories/place_summary_repository.dart';
import '../repositories/video_player_repository.dart';
import '../routes/app_routes.dart';
import '../utils/timestamp_format.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/nav_icons.dart';
import '../utils/place_category_label.dart';

class VideoAnalysisScreen extends StatefulWidget {
  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  /// Defaults to the real WebView-backed YouTube player. Widget tests
  /// inject `FakeVideoPlayerRepository()` instead.
  final VideoPlayerRepository videoPlayerRepository;

  /// True when this is the 분석 tab's own content rather than a pushed
  /// screen: there's nothing to go back to, so the header offers "새 영상
  /// 분석" (which clears the result and brings the URL field back) in place
  /// of the back button.
  final bool isTabRoot;

  const VideoAnalysisScreen({
    super.key,
    this.mapRepository = const KakaoMapRepository(),
    this.videoPlayerRepository = const YoutubeIframePlayerRepository(),
    this.isTabRoot = false,
  });

  @override
  State<VideoAnalysisScreen> createState() => _VideoAnalysisScreenState();
}

class _VideoAnalysisScreenState extends State<VideoAnalysisScreen> {
  late final VideoPlayerInstance _player;

  @override
  void initState() {
    super.initState();
    final youtubeVideoId = context
        .read<VideoProvider>()
        .currentVideo
        ?.youtubeVideoId;
    _player = widget.videoPlayerRepository.createPlayer(youtubeVideoId);
  }

  @override
  void dispose() {
    _player.handle.dispose();
    super.dispose();
  }

  void _seekTo(int seconds) {
    _player.handle.seekTo(seconds);
  }

  Future<void> _openDetail(PlaceModel place) async {
    final seekTo = await Navigator.pushNamed(
      context,
      AppRoutes.placeDetail,
      arguments: place,
    );
    if (seekTo is int) {
      _seekTo(seekTo);
    }
  }

  void _showOnMap(PlaceModel place) {
    if (!place.hasCoordinates) return;

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
              Text(place.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: widget.mapRepository.buildMap(
                    initialLatitude: place.latitude!,
                    initialLongitude: place.longitude!,
                    markers: [
                      MapMarkerData(
                        id: place.placeId,
                        title: place.name,
                        latitude: place.latitude!,
                        longitude: place.longitude!,
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
    final video = context.watch<VideoProvider>().currentVideo;

    if (video == null) {
      return const Scaffold(body: LoadingIndicator());
    }

    return Scaffold(
      body: AuthBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    if (!widget.isTabRoot) ...[
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
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
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Text(
                      '동선 분석',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (widget.isTabRoot) ...[
                      const Spacer(),
                      TextButton.icon(
                        key: const Key('analyzeAnotherVideoButton'),
                        onPressed: () => context.read<VideoProvider>().reset(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('새 영상 분석'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _player.widget,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      video.title ?? '영상 분석 결과',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '등장 순서대로 정리된 장소 ${video.places.length}곳',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (video.enrichmentPending) ...[
                      const SizedBox(height: 8),
                      const _EnrichmentNotice(),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    if (video.places.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Center(child: Text('추출된 장소가 없습니다.')),
                      )
                    else
                      for (var i = 0; i < video.places.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _PlaceExpandableCard(
                            order: i + 1,
                            place: video.places[i],
                            onTap: () => _openDetail(video.places[i]),
                            onTimestampTap: video.places[i].timestampSec != null
                                ? () => _seekTo(video.places[i].timestampSec!)
                                : null,
                            onMapTap: video.places[i].hasCoordinates
                                ? () => _showOnMap(video.places[i])
                                : null,
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceExpandableCard extends StatefulWidget {
  const _PlaceExpandableCard({
    required this.order,
    required this.place,
    required this.onTap,
    this.onTimestampTap,
    this.onMapTap,
  });

  final int order;
  final PlaceModel place;
  final VoidCallback onTap;
  final VoidCallback? onTimestampTap;
  final VoidCallback? onMapTap;

  @override
  State<_PlaceExpandableCard> createState() => _PlaceExpandableCardState();
}

class _PlaceExpandableCardState extends State<_PlaceExpandableCard> {
  bool _expanded = false;
  Future<PlaceSummaryModel>? _summaryFuture;

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      _summaryFuture ??= PlaceSummaryRepository().getSummary(
        widget.place.placeId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint1,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 3),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accentCyan,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${widget.order}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (place.timestampSec != null)
                        GestureDetector(
                          onTap: widget.onTimestampTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceTint3,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              formatTimestamp(place.timestampSec!),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      if (place.timestampSec != null) const SizedBox(width: 6),
                      if (placeCategoryLabel(place.category) != null)
                        Flexible(
                          child: Text(
                            placeCategoryLabel(place.category)!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _toggleExpanded,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded ? '접기' : '더보기',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 10),
                    FutureBuilder<PlaceSummaryModel>(
                      future: _summaryFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final summary = snapshot.data;
                        if (summary == null || !summary.available) {
                          return const Text(
                            '아직 여러 영상에서 비교할 만한 의견이 모이지 않았어요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          );
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: AppColors.dividerStrong,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (summary.pros != null)
                                _SummaryRow(
                                  label: '장점',
                                  labelColor: AppColors.primaryStrong,
                                  labelBg: AppColors.surfaceTint3Alt,
                                  text: summary.pros!,
                                ),
                              if (summary.pros != null && summary.cons != null)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Divider(height: 1),
                                ),
                              if (summary.cons != null)
                                _SummaryRow(
                                  label: '단점',
                                  labelColor: Color(0xFFD9784F),
                                  labelBg: Color(0xFFFDF1EA),
                                  text: summary.cons!,
                                ),
                              const SizedBox(height: 8),
                              Text(
                                '브이로그 코멘트 · 리뷰 ${summary.sourceCount}건 AI 요약',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted2,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 34px white circles with `sh-icon-btn`, side by side with a 6
          // gap -- the handoff's own shape for these two.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundCardButton(
                tooltip: '지도 보기',
                onTap: widget.onMapTap,
                child: MapPinGlyphIcon(
                  size: 15,
                  color: widget.onMapTap != null
                      ? AppColors.textTertiary
                      : AppColors.textMuted2,
                ),
              ),
              const SizedBox(width: 6),
              _RoundIconChrome(
                child: BookmarkButton(placeId: place.placeId, compact: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.labelColor,
    required this.labelBg,
    required this.text,
  });

  final String label;
  final Color labelColor;
  final Color labelBg;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: labelBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown while the backend keeps looking for places the transcript didn't
/// mention, by reading the video's on-screen text. That pass takes minutes,
/// so the screen shows what it has and fills in the rest as it arrives.
class _EnrichmentNotice extends StatelessWidget {
  const _EnrichmentNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '영상 화면 속 장소 이름을 더 찾고 있어요. 잠시 후 자동으로 추가됩니다.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 34px white circle holding one small control, as the handoff draws the
/// place card's map and bookmark buttons.
/// The design's 34px white circle behind a place card's trailing icons.
class _RoundIconChrome extends StatelessWidget {
  const _RoundIconChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: AppColors.floatingButtonShadow(),
      ),
      child: child,
    );
  }
}

/// A circle this card drives itself. Built on [IconButton] rather than a bare
/// gesture detector so a null [onTap] is disabled *and still labelled* -- the
/// map button of a place with no coordinates has to say what it would have
/// done, not just go grey.
class _RoundCardButton extends StatelessWidget {
  const _RoundCardButton({required this.tooltip, required this.child, required this.onTap});

  final String tooltip;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _RoundIconChrome(
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: child,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      ),
    );
  }
}
