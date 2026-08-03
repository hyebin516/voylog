import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/core/network/dio_client.dart';
import 'package:travel_youtube_app/models/hotel_model.dart';
import 'package:travel_youtube_app/repositories/hotel_repository.dart';

import '../helpers/fake_dio_adapter.dart';
import '../helpers/mock_secure_storage_channel.dart';

void main() {
  setUpAll(installMockSecureStorageChannel);

  test('listHotels maps the JSON hotels array into HotelModels', () async {
    final adapter = FakeDioAdapter(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'hotels': [
            {'hotelId': 'h1', 'name': 'Hotel A', 'address': 'Seoul', 'latitude': 37.5, 'longitude': 127.0},
          ],
        },
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    final hotels = await HotelRepository().listHotels();

    expect(hotels, hasLength(1));
    expect(hotels.first.name, 'Hotel A');
    expect(adapter.lastOptions?.path, '/hotels');
  });

  test('createHotel sends toCreateJson (never a raw hotelId) and maps the created hotel back', () async {
    final adapter = FakeDioAdapter(
      statusCode: 201,
      body: {
        'success': true,
        'data': {'hotelId': 'server-assigned-id', 'name': 'New Hotel', 'address': 'Busan', 'latitude': 35.1, 'longitude': 129.0},
      },
    );
    DioClient().dio.httpClientAdapter = adapter;

    const draft = HotelModel(hotelId: '', name: 'New Hotel', address: 'Busan', latitude: 35.1, longitude: 129.0);
    final created = await HotelRepository().createHotel(draft);

    expect(created.hotelId, 'server-assigned-id');
    expect(adapter.lastOptions?.data, {'name': 'New Hotel', 'address': 'Busan', 'latitude': 35.1, 'longitude': 129.0});
  });
}
