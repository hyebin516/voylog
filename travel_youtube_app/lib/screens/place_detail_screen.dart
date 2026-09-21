import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/place_model.dart';
import '../providers/place_summary_provider.dart';
import '../repositories/behavior_repository.dart';
import '../repositories/map_repository.dart';
import '../services/kakao_map_launcher.dart';
import '../services/place_share_service.dart';
import '../utils/timestamp_format.dart';
import '../utils/view_state.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/primary_button.dart';
import '../widgets/tag_chip.dart';
import '../utils/place_category_label.dart';

class PlaceDetailScreen extends StatefulWidget {
  final PlaceModel place;

  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  /// Defaults to the real OS share sheet. Widget tests inject a fake so
  /// `flutter test` never touches the real `share_plus` platform channel.
  final PlaceShareService shareService;

  /// Defaults to opening the real Kakao Map app (or web). Widget tests
  /// inject a fake so nothing is launched under `flutter test`.
  final KakaoMapLauncher kakaoMapLauncher;

  /// Best-effort FR-15 behavior logging (see [RecommendationProvider] for
  /// the same pattern) -- a screen-level repository call rather than a
  /// dedicated provider, since this screen is reached from many different
  /// origins and the signal applies regardless of which one.
  final BehaviorRepository behaviorRepository;

  PlaceDetailScreen({
    super.key,
    required this.place,
    this.mapRepository = const KakaoMapRepository(),
    this.shareService = const PlaceShareService(),
    this.kakaoMapLauncher = const KakaoMapLauncher(),
    BehaviorRepository? behaviorRepository,
  }) : behaviorRepository = behaviorRepository ?? BehaviorRepository();

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaceSummaryProvider>().load(widget.place.placeId);
    });
  }

  Future<void> _onSharePressed() async {
    final place = widget.place;
    if (!place.hasCoordinates) return;

    await widget.shareService.shareMapLink(
      placeName: place.name,
      latitude: place.latitude!,
      longitude: place.longitude!,
    );

    try {
      await widget.behaviorRepository.record(placeId: place.placeId, action: 'share', screen: 'place_detail');
    } catch (_) {
      // best-effort: a failed behavior log must never surface to the user
    }
  }

  Future<void> _onOpenKakaoMapPressed() async {
    final place = widget.place;
    if (!place.hasCoordinates) return;

    final opened = await widget.kakaoMapLauncher.open(
      placeId: place.placeId,
      name: place.name,
      latitude: place.latitude!,
      longitude: place.longitude!,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오맵을 열 수 없어요.')),
      );
      return;
    }

    try {
      await widget.behaviorRepository.record(placeId: place.placeId, action: 'map_view', screen: 'place_detail');
    } catch (_) {
      // best-effort: a failed behavior log must never surface to the user
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final mapRepository = widget.mapRepository;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                place.hasCoordinates
                    ? mapRepository.buildMap(
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
                      )
                    : const ColoredBox(
                        color: AppColors.surfaceTint3,
                        child: Center(child: Text('위치 정보가 없습니다.')),
                      ),
                Positioned(
                  top: 8,
                  left: 20,
                  child: SafeArea(
                    bottom: false,
                    child: _HeroIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 20,
                  child: SafeArea(
                    bottom: false,
                    child: _HeroBookmarkButton(placeId: place.placeId),
                  ),
                ),
                if (place.hasCoordinates)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: _OpenKakaoMapButton(onTap: _onOpenKakaoMapPressed),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  place.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                if (place.address != null && place.address!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(place.address!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
                if (placeCategoryLabel(place.category) != null || place.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (placeCategoryLabel(place.category) != null)
                        TagChip(label: placeCategoryLabel(place.category)!),
                      for (final tag in place.tags) TagChip(label: tag),
                    ],
                  ),
                ],
                if (place.timestampSec != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.schedule_outlined, size: 16, color: AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Text(
                        '영상 ${formatTimestamp(place.timestampSec!)} 지점에 등장',
                        style: const TextStyle(fontSize: 13, color: AppColors.ink),
                      ),
                    ],
                  ),
                ],
                if (place.businessHours != null && place.businessHours!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _BusinessHoursSection(
                    businessHours: place.businessHours!,
                    isEstimated: place.businessHoursIsEstimated,
                  ),
                ],
                if (place.mentionNote != null && place.mentionNote!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _MentionNoteSection(note: place.mentionNote!),
                ],
                const SizedBox(height: AppSpacing.md),
                const _PlaceSummarySection(),
                const SizedBox(height: AppSpacing.lg),
                if (place.hasCoordinates)
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _onSharePressed,
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: const Text('공유하기'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                        ),
                      ),
                      if (place.timestampSec != null) ...[
                        const SizedBox(width: 10),
                        // Half the row can't fit "영상에서 이 장면 보기" plus its
                        // icon on a ~360dp phone -- it overflowed on device --
                        // so this side gets more room and a shorter label.
                        Expanded(
                          flex: 3,
                          child: PrimaryButton(
                            label: '영상에서 보기',
                            icon: Icons.play_circle_outline_rounded,
                            onPressed: () => Navigator.pop(context, place.timestampSec),
                          ),
                        ),
                      ],
                    ],
                  )
                else if (place.timestampSec != null)
                  PrimaryButton(
                    label: '영상에서 이 장면 보기',
                    icon: Icons.play_circle_outline_rounded,
                    onPressed: () => Navigator.pop(context, place.timestampSec),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hands the place off to the Kakao Map app for directions, reviews and
/// street view, which the in-app preview map doesn't have.
class _OpenKakaoMapButton extends StatelessWidget {
  const _OpenKakaoMapButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      elevation: 3,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new_rounded, size: 15, color: AppColors.primaryStrong),
              SizedBox(width: 6),
              Text(
                '카카오맵에서 보기',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Icon(icon, size: 17, color: AppColors.textSecondary),
      ),
    );
  }
}

