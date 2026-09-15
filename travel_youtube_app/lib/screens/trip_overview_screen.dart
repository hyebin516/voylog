import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/config/env.dart';
import '../core/theme/app_theme.dart';
import '../models/itinerary_model.dart';
import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../services/itinerary_share_service.dart';
import '../utils/date_format.dart';
import '../utils/route_format.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/route_summary_card.dart';

/// Full-trip overview -- a day-tab timeline of every saved day in one
/// place (design handoff's `isTripOverview`), reached from
/// [TripDetailScreen]'s "전체 일정" button.
///
/// The share icon opens the design's 4-option export sheet
/// (카카오톡/링크 복사/메시지/이미지 저장). "이미지 저장" (and, as a
/// stand-in for 카카오톡/메시지, the OS share sheet they'd otherwise
/// duplicate) is backed by [ItineraryShareService], which renders overview
/// + per-day PNGs and hands them to the platform share sheet, where
/// KakaoTalk/Messages already appear as targets if installed. "링크 복사"
/// copies a link to `GET /trips/:id/share` (FR-20) -- a public, unauthenticated
/// read-only page anyone with the link can open, showing hotel *names* (not
/// address/coordinates) since this link is only ever handed out by the
/// trip's owner to specific people, not broadcast the way the home screen's
/// shared-route feed (FR-21) is.
class TripOverviewScreen extends StatefulWidget {
  final String tripId;

  const TripOverviewScreen({super.key, required this.tripId});

  @override
  State<TripOverviewScreen> createState() => _TripOverviewScreenState();
}

