import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/itinerary_model.dart';
import 'voylog_logo.dart';

IconData _transportIcon(String transportMode) {
  switch (transportMode) {
    case 'walk':
      return Icons.directions_walk_rounded;
    case 'transit':
      return Icons.directions_transit_rounded;
    default:
      return Icons.directions_car_rounded;
  }
}

String _transportLabel(String transportMode) {
  switch (transportMode) {
    case 'walk':
      return '도보';
    case 'transit':
      return '대중교통';
    default:
      return '자동차';
  }
}

String _formatDuration(int? seconds) {
  if (seconds == null) return '';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '$hours시간 $minutes분';
  return '$minutes분';
}

String _formatDistance(int? meters) {
  if (meters == null) return '';
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
  return '${meters}m';
}

String _formatDate(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

/// Shared header used by both share-card variants: logo mark, wordmark, and
/// a small eyebrow label.
class _ShareCardHeader extends StatelessWidget {
  const _ShareCardHeader({required this.eyebrow});

  final String eyebrow;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const VoylogLogoMark(size: 32),
        const SizedBox(width: AppSpacing.sm),
        const VoylogWordmark(fontSize: 18),
        const Spacer(),
        Text(
          eyebrow,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentCyan),
        ),
      ],
    );
  }
}

/// Shared footer tagline used by both share-card variants.
class _ShareCardFooter extends StatelessWidget {
  const _ShareCardFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            'Voylog로 만든 여행 일정',
            style: TextStyle(fontSize: 12, color: AppColors.ink.withValues(alpha: 0.45), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// The white rounded "page" every share card renders onto, matching
/// [AppCard]'s look (can't reuse AppCard directly since it wires up an
/// InkWell/Material tap target this off-screen render never needs).
class _ShareCardSurface extends StatelessWidget {
  const _ShareCardSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow(opacity: 0.16, blurRadius: 24, offset: const Offset(0, 10)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );
  }
}

/// One line in the overview card summarizing a single day.
class _DaySummaryRow extends StatelessWidget {
  const _DaySummaryRow({required this.day});

  final ItineraryModel day;

  @override
  Widget build(BuildContext context) {
    final placeCount = day.routeData.where((p) => !p.isHotel).length;
    final duration = _formatDuration(day.totalDurationSec);
    final distance = _formatDistance(day.totalDistanceM);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Text(
              '${day.dayNumber}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              day.isRoundTrip ? '왕복 · 장소 $placeCount곳' : '호텔 → 호텔 · 장소 $placeCount곳',
              style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600),
            ),
          ),
          Icon(_transportIcon(day.transportMode), size: 15, color: AppColors.primary.withValues(alpha: 0.7)),
          if (duration.isNotEmpty || distance.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              [duration, distance].where((s) => s.isNotEmpty).join(' · '),
              style: TextStyle(fontSize: 12, color: AppColors.ink.withValues(alpha: 0.55)),
            ),
          ],
        ],
      ),
    );
  }
}

/// One stop in a day's timeline (a hotel or a place), with a connecting
/// line/arrow down to the next stop when [isLast] is false.
class _TimelineStop extends StatelessWidget {
  const _TimelineStop({required this.index, required this.point, required this.isLast, required this.transportMode});

  final int index;
  final RoutePointModel point;
  final bool isLast;
  final String transportMode;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: point.isHotel ? AppColors.primary : AppColors.accentCyan,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  point.isHotel ? Icons.hotel_rounded : Icons.place_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.surfaceSoft, margin: const EdgeInsets.symmetric(vertical: 2)),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.name,
                    softWrap: true,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(_transportIcon(transportMode), size: 12, color: AppColors.ink.withValues(alpha: 0.4)),
                        const SizedBox(width: 4),
                        Text(
                          '${_transportLabel(transportMode)}으로 이동',
                          style: TextStyle(fontSize: 11, color: AppColors.ink.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trip-wide overview share card: one page summarizing every day of
/// [days] under [tripName]. Rendered off-screen via `captureWidgetPng` --
/// never shown directly in the normal widget tree.
class ItineraryOverviewShareCard extends StatelessWidget {
  const ItineraryOverviewShareCard({
    super.key,
    required this.tripName,
    required this.createdAt,
    required this.days,
  });

  final String tripName;
  final DateTime createdAt;
  final List<ItineraryModel> days;

  @override
  Widget build(BuildContext context) {
    return _ShareCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ShareCardHeader(eyebrow: '여행 일정'),
          const SizedBox(height: AppSpacing.lg),
          Text(
            tripName,
            softWrap: true,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            '생성일 ${_formatDate(createdAt)} · 총 ${days.length}일',
            style: TextStyle(fontSize: 13, color: AppColors.ink.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final day in days) _DaySummaryRow(day: day),
          const _ShareCardFooter(),
        ],
      ),
    );
  }
}

/// Single-day detail share card: [day]'s full visiting order rendered as a
/// numbered vertical timeline. Rendered off-screen via `captureWidgetPng`.
class ItineraryShareCard extends StatelessWidget {
  const ItineraryShareCard({
    super.key,
    required this.tripName,
    required this.dayNumber,
    required this.day,
  });

  final String tripName;
  final int dayNumber;
  final ItineraryModel day;

  @override
  Widget build(BuildContext context) {
    final sortedStops = [...day.routeData]..sort((a, b) => a.order.compareTo(b.order));
    final duration = _formatDuration(day.totalDurationSec);
    final distance = _formatDistance(day.totalDistanceM);

    return _ShareCardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShareCardHeader(eyebrow: tripName),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                '$dayNumber일차',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceTint, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  day.isRoundTrip ? '왕복' : '호텔 → 호텔',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
          ),
          if (duration.isNotEmpty || distance.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [duration, distance].where((s) => s.isNotEmpty).join(' · '),
              style: TextStyle(fontSize: 13, color: AppColors.ink.withValues(alpha: 0.55)),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < sortedStops.length; i++)
            _TimelineStop(
              index: i,
              point: sortedStops[i],
              isLast: i == sortedStops.length - 1,
              transportMode: day.transportMode,
            ),
          const _ShareCardFooter(),
        ],
      ),
    );
  }
}