/// Same 36px floating-pill treatment as [_HeroIconButton], wrapping the
/// shared [BookmarkButton] so its filled/outline toggle logic stays
/// centralized while matching the hero overlay style.
class _HeroBookmarkButton extends StatelessWidget {
  const _HeroBookmarkButton({required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: BookmarkButton(placeId: placeId),
    );
  }
}

/// The `business_hours` JSONB column is a free-form day-\>hours map (only
/// populated when the source video's transcript actually states hours --
/// never guessed), so this just lists whatever keys came back rather than
/// assuming a fixed 7-day shape.
class _BusinessHoursSection extends StatelessWidget {
  const _BusinessHoursSection({required this.businessHours, required this.isEstimated});

  final Map<String, dynamic> businessHours;
  final bool isEstimated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surfaceTint1, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('영업시간', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 8),
          for (final entry in businessHours.entries)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 12.5, color: AppColors.ink)),
            ),
          if (isEstimated) ...[
            const SizedBox(height: 6),
            const Text(
              '* 영업시간은 영상 정보 기반 추정치예요',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// The one-sentence comment the LLM pulled from this video's transcript
/// about this specific place (`mention_note`) -- never fabricated, only
/// shown when the video actually said something about it.
class _MentionNoteSection extends StatelessWidget {
  const _MentionNoteSection({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint1,
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: AppColors.accentCyan, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, size: 18, color: AppColors.accentCyan),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(note, style: const TextStyle(fontSize: 13, color: AppColors.ink, fontStyle: FontStyle.italic, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

/// Shows a "여러 영상 속 방문자 의견" card once a summary is generated from
/// other videos that mention this same place (FR-19). Renders nothing
/// while loading, on error, or when fewer than 2 videos mention the place
/// -- this is a supplementary panel, not core page content, so its
/// absence should never read as broken. Our backend only ever produces
/// ONE consolidated sentence each for pros/cons, so this stays a single
/// line per card rather than the bulleted lists shown in the design
/// mockup's separate summary page.
class _PlaceSummarySection extends StatelessWidget {
  const _PlaceSummarySection();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaceSummaryProvider>(
      builder: (context, provider, _) {
        if (provider.state == ViewState.loading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: AppSpacing.sm),
                Text('여러 영상 속 의견을 모으는 중...'),
              ],
            ),
          );
        }

        final summary = provider.summary;
        if (summary == null || !summary.available) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('여러 영상 속 방문자 의견', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: AppSpacing.sm),
            if (summary.pros != null)
              _SummaryOpinionCard(
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF5FC2A0),
                bg: const Color(0xFFF0FAF5),
                border: const Color(0xFFD5F0E4),
                titleColor: const Color(0xFF2F8B6A),
                title: '이런 점이 좋아요',
                text: summary.pros!,
                textColor: const Color(0xFF3D6B58),
              ),
            if (summary.pros != null && summary.cons != null) const SizedBox(height: AppSpacing.sm),
            if (summary.cons != null)
              _SummaryOpinionCard(
                icon: Icons.error_rounded,
                iconColor: AppColors.danger,
                bg: const Color(0xFFFDF5F4),
                border: const Color(0xFFF7DEDC),
                titleColor: const Color(0xFFB8443F),
                title: '이런 점은 참고하세요',
                text: summary.cons!,
                textColor: const Color(0xFF8A5450),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryOpinionCard extends StatelessWidget {
  const _SummaryOpinionCard({
    required this.icon,
    required this.iconColor,
    required this.bg,
    required this.border,
    required this.titleColor,
    required this.title,
    required this.text,
    required this.textColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color bg;
  final Color border;
  final Color titleColor;
  final String title;
  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: titleColor)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(fontSize: 12.5, color: textColor, height: 1.5)),
        ],
      ),
    );
  }
}
