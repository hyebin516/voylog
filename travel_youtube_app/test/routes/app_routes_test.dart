import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_youtube_app/routes/app_routes.dart';

void main() {
  // Navigator casts a generated route to Route<T?> for pushNamed<T>. An
  // untyped MaterialPageRoute<dynamic> fails that cast at runtime -- the OTP
  // code was emailed but its entry screen never opened.
  for (final name in [AppRoutes.signupOtp, AppRoutes.passwordResetOtp]) {
    test('$name can be awaited with pushNamed<bool>', () {
      final route = AppRoutes.onGenerateRoute(
        RouteSettings(name: name, arguments: 'a@b.com'),
      );

      expect(route, isA<Route<bool?>>());
    });
  }
}
