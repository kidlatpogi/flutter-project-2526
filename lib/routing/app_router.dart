import 'package:flutter/material.dart';
import '../features/splash/screens/splash_screen1.dart';
import '../features/splash/screens/splash_screen2.dart';
import '../features/splash/screens/splash_screen3.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/create_account_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/dashboard/screens/main_dashboard.dart';
import '../features/script/screens/script_screen.dart';
import '../features/analysis/screens/progress_analytics_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/change_password_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/test_audio_video_screen.dart';
import '../features/practice/screens/practice_setup_screen.dart';
import 'route_names.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash1:
        return MaterialPageRoute(builder: (_) => const SplashScreen1());
      case RouteNames.splash2:
        return MaterialPageRoute(builder: (_) => const SplashScreen2());
      case RouteNames.splash3:
        return MaterialPageRoute(builder: (_) => const SplashScreen3());
      case RouteNames.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case RouteNames.createAccount:
        return MaterialPageRoute(builder: (_) => const CreateAccountScreen());
      case RouteNames.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case RouteNames.verifyEmail:
        return MaterialPageRoute(builder: (_) => const VerifyEmailScreen());
      case RouteNames.resetPassword:
        return MaterialPageRoute(builder: (_) => const ResetPasswordScreen());
      case RouteNames.dashboard:
        return MaterialPageRoute(builder: (_) => const MainDashboard());
      case RouteNames.script:
        return MaterialPageRoute(builder: (_) => const ScriptScreen());
      case RouteNames.progress:
        return MaterialPageRoute(builder: (_) => const ProgressAnalyticsScreen());
      case RouteNames.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case RouteNames.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case RouteNames.practiceSetup:
        return MaterialPageRoute(builder: (_) => const PracticeSetupScreen());
      case RouteNames.changePassword:
        return MaterialPageRoute(
          builder: (_) => const ChangePasswordScreen(),
          fullscreenDialog: true,
        );
      case RouteNames.testAudioVideo:
        return MaterialPageRoute(
          builder: (_) => const TestAudioVideoScreen(),
          fullscreenDialog: true,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}