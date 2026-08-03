import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/models/hotel_model.dart';
import 'package:travel_youtube_app/providers/hotel_provider.dart';
import 'package:travel_youtube_app/repositories/hotel_repository.dart';
import 'package:travel_youtube_app/utils/view_state.dart';

const HotelModel _hotelA = HotelModel(hotelId: 'h-a', name: 'Hotel A', address: 'addr a', latitude: 37.5, longitude: 127.0);
const HotelModel _hotelB = HotelModel(hotelId: 'h-b', name: 'Hotel B', address: 'addr b', latitude: 37.6, longitude: 127.1);

class FakeHotelRepository extends HotelRepository {
  List<HotelModel> hotelsToReturn = [];
  ApiException? listError;
  ApiException? createError;
  HotelModel? createdHotel;

  @override
  Future<List<HotelModel>> listHotels() async {
    if (listError != null) throw listError!;
    return hotelsToReturn;
  }

  @override
  Future<HotelModel> createHotel(HotelModel hotel) async {
    if (createError != null) throw createError!;
    return createdHotel ?? hotel;
  }
}

void main() {
  late FakeHotelRepository repository;
  late HotelProvider provider;

  setUp(() {
    repository = FakeHotelRepository();
    provider = HotelProvider(repository: repository);
  });

  group('loadHotels', () {
    test('populates hotels on success', () async {
      repository.hotelsToReturn = [_hotelA, _hotelB];

      await provider.loadHotels();

      expect(provider.state, ViewState.success);
      expect(provider.hotels, [_hotelA, _hotelB]);
    });

    test('sets an error state and friendly message on failure', () async {
      repository.listError = const ApiException(code: 'INTERNAL_ERROR', message: 'boom');

      await provider.loadHotels();

      expect(provider.state, ViewState.error);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('createHotel', () {
    test('prepends the newly-created hotel to the list', () async {
      repository.hotelsToReturn = [_hotelA];
      await provider.loadHotels();
      repository.createdHotel = _hotelB;

      final result = await provider.createHotel(_hotelB);

      expect(result, _hotelB);
      expect(provider.hotels, [_hotelB, _hotelA]);
    });

    test('returns null and sets a friendly error message on failure', () async {
      repository.createError = const ApiException(code: 'INVALID_REQUEST', message: 'boom');

      final result = await provider.createHotel(_hotelA);

      expect(result, isNull);
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('start/end hotel selection and round-trip derivation', () {
    test('isRoundTrip is false until both start and end hotels are selected', () {
      expect(provider.isRoundTrip, isFalse);
      provider.selectStartHotel(_hotelA);
      expect(provider.isRoundTrip, isFalse);
    });

    test('isRoundTrip is true when the same hotel is selected for both ends', () {
      provider.selectStartHotel(_hotelA);
      provider.selectEndHotel(_hotelA);

      expect(provider.isRoundTrip, isTrue);
    });

    test('isRoundTrip is false when start and end hotels differ (hotel-to-hotel)', () {
      provider.selectStartHotel(_hotelA);
      provider.selectEndHotel(_hotelB);

      expect(provider.isRoundTrip, isFalse);
      expect(provider.selectedStartHotel, _hotelA);
      expect(provider.selectedEndHotel, _hotelB);
    });

    test('clearSelection resets both start and end hotels', () {
      provider.selectStartHotel(_hotelA);
      provider.selectEndHotel(_hotelA);

      provider.clearSelection();

      expect(provider.selectedStartHotel, isNull);
      expect(provider.selectedEndHotel, isNull);
      expect(provider.isRoundTrip, isFalse);
    });
  });
}
