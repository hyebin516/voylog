import 'package:travel_youtube_app/models/api_exception.dart';
import 'package:travel_youtube_app/repositories/device_token_repository.dart';

class FakeDeviceTokenRepository implements DeviceTokenRepository {
  final List<({String token, String platform})> registered = [];
  final List<String> unregistered = [];
  ApiException? registerError;
  ApiException? unregisterError;

  @override
  Future<void> register(String token, String platform) async {
    if (registerError != null) throw registerError!;
    registered.add((token: token, platform: platform));
  }

  @override
  Future<void> unregister(String token) async {
    if (unregisterError != null) throw unregisterError!;
    unregistered.add(token);
  }
}
