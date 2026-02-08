import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../splash/screens/splash_screen1.dart';
import '../../dashboard/screens/main_dashboard.dart';
import 'login_screen.dart';
import 'nickname_setup_screen.dart';
import 'reset_password_screen.dart';

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
  StreamSubscription<AuthState>? _authSubscription;
  bool _isCheckingAuth = false; // Debounce flag to prevent concurrent checks

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _listenToAuthChanges();
  }

  /// Listen to authentication state changes
  void _listenToAuthChanges() {
    _authSubscription = _authService.authStateChanges.listen((authState) {
      final event = authState.event;

      if (!mounted) return;

      // Check for recovery mode - user clicked password reset link
      if (_isInRecoveryMode()) {
        setState(() {
          _targetWidget = const ResetPasswordScreen();
          _isLoading = false;
        });
        return;
      }

      // Handle sign out immediately - don't wait for _checkAuthStatus
      if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _targetWidget = const LoginScreen();
          _isLoading = false;
        });
        return;
      }

      // For sign in or other events, check full auth status
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.initialSession) {
        _checkAuthStatus();
      }
    });
  }

  /// Check if we're in password recovery mode
  /// This happens when user clicks the "Set Password" link from email
  bool _isInRecoveryMode() {
    try {
      // Check by looking for recovery type in the URL
      // Supabase sends links like: https://app.com/path#access_token=...&type=recovery
      final url = Uri.base.toString();
      return url.contains('type=recovery');
    } catch (e) {
      return false;
    }
  }

  /// Check current authentication status and route accordingly
  Future<void> _checkAuthStatus() async {
    if (!mounted) return;

    // Debounce: if already checking, skip this call
    if (_isCheckingAuth) return;
    _isCheckingAuth = true;

    setState(() => _isLoading = true);

    try {
      // Check if we're in a password recovery flow
      // This happens when user clicks "Set Password" link from email
      if (_isInRecoveryMode()) {
        if (mounted) {
          setState(() => _targetWidget = const ResetPasswordScreen());
          return;
        }
      }

      await _authService.refreshSessionIfNeeded();

      if (!mounted) return;

      if (_authService.isLoggedIn) {
        // User is logged in
        bool isDeactivated = false;

        // Get user profile with a timeout to prevent hanging
        Map<String, dynamic>? profile;
        try {
          profile = await _userProfileService.getUserProfile().timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );

          // Check if account is deactivated
          if (profile != null && profile['is_active'] == false) {
            await _authService.signOut();
            if (!mounted) return;
            _targetWidget = const LoginScreen();
            isDeactivated = true;
          }
        } catch (e) {
          profile = null;
        }

        if (!mounted) return;

        // Only continue routing if account is not deactivated
        if (!isDeactivated) {
          // Determine if this is a brand new user (no profile exists)
          final bool isNewUser = profile == null;

          // For new users, don't auto-create profile - let them set nickname first
          if (isNewUser) {
            developer.log(
              'New user detected (no profile) - showing nickname setup',
            );
            _targetWidget = const NicknameSetupScreen();
          } else {
            developer.log('Existing user found - checking if nickname is set');
            // Check if user has nickname (for existing users)
            final hasNickname =
                profile['nickname'] != null &&
                (profile['nickname'] as String).isNotEmpty;

            if (hasNickname) {
              // User has profile with nickname, go to dashboard
              developer.log('Nickname found, navigating to dashboard');
              _targetWidget = const MainDashboard();
            } else {
              // User has profile but needs to set/update nickname
              developer.log('No nickname found, showing nickname setup');
              _targetWidget = const NicknameSetupScreen();
            }
          }
        }
      } else {
        // User is not logged in, go directly to login screen
        _targetWidget = const LoginScreen();
      }
    } catch (e) {
      developer.log('_checkAuthStatus error: $e');
      _targetWidget = const LoginScreen();
    } finally {
      _isCheckingAuth = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _targetWidget;
  }
}
