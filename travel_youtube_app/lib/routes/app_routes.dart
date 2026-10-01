import 'package:flutter/material.dart';

import '../models/shared_route_model.dart';
import '../models/place_model.dart';
import '../models/saved_walking_course_model.dart';
import '../screens/bookmark_folder_detail_screen.dart';
import '../screens/bookmark_folder_list_screen.dart';
import '../screens/bookmark_folder_picker_screen.dart';
import '../screens/customer_service_screen.dart';
import '../screens/support_inquiry_screen.dart';
import '../screens/day_folder_select_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/hotel_search_screen.dart';
import '../screens/intro_screen.dart';
import '../screens/login_screen.dart';
import '../screens/my_page_screen.dart';
import '../screens/nearby_recommendations_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/password_reset_otp_screen.dart';
import '../screens/place_detail_screen.dart';
import '../screens/recommendation_duration_screen.dart';
import '../screens/recommendation_region_screen.dart';
import '../screens/recommendation_results_screen.dart';
import '../screens/recommendation_theme_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/route_planner_screen.dart';
import '../screens/saved_walking_course_detail_screen.dart';
import '../screens/saved_walking_courses_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/similar_taste_recommendations_screen.dart';
import '../screens/signup_otp_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/start_point_picker_screen.dart';
import '../screens/shared_route_detail_screen.dart';
import '../screens/taste_preference_screen.dart';
import '../screens/trip_detail_screen.dart';
import '../screens/trip_list_screen.dart';
import '../screens/trip_overview_screen.dart';
import '../screens/video_analysis_screen.dart';
import '../screens/walking_course_region_screen.dart';
import '../screens/walking_course_result_screen.dart';
import '../widgets/app_bottom_nav_shell.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String intro = '/intro';
  static const String login = '/login';
  static const String home = '/home';
  static const String videoAnalysis = '/video-analysis';
  static const String placeDetail = '/place-detail';
  static const String dayFolderSelect = '/day-folder-select';
  static const String hotelSearch = '/hotel-search';
  static const String routePlanner = '/route-planner';
  static const String tripList = '/trips';
  static const String tripDetail = '/trip-detail';
  static const String tripOverview = '/trip-overview';
  static const String myPage = '/my-page';
  static const String settings = '/settings';
  static const String recommendationRegion = '/recommendation/region';
  static const String recommendationTheme = '/recommendation/theme';
  static const String recommendationDuration = '/recommendation/duration';
  static const String recommendationResults = '/recommendation/results';
  static const String bookmarkFolders = '/bookmark-folders';
  static const String bookmarkFolderDetail = '/bookmark-folder-detail';
  static const String bookmarkFolderPicker = '/bookmark-folder-picker';
  static const String notificationSettings = '/notification-settings';
  static const String customerService = '/customer-service';
  static const String supportInquiry = '/customer-service/inquiry';
  static const String signup = '/signup';
  static const String signupOtp = '/signup/otp';
  static const String forgotPassword = '/forgot-password';
  static const String passwordResetOtp = '/forgot-password/otp';
  static const String resetPassword = '/forgot-password/reset';
  static const String nearbyRecommendations = '/recommendations/nearby';
  static const String tastePreferences = '/taste-preferences';
  static const String walkingCourseRegion = '/walking-course/region';
  static const String startPointPicker = '/walking-course/start-point';
  static const String walkingCourseResult = '/walking-course/result';
  static const String savedWalkingCourses = '/walking-courses/saved';
  static const String savedWalkingCourseDetail =
      '/walking-courses/saved-detail';
  static const String sharedRouteDetail = '/routes/shared-detail';
  static const String similarTasteRecommendations =
      '/recommendations/similar-taste';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case AppRoutes.intro:
        return MaterialPageRoute(
          builder: (_) => const IntroScreen(),
          settings: settings,
        );
      case AppRoutes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const AppBottomNavShell(),
          settings: settings,
        );
      case AppRoutes.videoAnalysis:
        return MaterialPageRoute(
          builder: (_) => const VideoAnalysisScreen(),
          settings: settings,
        );
      case AppRoutes.placeDetail:
        // Usually just the place. The home taste carousel also passes how
        // many similar-taste users saved it, which only it knows.
        final args = settings.arguments;
        final place = args is PlaceDetailArgs ? args.place : args as PlaceModel;
        return MaterialPageRoute(
          builder: (_) => PlaceDetailScreen(
            place: place,
            savedCount: args is PlaceDetailArgs ? args.savedCount : null,
          ),
          settings: settings,
        );
      case AppRoutes.dayFolderSelect:
        return MaterialPageRoute(
          builder: (_) => const DayFolderSelectScreen(),
          settings: settings,
        );
      case AppRoutes.hotelSearch:
        final args = settings.arguments as HotelSearchScreenArgs;
        return MaterialPageRoute(
          builder: (_) => HotelSearchScreen(role: args.role),
          settings: settings,
        );
      case AppRoutes.routePlanner:
        return MaterialPageRoute(
          builder: (_) => const RoutePlannerScreen(),
          settings: settings,
        );
      case AppRoutes.tripList:
        return MaterialPageRoute(
          builder: (_) => const TripListScreen(),
          settings: settings,
        );
      case AppRoutes.tripDetail:
        final tripId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => TripDetailScreen(tripId: tripId),
          settings: settings,
        );
      case AppRoutes.tripOverview:
        final tripId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => TripOverviewScreen(tripId: tripId),
          settings: settings,
        );
      case AppRoutes.myPage:
        return MaterialPageRoute(
          builder: (_) => const MyPageScreen(),
          settings: settings,
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
      case AppRoutes.recommendationRegion:
        return MaterialPageRoute(
          builder: (_) => const RecommendationRegionScreen(),
          settings: settings,
        );
      case AppRoutes.recommendationTheme:
        return MaterialPageRoute(
          builder: (_) => const RecommendationThemeScreen(),
          settings: settings,
        );
      case AppRoutes.recommendationDuration:
        return MaterialPageRoute(
          builder: (_) => const RecommendationDurationScreen(),
          settings: settings,
        );
      case AppRoutes.recommendationResults:
        return MaterialPageRoute(
          builder: (_) => const RecommendationResultsScreen(),
          settings: settings,
        );
      case AppRoutes.bookmarkFolders:
        return MaterialPageRoute(
          builder: (_) => const BookmarkFolderListScreen(),
          settings: settings,
        );
      case AppRoutes.bookmarkFolderDetail:
        final folderId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => BookmarkFolderDetailScreen(folderId: folderId),
          settings: settings,
        );
      case AppRoutes.bookmarkFolderPicker:
        final folderId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => BookmarkFolderPickerScreen(folderId: folderId),
          settings: settings,
        );
      case AppRoutes.notificationSettings:
        return MaterialPageRoute(
          builder: (_) => const NotificationSettingsScreen(),
          settings: settings,
        );
      case AppRoutes.customerService:
        return MaterialPageRoute(
          builder: (_) => const CustomerServiceScreen(),
          settings: settings,
        );
      case AppRoutes.supportInquiry:
        return MaterialPageRoute(
          builder: (_) => const SupportInquiryScreen(),
          settings: settings,
        );
      case AppRoutes.signup:
        return MaterialPageRoute(
          builder: (_) => const SignupScreen(),
          settings: settings,
        );
      // Typed <bool>: the email screen awaits `pushNamed<bool>` for the
      // verified flag, and Navigator casts the generated route to
      // Route<bool?>. An untyped MaterialPageRoute<dynamic> fails that cast,
      // so the code was emailed but the entry screen never opened.
      case AppRoutes.signupOtp:
        final email = settings.arguments as String;
        return MaterialPageRoute<bool>(
          builder: (_) => SignupOtpScreen(email: email),
          settings: settings,
        );
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
          settings: settings,
        );
      // Typed <bool> for the same reason as signupOtp above.
      case AppRoutes.passwordResetOtp:
        final email = settings.arguments as String;
        return MaterialPageRoute<bool>(
          builder: (_) => PasswordResetOtpScreen(email: email),
          settings: settings,
        );
      case AppRoutes.resetPassword:
        final email = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: email),
          settings: settings,
        );
      case AppRoutes.nearbyRecommendations:
        return MaterialPageRoute(
          builder: (_) => const NearbyRecommendationsScreen(),
          settings: settings,
        );
      case AppRoutes.tastePreferences:
        return MaterialPageRoute(
          builder: (_) => const TastePreferenceScreen(),
          settings: settings,
        );
      case AppRoutes.walkingCourseRegion:
        return MaterialPageRoute(
          builder: (_) => const WalkingCourseRegionScreen(),
          settings: settings,
        );
      case AppRoutes.startPointPicker:
        return MaterialPageRoute(
          builder: (_) => const StartPointPickerScreen(),
          settings: settings,
        );
      case AppRoutes.walkingCourseResult:
        return MaterialPageRoute(
          builder: (_) => const WalkingCourseResultScreen(),
          settings: settings,
        );
      case AppRoutes.savedWalkingCourses:
        return MaterialPageRoute(
          builder: (_) => const SavedWalkingCoursesScreen(),
          settings: settings,
        );
      case AppRoutes.savedWalkingCourseDetail:
        final course = settings.arguments as SavedWalkingCourseModel;
        return MaterialPageRoute(
          builder: (_) => SavedWalkingCourseDetailScreen(course: course),
          settings: settings,
        );
      case AppRoutes.sharedRouteDetail:
        final sharedRoute = settings.arguments as SharedRouteModel;
        return MaterialPageRoute(
          builder: (_) => SharedRouteDetailScreen(route: sharedRoute),
          settings: settings,
        );
      case AppRoutes.similarTasteRecommendations:
        return MaterialPageRoute(
          builder: (_) => const SimilarTasteRecommendationsScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('알 수 없는 경로: ${settings.name}')),
          ),
          settings: settings,
        );
    }
  }
}
