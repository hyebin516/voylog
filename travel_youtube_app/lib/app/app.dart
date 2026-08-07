import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/bookmark_folder_provider.dart';
import '../providers/bookmark_provider.dart';
import '../providers/hotel_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/location_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/recommendation_provider.dart';
import '../providers/recommendation_wizard_provider.dart';
import '../providers/trip_provider.dart';
import '../providers/video_provider.dart';
import '../routes/app_routes.dart';

class TravelYoutubeApp extends StatelessWidget {
  const TravelYoutubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VideoProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        ChangeNotifierProvider(create: (_) => HotelProvider()),
        ChangeNotifierProvider(create: (_) => ItineraryProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationWizardProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkFolderProvider()),
        ChangeNotifierProvider(create: (_) => NotificationSettingsProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationProvider()),
      ],
      child: MaterialApp(
        title: '여행 유튜브 요약',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
