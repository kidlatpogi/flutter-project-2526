import 'package:flutter/material.dart';
import '../features/splash/screens/splash_screen1.dart';
import '../features/splash/screens/splash_screen2.dart';
import '../features/splash/screens/splash_screen3.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/create_account_screen.dart';
import '../features/auth/screens/nickname_setup_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/auth_wrapper.dart';
import '../features/dashboard/screens/main_dashboard.dart';
import '../features/dashboard/screens/sessions_screen.dart';
import '../features/script/screens/script_screen.dart';
import '../features/script/screens/create_script_screen.dart';
import '../features/script/screens/edit_script_screen.dart';
import '../features/analysis/screens/progress_analytics_screen.dart';
import '../features/analysis/screens/detailed_feedback_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/change_password_screen.dart';
import '../features/profile/screens/edit_nickname_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/test_audio_video_screen.dart';
import '../features/practice/screens/practice_setup_screen.dart';
import '../features/practice/screens/recording_session_screen.dart';
import '../features/practice/screens/analysis_result_screen.dart';
import '../data/models/analysis_model.dart';
import 'route_names.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.authWrapper:
        return MaterialPageRoute(builder: (_) => const AuthWrapper());
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
      case RouteNames.nicknameSetup:
        return MaterialPageRoute(builder: (_) => const NicknameSetupScreen());
      case RouteNames.forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case RouteNames.verifyEmail:
        final email = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: email),
        );
      case RouteNames.resetPassword:
        return MaterialPageRoute(builder: (_) => const ResetPasswordScreen());
      case RouteNames.dashboard:
        return MaterialPageRoute(builder: (_) => const MainDashboard());
      case RouteNames.sessions:
        return MaterialPageRoute(builder: (_) => const SessionsScreen());
      case RouteNames.script:
        return MaterialPageRoute(builder: (_) => const ScriptScreen());
      case RouteNames.createScript:
        return MaterialPageRoute(
          builder: (_) => const CreateScriptScreen(),
          fullscreenDialog: true,
        );
      case RouteNames.editScript:
        final script = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => EditScriptScreen(script: script),
          fullscreenDialog: true,
        );
      case RouteNames.progress:
        return MaterialPageRoute(
          builder: (_) => const ProgressAnalyticsScreen(),
        );
      case RouteNames.detailedFeedback:
        final args = settings.arguments;
        if (args is AnalysisModel) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => DetailedFeedbackScreen(analysisResult: args),
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) =>
                DetailedFeedbackScreen(sessionId: args['sessionId'] as String?),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DetailedFeedbackScreen(),
        );
      case RouteNames.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case RouteNames.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case RouteNames.practiceSetup:
        return MaterialPageRoute(builder: (_) => const PracticeSetupScreen());
      case RouteNames.recording:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => RecordingSessionScreen(
            isScripted: args?['isScripted'] as bool? ?? true,
            scriptTitle: args?['scriptTitle'] as String?,
            scriptContent: args?['scriptContent'] as String?,
          ),
        );
      case RouteNames.analysis:
        final args = settings.arguments;
        if (args is AnalysisModel) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AnalysisResultScreen(analysisResult: args),
          );
        }
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) =>
                AnalysisResultScreen(sessionId: args['sessionId'] as String?),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AnalysisResultScreen(),
        );
      case RouteNames.changePassword:
        return MaterialPageRoute(
          builder: (_) => const ChangePasswordScreen(),
          fullscreenDialog: true,
        );
      case RouteNames.editNickname:
        return MaterialPageRoute(
          builder: (_) => const EditNicknameScreen(),
          fullscreenDialog: true,
        );
      case RouteNames.testAudioVideo:
        return MaterialPageRoute(
          builder: (_) => const TestAudioVideoScreen(),
          fullscreenDialog: true,
        );
      default:
        // Check if this is an OAuth callback route (contains token parameters)
        final routeName = settings.name ?? '';
        if (routeName.contains('access_token') ||
            routeName.contains('provider_token') ||
            routeName.contains('refresh_token') ||
            routeName.contains('expires_at') ||
            routeName.contains('expires_in') ||
            routeName.contains('token_type') ||
            routeName.startsWith('access_token=')) {
          print('AppRouter: OAuth callback detected, routing to AuthWrapper');
          return MaterialPageRoute(builder: (_) => const AuthWrapper());
        }

        // Handle password reset error routes (expired OTP, etc.)
        if (routeName.contains('error=') ||
            routeName.contains('error_code=') ||
            routeName.contains('error_description=')) {
          print('AppRouter: Auth error detected: $routeName');
          // Parse error details for user-friendly message
          String errorMessage =
              'The password reset link has expired or is invalid.';
          if (routeName.contains('otp_expired')) {
            errorMessage =
                'The password reset link has expired. Please request a new one.';
          } else if (routeName.contains('access_denied')) {
            errorMessage = 'Access denied. The link may be invalid or expired.';
          }

          return MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.link_off,
                          size: 64,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Link Expired',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              RouteNames.forgotPassword,
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 50),
                          ),
                          child: const Text('Request New Link'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              RouteNames.login,
                              (route) => false,
                            );
                          },
                          child: const Text('Back to Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Unknown route - show error
        print('AppRouter: Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('No route defined for ${settings.name}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    child: const Text('Go Home'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
