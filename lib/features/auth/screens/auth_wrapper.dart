import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../routing/route_names.dart';
import '../../splash/screens/splash_screen1.dart';
import '../../dashboard/screens/main_dashboard.dart';
import 'nickname_setup_screen.dart';

/// Wrapper that handles authentication state and routing
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final UserProfileService _userProfileService = UserProfileService();
  bool _isLoading = true;
  Widget _targetWidget = const SplashScreen1();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _listenToAuthChanges();
  }

  /// Listen to authentication state changes
  void _listenToAuthChanges() {
    _authService.authStateChanges.listen((authState) {
      if (mounted) {
        _checkAuthStatus();
      }
    });
  }

  /// Check current authentication status and route accordingly
  Future<void> _checkAuthStatus() async {
    setState(() => _isLoading = true);

    try {
      await _authService.refreshSessionIfNeeded();
      if (_authService.isLoggedIn) {
        // User is logged in, check if they have a profile
        print('User is logged in, checking profile...');
        
        // Check if user has nickname
        bool hasNickname = false;
        try {
          hasNickname = await _userProfileService.hasNickname();
          print('Has nickname: $hasNickname');
        } catch (e) {
          print('Error checking nickname (backend might be down): $e');
          // If backend is down, skip nickname check and go to dashboard
          hasNickname = true;
        }

        if (hasNickname) {
          // User has profile, go to dashboard
          _targetWidget = const MainDashboard();
        } else {
          // User needs to set up nickname
          _targetWidget = const NicknameSetupScreen();
        }
      } else {
        // User is not logged in, show splash screen
        print('User is not logged in, showing splash screen');
        _targetWidget = const SplashScreen1();
      }
    } catch (e) {
      print('Error checking auth status: $e');
      _targetWidget = const SplashScreen1();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _userProfileService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _targetWidget;
  }
}