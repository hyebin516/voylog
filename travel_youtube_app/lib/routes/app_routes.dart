import 'package:flutter/material.dart';

import '../screens/bookmark_screen.dart';
import '../screens/home_screen.dart';
import '../screens/hotel_search_screen.dart';
import '../screens/login_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/route_planner_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/video_analysis_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String videoAnalysis = '/video-analysis';
  static const String bookmarks = '/bookmarks';
  static const String hotelSearch = '/hotel-search';
  static const String routePlanner = '/route-planner';
  static const String myPage = '/my-page';
  static const String settings = '/settings';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case AppRoutes.videoAnalysis:
        return MaterialPageRoute(builder: (_) => const VideoAnalysisScreen());
      case AppRoutes.bookmarks:
        return MaterialPageRoute(builder: (_) => const BookmarkScreen());
      case AppRoutes.hotelSearch:
        final args = settings.arguments as HotelSearchScreenArgs;
        return MaterialPageRoute(builder: (_) => HotelSearchScreen(role: args.role));
      case AppRoutes.routePlanner:
        return MaterialPageRoute(builder: (_) => const RoutePlannerScreen());
      case AppRoutes.myPage:
        return MaterialPageRoute(builder: (_) => const MyPageScreen());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(body: Center(child: Text('알 수 없는 경로: ${settings.name}'))),
        );
    }
  }
}
