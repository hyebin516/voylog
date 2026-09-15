import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

/// Lays screens out on a portrait phone (360x800 logical) instead of the
/// test binding's default 800x600 landscape surface. The app is phone-only,
/// and on the default surface content below the first card never builds
/// (lists build lazily), so finders and taps miss widgets that are plainly
/// on screen on a real device.
void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}
