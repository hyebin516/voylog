import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/hotel_model.dart';
import '../models/hotel_search_candidate.dart';
import '../models/map_view_types.dart';
import '../providers/hotel_provider.dart';
import '../providers/trip_provider.dart';
import '../repositories/map_repository.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/hotel_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/primary_button.dart';

enum HotelSelectionRole { start, end }

class HotelSearchScreenArgs {
  final HotelSelectionRole role;

  const HotelSearchScreenArgs({required this.role});
}

/// Default map center (Seoul City Hall) used before the user has picked
/// a location. The user must drag the map to their desired hotel and
/// confirm -- coordinates are never entered manually.
const double _defaultLatitude = 37.5665;
const double _defaultLongitude = 126.9780;

/// The design's `isHotelSelect` screen: one screen with a "시작 호텔"/"종료
/// 호텔" segmented toggle (not two separate pushed screens), a real Kakao
/// keyword search bar, and a map-drag fallback for places Kakao doesn't
/// index. `widget.role` only seeds which tab starts active.
class HotelSearchScreen extends StatefulWidget {
  final HotelSelectionRole role;

  /// Defaults to the real native Kakao map. Widget tests inject
  /// `FakeMapRepository()` instead, so the real map SDK never loads
  /// under `flutter test`.
  final MapRepository mapRepository;

  const HotelSearchScreen({
    super.key,
    required this.role,
    this.mapRepository = const KakaoMapRepository(),
  });

  @override
  State<HotelSearchScreen> createState() => _HotelSearchScreenState();
}

class _HotelSearchScreenState extends State<HotelSearchScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  late HotelSelectionRole _activeRole = widget.role;
  bool _roundTripSameHotel = false;

  MapCenter _center = const MapCenter(
    latitude: _defaultLatitude,
    longitude: _defaultLongitude,
  );
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HotelProvider>().loadHotels();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      context.read<HotelProvider>().searchHotels(query);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    context.read<HotelProvider>().clearSearch();
  }

  Future<void> _saveCandidate(HotelSearchCandidate candidate) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final hotel = await context.read<HotelProvider>().createHotel(
      candidate.toHotelModel(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (hotel != null) {
      _selectHotel(hotel);
      _clearSearch();
    } else if (context.mounted) {
      final message =
          context.read<HotelProvider>().errorMessage ?? '호텔 저장에 실패했습니다.';
      showErrorDialog(context, message);
    }
  }

  Future<void> _saveCurrentLocation() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);

    final hotelProvider = context.read<HotelProvider>();
    final address = await hotelProvider.reverseGeocode(
      _center.latitude,
      _center.longitude,
    );

    if (!mounted) return;
    if (address == null || address.isEmpty) {
      setState(() => _isSaving = false);
      showErrorDialog(context, '이 위치의 주소를 찾지 못했어요. 지도를 조금 옮기거나 이름으로 검색해보세요.');
      return;
    }

    final hotel = await hotelProvider.createHotel(
      HotelModel(
        hotelId: '',
        name: name,
        address: address,
        latitude: _center.latitude,
        longitude: _center.longitude,
      ),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (hotel != null) {
      _selectHotel(hotel);
      _nameController.clear();
    } else if (context.mounted) {
      final message = hotelProvider.errorMessage ?? '호텔 저장에 실패했습니다.';
      showErrorDialog(context, message);
    }
  }

  Future<void> _confirmDelete(HotelModel hotel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('호텔 삭제'),
        content: Text('${hotel.name}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await context.read<HotelProvider>().deleteHotel(
      hotel.hotelId,
    );
    if (success || !mounted) return;

    final message =
        context.read<HotelProvider>().errorMessage ?? '호텔 삭제에 실패했습니다.';
    showErrorDialog(context, message);
  }

  void _selectHotel(HotelModel hotel) {
    final hotelProvider = context.read<HotelProvider>();
    if (_activeRole == HotelSelectionRole.start) {
      hotelProvider.selectStartHotel(hotel);
      if (_roundTripSameHotel) hotelProvider.selectEndHotel(hotel);
    } else {
      hotelProvider.selectEndHotel(hotel);
    }
  }

  Widget _buildMapPicker(BuildContext context) {
    return widget.mapRepository.buildMap(
      initialLatitude: _defaultLatitude,
      initialLongitude: _defaultLongitude,
      onCenterChanged: (center) => setState(() => _center = center),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotelProvider = context.watch<HotelProvider>();
    final tripProvider = context.watch<TripProvider>();
    final dayLabel =
        '${tripProvider.activeDayNumber ?? tripProvider.nextDayNumber}일차';
    final activeHotel = _activeRole == HotelSelectionRole.start
        ? hotelProvider.selectedStartHotel
        : hotelProvider.selectedEndHotel;
    final isSearchActive = _searchController.text.trim().isNotEmpty;

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
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$dayLabel 호텔 선택',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _RoleTab(
                      label: '시작 호텔',
                      active: _activeRole == HotelSelectionRole.start,
                      onTap: () => setState(
                        () => _activeRole = HotelSelectionRole.start,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RoleTab(
                      label: '종료 호텔',
                      active: _activeRole == HotelSelectionRole.end,
                      onTap: () =>
                          setState(() => _activeRole = HotelSelectionRole.end),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint2,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: const InputDecoration(
                              hintText: '숙소 이름이나 주소를 검색하세요',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        if (isSearchActive)
                          InkWell(
                            onTap: _clearSearch,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (isSearchActive) ...[
                    if (hotelProvider.isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: LoadingIndicator(),
                      )
                    else if (hotelProvider.searchState == ViewState.error)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            hotelProvider.searchErrorMessage ?? '검색에 실패했습니다.',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else if (hotelProvider.searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            '검색 결과가 없어요. 지도에서 직접 골라보세요.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      for (final candidate in hotelProvider.searchResults) ...[
                        _CandidateTile(
                          candidate: candidate,
                          onTap: _isSaving
                              ? null
                              : () => _saveCandidate(candidate),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                  ] else ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildMapPicker(context),
                            IgnorePointer(
                              child: Icon(
                                Icons.location_pin,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '지도를 움직여 호텔 위치를 지정하세요',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: '호텔 이름',
                        prefixIcon: Icon(Icons.hotel_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrimaryButton(
                      label: '이 위치를 호텔로 저장',
                      icon: Icons.check_rounded,
                      isLoading: _isSaving,
                      onPressed: _saveCurrentLocation,
                    ),
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '저장된 호텔',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (hotelProvider.hotels.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            '저장된 호텔이 없습니다.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      for (final hotel in hotelProvider.hotels) ...[
                        HotelCard(
                          hotel: hotel,
                          selected: activeHotel?.hotelId == hotel.hotelId,
                          onTap: () => setState(() => _selectHotel(hotel)),
                          onDelete: () => _confirmDelete(hotel),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  if (_activeRole == HotelSelectionRole.start)
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(
                          () => _roundTripSameHotel = !_roundTripSameHotel,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _roundTripSameHotel
                                    ? AppColors.accentCyan
                                    : AppColors.surfaceTint2,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: _roundTripSameHotel
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                '종료 호텔도 동일 (왕복)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 12,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _RoleTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceTint2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final HotelSearchCandidate candidate;
  final VoidCallback? onTap;

  const _CandidateTile({required this.candidate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint1,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    candidate.address ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
