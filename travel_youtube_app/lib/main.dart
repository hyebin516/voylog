import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'services/kakao_auth_service.dart';
import 'services/map_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env is git-ignored; isOptional keeps the app runnable (with Env's
  // fallback defaults) even if a developer hasn't created it yet.
  await dotenv.load(fileName: '.env', isOptional: true);

  MapService.initialize();
  await KakaoAuthService.initialize();
  runApp(const TravelYoutubeApp());
}
