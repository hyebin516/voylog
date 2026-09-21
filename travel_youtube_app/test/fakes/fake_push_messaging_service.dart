import 'dart:async';

import 'package:travel_youtube_app/services/push_messaging_service.dart';

/// Stands in for the Firebase SDK under `flutter test` -- the real one needs
/// a native platform channel (CLAUDE.md's real/fake rule for platform
/// features).
class FakePushMessagingService implements PushMessagingService {
  FakePushMessagingService({this.permissionGranted = true, this.token = 'fcm-token'});

  bool permissionGranted;
  String? token;
  int permissionRequests = 0;
  int tokenReads = 0;

  final StreamController<String> refreshController = StreamController<String>.broadcast();

  @override
  Future<bool> requestPermission() async {
    permissionRequests += 1;
    return permissionGranted;
  }

  @override
  Future<String?> getToken() async {
    tokenReads += 1;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refreshController.stream;
}
