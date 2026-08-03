import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../providers/hotel_provider.dart';
import '../providers/itinerary_provider.dart';
import '../repositories/map_repository.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';
import '../widgets/route_summary_card.dart';
import 'hotel_search_screen.dart';

class RoutePlannerScreen extends StatelessWidget {
  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const RoutePlannerScreen({super.key, this.mapRepository = const KakaoMapRepository()});

  Future<void> _pickHotel(BuildContext context, HotelSelectionRole role) {
    return Navigator.pushNamed(
      context,
      AppRoutes.hotelSearch,
      arguments: HotelSearchScreenArgs(role: role),
    );
  }

  Future<void> _optimize(BuildContext context) async {
    final hotelProvider = context.read<HotelProvider>();
    final itineraryProvider = context.read<ItineraryProvider>();

    final startHotel = hotelProvider.selectedStartHotel;
    final endHotel = hotelProvider.selectedEndHotel;
    if (startHotel == null || endHotel == null) return;

    await itineraryProvider.optimize(
      startHotelId: startHotel.hotelId,
      endHotelId: endHotel.hotelId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotelProvider = context.watch<HotelProvider>();
    final itineraryProvider = context.watch<ItineraryProvider>();

    final startHotel = hotelProvider.selectedStartHotel;
    final endHotel = hotelProvider.selectedEndHotel;
    final canOptimize =
        startHotel != null && endHotel != null && itineraryProvider.canOptimize;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 동선 플래너')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HotelSelectTile(
                label: '시작 호텔',
                hotelName: startHotel?.name,
                onTap: () => _pickHotel(context, HotelSelectionRole.start),
              ),
              const SizedBox(height: AppSpacing.sm),
              _HotelSelectTile(
                label: '종료 호텔',
                hotelName: endHotel?.name,
                onTap: () => _pickHotel(context, HotelSelectionRole.end),
              ),
              if (startHotel != null && endHotel != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Chip(
                  label: Text(
                    startHotel.hotelId == endHotel.hotelId
                        ? '왕복 (Round Trip)'
                        : '호텔 → 호텔',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                '선택한 장소 ${itineraryProvider.selectedPlaceIds.length}개',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: '동선 최적화',
                icon: Icons.route_rounded,
                isLoading: itineraryProvider.isLoading,
                onPressed: canOptimize ? () => _optimize(context) : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (itineraryProvider.isLoading)
                const LoadingIndicator(message: '최적 동선을 계산하고 있어요...'),
              if (itineraryProvider.state == ViewState.error)
                ErrorView(
                  message: itineraryProvider.errorMessage ?? '동선 생성에 실패했습니다.',
                  onRetry: canOptimize ? () => _optimize(context) : null,
                ),
              if (itineraryProvider.result != null) ...[
                RouteSummaryCard(itinerary: itineraryProvider.result!),
                const SizedBox(height: AppSpacing.md),
                Builder(
                  builder: (context) {
                    final routeMarkers = itineraryProvider.result!.routeData
                        .where((p) => p.latitude != null && p.longitude != null)
                        .map(
                          (p) => MapMarkerData(
                            id: p.placeId ?? p.hotelId ?? p.name,
                            title: p.name,
                            latitude: p.latitude!,
                            longitude: p.longitude!,
                          ),
                        )
                        .toList();

                    return SizedBox(
                      height: 320,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: mapRepository.buildMap(
                          initialLatitude: routeMarkers.first.latitude,
                          initialLongitude: routeMarkers.first.longitude,
                          markers: routeMarkers,
                          drawRoutePolyline: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HotelSelectTile extends StatelessWidget {
  final String label;
  final String? hotelName;
  final VoidCallback onTap;

  const _HotelSelectTile({
    required this.label,
    required this.hotelName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.hotel_rounded),
        title: Text(label),
        subtitle: Text(hotelName ?? '호텔을 선택하세요'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
