import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/hotel_model.dart';
import '../models/map_view_types.dart';
import '../providers/hotel_provider.dart';
import '../repositories/map_repository.dart';
import '../widgets/error_view.dart';
import '../widgets/hotel_card.dart';
import '../widgets/primary_button.dart';

enum HotelSelectionRole { start, end }

class HotelSearchScreenArgs {
  final HotelSelectionRole role;

  const HotelSearchScreenArgs({required this.role});
}

/// Default map center (Seoul City Hall) used before the user has picked
/// a location. The user must drag the map to their desired hotel and
/// confirm — coordinates are never entered manually.
const double _defaultLatitude = 37.5665;
const double _defaultLongitude = 126.9780;

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

  MapCenter _center = const MapCenter(latitude: _defaultLatitude, longitude: _defaultLongitude);
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
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentLocation() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    final hotel = await context.read<HotelProvider>().createHotel(
          HotelModel(
            hotelId: '',
            name: name,
            address: '',
            latitude: _center.latitude,
            longitude: _center.longitude,
          ),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (hotel != null) {
      _confirmSelection(hotel);
    } else if (context.mounted) {
      final message = context.read<HotelProvider>().errorMessage ?? '호텔 저장에 실패했습니다.';
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await context.read<HotelProvider>().deleteHotel(hotel.hotelId);
    if (success || !mounted) return;

    final message = context.read<HotelProvider>().errorMessage ?? '호텔 삭제에 실패했습니다.';
    showErrorDialog(context, message);
  }

  void _confirmSelection(HotelModel hotel) {
    final hotelProvider = context.read<HotelProvider>();
    if (widget.role == HotelSelectionRole.start) {
      hotelProvider.selectStartHotel(hotel);
    } else {
      hotelProvider.selectEndHotel(hotel);
    }
    Navigator.pop(context, hotel);
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
    final title = widget.role == HotelSelectionRole.start ? '시작 호텔 선택' : '종료 호텔 선택';
    final hotelProvider = context.watch<HotelProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildMapPicker(context),
                IgnorePointer(
                  child: Icon(Icons.location_pin, size: 44, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('지도를 움직여 호텔 위치를 지정하세요', style: Theme.of(context).textTheme.bodySmall),
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
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('저장된 호텔', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: hotelProvider.hotels.isEmpty
                ? const Center(child: Text('저장된 호텔이 없습니다.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: hotelProvider.hotels.length,
                    separatorBuilder: (context, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final hotel = hotelProvider.hotels[index];
                      return HotelCard(
                        hotel: hotel,
                        onTap: () => _confirmSelection(hotel),
                        onDelete: () => _confirmDelete(hotel),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
