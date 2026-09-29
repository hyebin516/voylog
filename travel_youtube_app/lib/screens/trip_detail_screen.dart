import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/hotel_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/trip_provider.dart';
import '../routes/app_routes.dart';
import '../models/itinerary_model.dart';
import '../utils/date_format.dart';
import '../utils/route_format.dart';
import '../utils/view_state.dart';
import '../widgets/dashed_border_container.dart';
import '../widgets/date_range_dialog.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().loadTrip(widget.tripId);
    });
  }

  Future<void> _editDates(DateTime? currentStart, DateTime? currentEnd) async {
    final result = await showTripDateRangeDialog(
      context,
      initialStartDate: currentStart,
      initialEndDate: currentEnd,
      title: '여행 날짜 수정',
    );
    if (result == null || !mounted) return;

    final tripProvider = context.read<TripProvider>();
    final success = await tripProvider.updateTripDates(
      widget.tripId,
      startDate: result.startDate,
      endDate: result.endDate,
    );
    if (!mounted) return;
    if (!success) {
      final message = tripProvider.errorMessage ?? '여행 날짜를 저장하지 못했습니다.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _addDay(int dayNumber) {
    final tripProvider = context.read<TripProvider>();
    tripProvider.startBuildingDay(widget.tripId, dayNumber);
    context.read<ItineraryProvider>().reset();
    context.read<HotelProvider>().clearSelection();
    Navigator.pushNamed(context, AppRoutes.dayFolderSelect);
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final trip = tripProvider.currentTrip;

    return Scaffold(
      // v1 layered a blue gradient and a decorative circle here; v2 makes
      // every screen a flat `surface-page`.
      backgroundColor: AppColors.surfacePage,
      body: Stack(
        children: [
          SafeArea(
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
                          '여행',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (trip != null)
                        InkWell(
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.tripOverview,
                            arguments: widget.tripId,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFD5EAF7),
                                width: 1.5,
                              ),
                              boxShadow: AppColors.cardShadow(),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.reorder_rounded,
                                  size: 14,
                                  color: AppColors.primaryStrong,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '전체 일정',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryStrong,
                                  ),
                                ),
                              ],
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
                      if (tripProvider.state == ViewState.error &&
                          trip == null) {
                        return ErrorView(
                          message:
                              tripProvider.errorMessage ?? '여행을 불러오지 못했습니다.',
                          onRetry: () => tripProvider.loadTrip(widget.tripId),
                        );
                      }
                      if (trip == null) return const SizedBox.shrink();

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        children: [
                          // Trip name -- read-only for now (no rename API).
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 15,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppColors.cardShadow(),
                            ),
                            child: Text(
                              trip.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: _DateField(
                                  label: trip.startDate != null
                                      ? formatTripDate(trip.startDate!)
                                      : '시작일',
                                  onTap: () =>
                                      _editDates(trip.startDate, trip.endDate),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '–',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _DateField(
                                  label: trip.endDate != null
                                      ? formatTripDate(trip.endDate!)
                                      : '종료일',
                                  onTap: () =>
                                      _editDates(trip.startDate, trip.endDate),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text(
                            '날짜',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (trip.days.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Center(
                                child: Text(
                                  '아직 저장된 일차가 없습니다.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            ),
                          for (final day in trip.days) ...[
                            _TripDayCard(
                              day: day,
                              date: trip.startDate?.add(Duration(days: day.dayNumber - 1)),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          GestureDetector(
                            onTap: () => _addDay(trip.days.length + 1),
                            child: DashedBorderContainer(
                              backgroundColor: AppColors.surfaceTint1,
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.add_rounded,
                                    size: 15,
                                    color: AppColors.primaryStrong,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '날짜 추가',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryStrong,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One end of the trip's date range (matches the design's `field` boxes).
/// Tapping either side opens a dialog to set/change both dates.
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow(),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// One day's compact summary card -- day-number badge (blue/orange
/// alternating, matching the design), start hotel + round-trip/hotel-to-hotel
/// badge, and a totals line. The full stop-by-stop breakdown lives on
/// "전체 일정" (trip overview) instead of being repeated here.
const List<String> _koreanWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

class _TripDayCard extends StatelessWidget {
  const _TripDayCard({required this.day, this.date});

  final ItineraryModel day;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final badgeColor = day.dayNumber.isOdd
        ? AppColors.primary
        : AppColors.accentWarm;
    final hotelName = day.routeData.isNotEmpty ? day.routeData.first.name : '-';
    final placeCount = day.routeData.where((p) => !p.isHotel).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${day.dayNumber}일차',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (date != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${date!.month}/${date!.day} (${_koreanWeekdays[date!.weekday - 1]})',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint1,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.home_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    hotelName,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint3Alt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    day.isRoundTrip ? '왕복' : '호텔 → 호텔',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '저장된 장소 $placeCount곳 · ${formatRouteDuration(day.totalDurationSec)} · ${formatRouteDistance(day.totalDistanceM)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
