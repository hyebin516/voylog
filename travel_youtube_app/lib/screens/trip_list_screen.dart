import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/app_card.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().loadTrips();
    });
  }

  Future<void> _createTrip() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 여행 만들기'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 제주도 여행'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('만들기'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final tripProvider = context.read<TripProvider>();
    final trip = await tripProvider.createTrip(name);
    if (!mounted) return;

    if (trip != null) {
      Navigator.pushNamed(context, AppRoutes.tripDetail, arguments: trip.tripId);
    } else {
      final message = tripProvider.errorMessage ?? '여행 생성에 실패했습니다.';
      showErrorDialog(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 여행'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '새 여행 만들기',
            onPressed: _createTrip,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (tripProvider.isLoading && tripProvider.trips.isEmpty) {
            return const LoadingIndicator();
          }
          if (tripProvider.state == ViewState.error && tripProvider.trips.isEmpty) {
            return ErrorView(
              message: tripProvider.errorMessage ?? '여행 목록을 불러오지 못했습니다.',
              onRetry: () => tripProvider.loadTrips(),
            );
          }
          if (tripProvider.trips.isEmpty) {
            return const Center(child: Text('아직 만든 여행이 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: tripProvider.trips.length,
            separatorBuilder: (context, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final TripModel trip = tripProvider.trips[index];
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onTap: () => Navigator.pushNamed(context, AppRoutes.tripDetail, arguments: trip.tripId),
                child: Row(
                  children: [
                    const Icon(Icons.card_travel_rounded, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trip.name, style: Theme.of(context).textTheme.titleMedium),
                          Text('${trip.dayCount}일차 저장됨', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
