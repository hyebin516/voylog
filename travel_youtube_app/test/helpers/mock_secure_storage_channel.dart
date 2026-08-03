import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// DioClient's request interceptor reads the JWT via FlutterSecureStorage on
/// every request. There's no real platform binding in `flutter test`, so
/// without this the plugin channel throws a MissingPluginException and every
/// request fails before it ever reaches a fake Dio adapter. Call this once
/// (e.g. in `setUpAll`) in any test that exercises a real repository talking
/// to the real `DioClient().dio`.
void installMockSecureStorageChannel() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    _secureStorageChannel,
    (MethodCall call) async {
      switch (call.method) {
        case 'read':
          return null; // simulate "not logged in" — no stored JWT
        case 'write':
        case 'delete':
          return null;
        default:
          return null;
      }
    },
  );
}
