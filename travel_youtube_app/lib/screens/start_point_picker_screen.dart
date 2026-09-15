import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/map_view_types.dart';
import '../models/start_point_model.dart';
import '../providers/hotel_provider.dart';
import '../repositories/map_repository.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/primary_button.dart';

/// Picks where an FR-17 walking course starts and ends: either by searching
/// for a place or by dragging the map to a spot.
///
/// Pops with a [StartPointModel], or null if the user backed out. Nothing is
/// saved -- unlike the trip planner's hotel flow, this point exists only for
/// the course being generated.
class StartPointPickerScreen extends StatefulWidget {
  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead.
  final MapRepository mapRepository;

  const StartPointPickerScreen({super.key, this.mapRepository = const KakaoMapRepository()});

  @override
  State<StartPointPickerScreen> createState() => _StartPointPickerScreenState();
}

// Seoul City Hall, matching the trip planner's map default -- only used
// until the user moves the map or searches.
const double _defaultLatitude = 37.5665;
const double _defaultLongitude = 126.9780;

class _StartPointPickerScreenState extends State<StartPointPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  MapCenter _center = const MapCenter(latitude: _defaultLatitude, longitude: _defaultLongitude);
  bool _isResolving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    await context.read<HotelProvider>().searchHotels(query);
  }

  /// Uses the dragged map center. The address is only for display, so a
  /// failed lookup falls back to a generic label rather than blocking the
  /// pick -- the coordinates are what the course actually needs.
  Future<void> _useMapCenter() async {
    if (_isResolving) return;
    setState(() => _isResolving = true);

    final address = await context.read<HotelProvider>().reverseGeocode(
      _center.latitude,
      _center.longitude,
    );

    if (!mounted) return;
    setState(() => _isResolving = false);

    Navigator.pop(
      context,
      StartPointModel(
        name: (address == null || address.isEmpty) ? '지도에서 고른 지점' : address,
        latitude: _center.latitude,
        longitude: _center.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotelProvider = context.watch<HotelProvider>();
    final results = hotelProvider.searchResults;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '시작 지점 선택',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                key: const Key('startPointSearchField'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _onSearch(),
                decoration: InputDecoration(
                  hintText: '장소 검색 (예: 성수역, 전주 한옥마을)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    key: const Key('startPointSearchButton'),
                    onPressed: _onSearch,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  ),
                ),
              ),
            ),
            if (hotelProvider.searchState == ViewState.error) ...[
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ErrorView(message: hotelProvider.searchErrorMessage ?? '검색에 실패했습니다.'),
              ),
            ],
            if (results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final candidate = results[index];
                    return ListTile(
                      leading: const Icon(Icons.place_outlined, color: AppColors.textSecondary),
                      title: Text(candidate.name),
                      subtitle: candidate.address == null ? null : Text(candidate.address!),
                      onTap: () => Navigator.pop(
                        context,
                        StartPointModel(
                          name: candidate.name,
                          latitude: candidate.latitude,
                          longitude: candidate.longitude,
                        ),
                      ),
                    );
                  },
                ),
              )
            else ...[
              const SizedBox(height: AppSpacing.sm),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '지도를 움직여 시작할 위치를 가운데 핀에 맞춰주세요.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        widget.mapRepository.buildMap(
                          initialLatitude: _defaultLatitude,
                          initialLongitude: _defaultLongitude,
                          onCenterChanged: (center) => setState(() => _center = center),
                        ),
                        const IgnorePointer(
                          child: Icon(Icons.place, size: 38, color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, AppSpacing.lg),
                child: PrimaryButton(
                  key: const Key('confirmStartPointButton'),
                  label: '이 위치에서 시작하기',
                  isLoading: _isResolving,
                  onPressed: _useMapCenter,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
