import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../splash/screens/splash_screen1.dart';
import '../../dashboard/screens/main_dashboard.dart';
import 'login_screen.dart';
import 'nickname_setup_screen.dart';

// For URL cleanup on web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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

  @override
  void initState() {
    super.initState();
    _cleanupOAuthUrl();
    _checkAuthStatus();
    _listenToAuthChanges();
  }

  /// Clean up OAuth parameters from URL after successful login
  void _cleanupOAuthUrl() {
    if (!kIsWeb) return;
    
    try {
      final location = html.window.location;
      final href = location.href;
      
      // Check if URL contains OAuth tokens
      if (href.contains('access_token=') || 
          href.contains('provider_token=') ||
          href.contains('refresh_token=') ||
          href.contains('expires_at=')) {
        print('AuthWrapper: Cleaning OAuth tokens from URL');
        // Replace URL to remove all fragments (tokens)
        // Keep the path but remove the fragment containing tokens
        final baseUrl = href.split('#')[0];
        html.window.history.replaceState(null, '', baseUrl);
      }
    } catch (e) {
      print('AuthWrapper: Error cleaning OAuth URL: $e');
    }
  }

  /// Listen to authentication state changes
  void _listenToAuthChanges() {
    _authSubscription = _authService.authStateChanges.listen((authState) {
      final event = authState.event;
      print('AuthWrapper: Auth event received: $event');
      
      if (!mounted) return;
      
      // Handle sign out immediately - don't wait for _checkAuthStatus
      if (event == AuthChangeEvent.signedOut) {
        print('AuthWrapper: User signed out, showing login screen');
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

  /// Check current authentication status and route accordingly
  Future<void> _checkAuthStatus() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      await _authService.refreshSessionIfNeeded();
      
      if (!mounted) return;
      
      if (_authService.isLoggedIn) {
        // User is logged in, check if they have a profile
        print('AuthWrapper: User is logged in, checking profile...');
        
        // Check if user has nickname
        bool hasNickname = false;
        try {
          final profile = await _userProfileService.getUserProfile();
          if (profile != null && profile['is_active'] == false) {
            print('AuthWrapper: Account deactivated, signing out');
            await _authService.signOut();
            if (!mounted) return;
            _targetWidget = const LoginScreen();
            return;
          }
          hasNickname = profile != null &&
              profile['has_profile'] == true &&
              profile['nickname'] != null &&
              (profile['nickname'] as String).isNotEmpty;
          print('AuthWrapper: Has nickname: $hasNickname');
        } catch (e) {
          print('AuthWrapper: Error checking nickname (backend might be down): $e');
          // If backend is down, skip nickname check and go to dashboard
          hasNickname = true;
        }

        if (!mounted) return;
        
        if (hasNickname) {
          // User has profile, go to dashboard
          _targetWidget = const MainDashboard();
        } else {
          // User needs to set up nickname
          _targetWidget = const NicknameSetupScreen();
        }
      } else {
        // User is not logged in, go directly to login screen
        print('AuthWrapper: User is not logged in, showing login screen');
        _targetWidget = const LoginScreen();
      }
    } catch (e) {
      print('AuthWrapper: Error checking auth status: $e');
      _targetWidget = const LoginScreen();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
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