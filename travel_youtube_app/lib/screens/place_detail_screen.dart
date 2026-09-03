import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/place_model.dart';
import '../providers/place_summary_provider.dart';
import '../repositories/map_repository.dart';
import '../utils/timestamp_format.dart';
import '../utils/view_state.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/primary_button.dart';
import '../widgets/tag_chip.dart';

class PlaceDetailScreen extends StatefulWidget {
  final PlaceModel place;

  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const PlaceDetailScreen({
    super.key,
    required this.place,
    this.mapRepository = const KakaoMapRepository(),
  });

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

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final mapRepository = widget.mapRepository;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [BookmarkButton(placeId: place.placeId)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: place.hasCoordinates
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
                      color: AppColors.surfaceTint,
                      child: Center(child: Text('위치 정보가 없습니다.')),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(place.name, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (place.category != null) ...[
                const SizedBox(width: AppSpacing.sm),
                TagChip(label: place.category!),
              ],
            ],
          ),
          if (place.address != null && place.address!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(place.address!, style: textTheme.bodyMedium)),
              ],
            ),
          ],
          if (place.timestampSec != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.schedule_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text('영상 ${formatTimestamp(place.timestampSec!)} 지점에 등장', style: textTheme.bodyMedium),
              ],
            ),
          ],
          if (place.businessHours != null && place.businessHours!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _BusinessHoursSection(
              businessHours: place.businessHours!,
              isEstimated: place.businessHoursIsEstimated,
            ),
          ],
          if (place.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [for (final tag in place.tags) TagChip(label: tag)],
            ),
          ],
          if (place.mentionNote != null && place.mentionNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _MentionNoteSection(note: place.mentionNote!),
          ],
          const SizedBox(height: AppSpacing.lg),
          const _PlaceSummarySection(),
          const SizedBox(height: AppSpacing.lg),
          if (place.timestampSec != null)
            PrimaryButton(
              label: '영상에서 이 장면 보기',
              icon: Icons.play_circle_outline_rounded,
              onPressed: () => Navigator.pop(context, place.timestampSec),
            ),
        ],
      ),
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
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text('영업시간', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final entry in businessHours.entries)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${entry.key}: ${entry.value}', style: textTheme.bodyMedium),
            ),
          if (isEstimated) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '* 영업시간은 영상 정보 기반 추정치예요',
              style: textTheme.bodySmall?.copyWith(color: AppColors.primary.withValues(alpha: 0.55)),
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
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: AppColors.accentCyan, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, size: 18, color: AppColors.accentCyan),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              note,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a "여러 영상 속 방문자 의견" card once a summary is generated from
/// other videos that mention this same place. Renders nothing while
/// loading, on error, or when fewer than 2 videos mention the place --
/// this is a supplementary panel, not core page content, so its absence
/// should never read as broken.
class _PlaceSummarySection extends StatelessWidget {
  const _PlaceSummarySection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('여러 영상 속 방문자 의견', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              if (summary.pros != null) _SummaryLine(icon: Icons.thumb_up_outlined, text: summary.pros!),
              if (summary.cons != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _SummaryLine(icon: Icons.thumb_down_outlined, text: summary.cons!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }
}
