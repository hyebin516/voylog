import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'services/kakao_auth_service.dart';
import 'services/map_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // google_fonts defaults to fetching font files from Google's CDN at
  // runtime, which throws when the device has no network access (or the
  // domain is blocked). A native app's core typography must not depend on
  // a live network call, so this disables runtime fetching -- text just
  // falls back to the platform default font until real font files are
  // bundled locally as assets instead.
  GoogleFonts.config.allowRuntimeFetching = false;

  // .env is git-ignored; isOptional keeps the app runnable (with Env's
  // fallback defaults) even if a developer hasn't created it yet.
  await dotenv.load(fileName: '.env', isOptional: true);

  MapService.initialize();
  await KakaoAuthService.initialize();
  runApp(const TravelYoutubeApp());
}