class _TripOverviewScreenState extends State<TripOverviewScreen> {
  final ItineraryShareService _shareService = const ItineraryShareService();
  bool _isSharing = false;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().loadTrip(widget.tripId);
    });
  }

  Future<void> _shareViaSystemSheet() async {
    final trip = context.read<TripProvider>().currentTrip;
    if (trip == null) return;
    setState(() => _isSharing = true);
    try {
      await _shareService.shareTrip(context: context, trip: trip);
    } catch (_) {
      if (mounted) showErrorDialog(context, '이미지를 만들지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _copyShareLink() async {
    final link = '${Env.apiBaseUrl}/trips/${widget.tripId}/share';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('링크가 복사되었어요.')));
  }

  Future<void> _openExportSheet() async {
    final trip = context.read<TripProvider>().currentTrip;
    if (trip == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ExportSheet(
          tripName: trip.name,
          dateLabel: _dateRangeLabel(trip),
          onKakao: () {
            Navigator.pop(sheetContext);
            _shareViaSystemSheet();
          },
          onCopyLink: () {
            Navigator.pop(sheetContext);
            _copyShareLink();
          },
          onMessage: () {
            Navigator.pop(sheetContext);
            _shareViaSystemSheet();
          },
          onSaveImage: () {
            Navigator.pop(sheetContext);
            _shareViaSystemSheet();
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  // Design's subtitle shows the trip's date range (e.g. "2026.09.12 –
  // 2026.09.14"), not the creation date -- falls back to the old
  // creation-date/day-count label for trips saved before start/end dates
  // existed.
  String _dateRangeLabel(TripDetailModel trip) {
    if (trip.startDate == null || trip.endDate == null) {
      return '${_formatDate(trip.createdAt)} 생성 · 총 ${trip.days.length}일차';
    }
    return '${formatTripDate(trip.startDate!)} – ${formatTripDate(trip.endDate!)}';
  }

  // Aggregate place count + distance across every saved day, for the
  // design's pin-icon summary chip under the date range.
  String _overviewTotal(TripDetailModel trip) {
    final placeCount = trip.days.fold<int>(
      0,
      (sum, day) => sum + day.routeData.where((p) => p.type == 'place').length,
    );
    final totalDistanceM = trip.days.fold<int>(
      0,
      (sum, day) => sum + (day.totalDistanceM ?? 0),
    );
    return '장소 $placeCount곳 · ${formatRouteDistance(totalDistanceM)}';
  }

  String? _dayDateLabel(TripDetailModel trip, ItineraryModel day) {
    if (trip.startDate == null) return null;
    return formatTripDate(
      trip.startDate!.add(Duration(days: day.dayNumber - 1)),
    );
  }

  String _dayMeta(ItineraryModel day) {
    final placeCount = day.routeData.where((p) => p.type == 'place').length;
    return '장소 $placeCount곳 · ${formatRouteDistance(day.totalDistanceM)}';
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final trip = tripProvider.currentTrip;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                  const Expanded(
                    child: Text(
                      '전체 일정',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: (trip == null || trip.days.isEmpty || _isSharing)
                        ? null
                        : _openExportSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTint2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isSharing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.ios_share_rounded,
                              size: 16,
                              color: AppColors.primaryStrong,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (tripProvider.isLoading && trip == null) {
                    return const LoadingIndicator();
                  }
                  if (tripProvider.state == ViewState.error && trip == null) {
                    return ErrorView(
                      message: tripProvider.errorMessage ?? '여행을 불러오지 못했습니다.',
                      onRetry: () => tripProvider.loadTrip(widget.tripId),
                    );
                  }
                  if (trip == null) return const SizedBox.shrink();
                  if (trip.days.isEmpty) {
                    return const Center(
                      child: Text(
                        '아직 저장된 일차가 없습니다.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }

                  final dayIndex = _selectedDayIndex.clamp(
                    0,
                    trip.days.length - 1,
                  );
                  final selectedDay = trip.days[dayIndex];

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      Text(
                        trip.name,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dateRangeLabel(trip),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTint2,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _overviewTotal(trip),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (trip.days.length > 1)
                        Row(
                          children: [
                            for (var i = 0; i < trip.days.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: _DayTab(
                                  label: '${trip.days[i].dayNumber}일차',
                                  selected: i == dayIndex,
                                  onTap: () =>
                                      setState(() => _selectedDayIndex = i),
                                ),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 18),
                      _DayPill(
                        dayNumber: selectedDay.dayNumber,
                        dateLabel: _dayDateLabel(trip, selectedDay),
                        meta: _dayMeta(selectedDay),
                      ),
                      const SizedBox(height: 12),
                      RouteSummaryCard(
                        isRoundTrip: selectedDay.isRoundTrip,
                        transportMode: selectedDay.transportMode,
                        totalDurationSec: selectedDay.totalDurationSec,
                        totalDistanceM: selectedDay.totalDistanceM,
                        routeData: selectedDay.routeData,
                      ),
                    ],
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

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceTint3 : AppColors.surfaceTint2,
          border: Border.all(
            color: selected ? AppColors.selectedBorder : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primaryStrong : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.dayNumber, this.dateLabel, required this.meta});

  final int dayNumber;
  final String? dateLabel;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final color = dayNumber.isOdd ? AppColors.primary : AppColors.accentWarm;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$dayNumber일차',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            dateLabel != null ? '$dateLabel · $meta' : meta,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// The design handoff's 4-option share sheet (카카오톡/링크 복사/메시지/이미지 저장).
/// See the doc comment on [TripOverviewScreen] for which options are real
/// vs. placeholders.
class _ExportSheet extends StatelessWidget {
  const _ExportSheet({
    required this.tripName,
    required this.dateLabel,
    required this.onKakao,
    required this.onCopyLink,
    required this.onMessage,
    required this.onSaveImage,
  });

  final String tripName;
  final String dateLabel;
  final VoidCallback onKakao;
  final VoidCallback onCopyLink;
  final VoidCallback onMessage;
  final VoidCallback onSaveImage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '일정 공유하기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint2,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$tripName · $dateLabel',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _ExportOption(
                    label: '카카오톡',
                    bg: const Color(0xFFFEE500),
                    icon: Icons.chat_bubble_rounded,
                    iconColor: const Color(0xFF3A2B1A),
                    onTap: onKakao,
                  ),
                ),
                Expanded(
                  child: _ExportOption(
                    label: '링크 복사',
                    bg: AppColors.surfaceTint3,
                    icon: Icons.link_rounded,
                    iconColor: AppColors.primaryStrong,
                    onTap: onCopyLink,
                  ),
                ),
                Expanded(
                  child: _ExportOption(
                    label: '메시지',
                    bg: AppColors.surfaceTint3,
                    icon: Icons.sms_rounded,
                    iconColor: AppColors.primaryStrong,
                    onTap: onMessage,
                  ),
                ),
                Expanded(
                  child: _ExportOption(
                    label: '이미지 저장',
                    bg: AppColors.surfaceTint3,
                    icon: Icons.image_rounded,
                    iconColor: AppColors.primaryStrong,
                    onTap: onSaveImage,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportOption extends StatelessWidget {
  const _ExportOption({
    required this.label,
    required this.bg,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B7F94),
            ),
          ),
        ],
      ),
    );
  }
}
