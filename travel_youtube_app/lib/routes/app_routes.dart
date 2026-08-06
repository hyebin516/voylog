import 'package:flutter/material.dart';

import '../models/place_model.dart';
import '../screens/bookmark_screen.dart';
import '../screens/home_screen.dart';
import '../screens/hotel_search_screen.dart';
import '../screens/login_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/place_detail_screen.dart';
import '../screens/recommendation_duration_screen.dart';
import '../screens/recommendation_region_screen.dart';
import '../screens/recommendation_results_screen.dart';
import '../screens/recommendation_theme_screen.dart';
import '../screens/route_planner_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/trip_detail_screen.dart';
import '../screens/trip_list_screen.dart';
import '../screens/video_analysis_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String videoAnalysis = '/video-analysis';
  static const String placeDetail = '/place-detail';
  static const String bookmarks = '/bookmarks';
  static const String hotelSearch = '/hotel-search';
  static const String routePlanner = '/route-planner';
  static const String tripList = '/trips';
  static const String tripDetail = '/trip-detail';
  static const String myPage = '/my-page';
  static const String settings = '/settings';
  static const String recommendationRegion = '/recommendation/region';
  static const String recommendationTheme = '/recommendation/theme';
  static const String recommendationDuration = '/recommendation/duration';
  static const String recommendationResults = '/recommendation/results';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen(), settings: settings);
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen(), settings: settings);
      case AppRoutes.videoAnalysis:
        return MaterialPageRoute(builder: (_) => const VideoAnalysisScreen(), settings: settings);
      case AppRoutes.placeDetail:
        final place = settings.arguments as PlaceModel;
        return MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: place), settings: settings);
      case AppRoutes.bookmarks:
        return MaterialPageRoute(builder: (_) => const BookmarkScreen(), settings: settings);
      case AppRoutes.hotelSearch:
        final args = settings.arguments as HotelSearchScreenArgs;
        return MaterialPageRoute(builder: (_) => HotelSearchScreen(role: args.role), settings: settings);
      case AppRoutes.routePlanner:
        return MaterialPageRoute(builder: (_) => const RoutePlannerScreen(), settings: settings);
      case AppRoutes.tripList:
        return MaterialPageRoute(builder: (_) => const TripListScreen(), settings: settings);
      case AppRoutes.tripDetail:
        final tripId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => TripDetailScreen(tripId: tripId), settings: settings);
      case AppRoutes.myPage:
        return MaterialPageRoute(builder: (_) => const MyPageScreen(), settings: settings);
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen(), settings: settings);
      case AppRoutes.recommendationRegion:
        return MaterialPageRoute(builder: (_) => const RecommendationRegionScreen(), settings: settings);
      case AppRoutes.recommendationTheme:
        return MaterialPageRoute(builder: (_) => const RecommendationThemeScreen(), settings: settings);
      case AppRoutes.recommendationDuration:
        return MaterialPageRoute(builder: (_) => const RecommendationDurationScreen(), settings: settings);
      case AppRoutes.recommendationResults:
        return MaterialPageRoute(builder: (_) => const RecommendationResultsScreen(), settings: settings);
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(body: Center(child: Text('알 수 없는 경로: ${settings.name}'))),
          settings: settings,
        );
    }
  }
}
