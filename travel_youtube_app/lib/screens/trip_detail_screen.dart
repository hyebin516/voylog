import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/trip_model.dart';
import '../providers/hotel_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/trip_provider.dart';
import '../routes/app_routes.dart';
import '../services/itinerary_share_service.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/primary_button.dart';
import '../widgets/route_summary_card.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final ItineraryShareService _shareService = const ItineraryShareService();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().loadTrip(widget.tripId);
    });
  }

  void _addDay(int dayNumber) {
    final tripProvider = context.read<TripProvider>();
    tripProvider.startBuildingDay(widget.tripId, dayNumber);
    context.read<ItineraryProvider>().reset();
    context.read<HotelProvider>().clearSelection();
    Navigator.pushNamed(context, AppRoutes.bookmarks);
  }

  Future<void> _confirmDeleteTrip() async {
    final tripProvider = context.read<TripProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('여행 삭제'),
        content: Text('${tripProvider.currentTrip?.name ?? '이 여행'}을(를) 삭제하시겠습니까? 저장된 모든 일차 동선도 함께 삭제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await tripProvider.deleteTrip(widget.tripId);
    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      final message = tripProvider.errorMessage ?? '여행 삭제에 실패했습니다.';
      showErrorDialog(context, message);
    }
  }

  Future<void> _onSharePressed(TripDetailModel trip) async {
    setState(() => _isSharing = true);
    try {
      await _shareService.shareTrip(context: context, trip: trip);
    } catch (_) {
      if (mounted) {
        showErrorDialog(context, '이미지를 만들지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final trip = tripProvider.currentTrip;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip?.name ?? '여행'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: '여행 삭제',
            onPressed: trip == null ? null : _confirmDeleteTrip,
          ),
        ],
      ),
      body: Builder(
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

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              PrimaryButton(
                label: '이미지로 공유',
                icon: Icons.image_outlined,
                isLoading: _isSharing,
                onPressed: trip.days.isEmpty ? null : () => _onSharePressed(trip),
              ),
              const SizedBox(height: AppSpacing.md),
              if (trip.days.isEmpty) const Center(child: Text('아직 저장된 일차가 없습니다.')),
              for (final day in trip.days) ...[
                Text('${day.dayNumber}일차', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                RouteSummaryCard(
                  isRoundTrip: day.isRoundTrip,
                  transportMode: day.transportMode,
                  totalDurationSec: day.totalDurationSec,
                  totalDistanceM: day.totalDistanceM,
                  routeData: day.routeData,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              PrimaryButton(
                label: '${trip.days.length + 1}일차 추가',
                icon: Icons.add_road_rounded,
                onPressed: () => _addDay(trip.days.length + 1),
              ),
            ],
          );
        },
      ),
    );
  }
}
