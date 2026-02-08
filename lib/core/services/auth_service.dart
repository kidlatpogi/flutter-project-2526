import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/web_oauth_utils.dart' as web_oauth;

/// Exception thrown when authentication fails
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message${code != null ? ' (code: $code)' : ''}';
}

/// Service handling all authentication operations with Supabase + Google Sign-In
class AuthService {
  // Supabase client instance
  final SupabaseClient _supabase = Supabase.instance.client;

  // Google Sign-In configuration
  // Web/Mobile Client ID from Google Cloud Console
  // This is the same ID used for both web and mobile platforms
  static const String _clientId =
      '224611722969-cegepmde5ctvv1f8llu07qt17t6d8l7q.apps.googleusercontent.com';

  late final GoogleSignIn _googleSignIn;

  AuthService() {
    // Web: clientId is set via meta tag in index.html, no serverClientId allowed
    // Mobile: use serverClientId for native flow
    _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: kIsWeb ? null : _clientId,
    );
  }

  /// Get the current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Get the current session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Get the current access token (JWT) for API calls
  String? get accessToken => currentSession?.accessToken;

  /// Check if user signed up with Google only (no password)
  bool get isGoogleOnlyUser {
    final user = currentUser;
    if (user == null) return false;
    // Check both 'providers' list and 'provider' string for robustness
    final providersList = user.appMetadata['providers'] as List? ?? [];
    final singleProvider = user.appMetadata['provider'] as String? ?? '';
    
    // User is Google-only if:
    // 1. providers list has exactly 'google' OR
    // 2. provider string is 'google' and 'email' is not in providers list
    if (providersList.isNotEmpty) {
      return providersList.length == 1 && providersList.contains('google');
    }
    return singleProvider == 'google';
  }

  /// Check if user has password authentication
  bool get hasPasswordAuth {
    final user = currentUser;
    if (user == null) return false;
    final providersList = user.appMetadata['providers'] as List? ?? [];
    final singleProvider = user.appMetadata['provider'] as String? ?? '';
    
    if (providersList.isNotEmpty) {
      return providersList.contains('email');
    }
    // If providers list is empty, check if the single provider is email
    return singleProvider == 'email';
  }

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Refresh session if token is near expiry
  Future<void> refreshSessionIfNeeded() async {
    final session = _supabase.auth.currentSession;
    if (session == null) return;

    final expiresAt = session.expiresAt;
    if (expiresAt == null) return;

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final now = DateTime.now().toUtc();

    // On web implicit flow, refresh token may be missing
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return;

    if (now.isAfter(expiry.subtract(const Duration(minutes: 1)))) {
      try {
        await _supabase.auth.refreshSession();
      } catch (e) {
        // Ignore refresh errors to avoid breaking flow on web implicit auth
      }
    }
  }

  /// Sign in with Google
  ///
  /// On Web: Uses Supabase OAuth flow (opens popup window)
  /// On Mobile: Uses native Google Sign-In flow
  ///
  /// Throws [AuthException] if sign-in fails or is cancelled
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: Get OAuth URL and open in a popup window
        // This keeps the original tab intact (no redirect)
        final redirectTo = Uri.base.origin;
        
        final res = await _supabase.auth.getOAuthSignInUrl(
          provider: OAuthProvider.google,
          redirectTo: redirectTo,
          queryParams: {
            'access_type': 'offline', 
            'prompt': 'select_account',
            'scope': 'openid email profile', // Explicitly request profile data
          },
        );
        
        // Open the OAuth URL in a popup window
        web_oauth.openOAuthPopup(res.url);
        
        // Return null - the auth state change listener in AuthWrapper
        // will detect the session from the popup via BroadcastChannel/localStorage
        return null;
      } else {
        // Mobile: Use native Google Sign-In flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          throw AuthException('Google sign-in was cancelled', code: 'cancelled');
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final String? idToken = googleAuth.idToken;
        final String? accessToken = googleAuth.accessToken;

        if (idToken == null) {
          throw AuthException(
            'Missing ID Token',
            code: 'missing_id_token',
          );
        }

        final AuthResponse response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );

        if (response.user == null) {
          throw AuthException(
            'Supabase authentication failed',
            code: 'supabase_auth_failed',
          );
        }

        return response.user;
      }
    } on AuthException {
      // Re-throw our custom exceptions
      rethrow;
    } on AuthApiException catch (e) {
      // Handle Supabase-specific errors
      throw AuthException(
        e.message,
        code: e.statusCode,
      );
    } catch (e) {
      // Handle any other errors
      throw AuthException(
        'An unexpected error occurred during sign-in: ${e.toString()}',
        code: 'unknown',
      );
    }
  }

  /// Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // If email confirmation is required, block login until verified
      if (response.user?.emailConfirmedAt == null) {
        await _supabase.auth.signOut();
        throw AuthException('Please verify your email before logging in.');
      }
      
      // Check if account is deactivated
      final isActive = await checkAccountActive(response.user!.id);
      if (!isActive) {
        await _supabase.auth.signOut();
        throw AuthException('Your account has been deactivated. Please contact support if you believe this is an error.');
      }
      
      return response.user;
    } on AuthApiException catch (e) {
      final message = e.message.toLowerCase();
      
      // Check for invalid credentials
      if (message.contains('invalid') || 
          message.contains('wrong') || 
          message.contains('incorrect')) {
        throw AuthException(
          'Invalid email or password. If you signed up with Google, please use the Google Sign-In button.',
          code: 'invalid_credentials',
        );
      }
      
      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign-in failed: ${e.toString()}');
    }
  }

  /// Register with email and password
  Future<User?> signUpWithEmail(String email, String password,
      {String? name}) async {
    try {
      final emailRedirectTo = kIsWeb ? Uri.base.origin : null;
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'full_name': name} : null,
        emailRedirectTo: emailRedirectTo,
      );
      if (response.user == null) {
        throw AuthException('Registration failed. Please try again.');
      }
      return response.user;
    } on AuthApiException catch (e) {
      final message = e.message.toLowerCase();
      
      // Check for duplicate email error
      if (message.contains('already') || 
          message.contains('registered') || 
          message.contains('exists') ||
          message.contains('duplicate') ||
          message.contains('user with this email already exists')) {
        throw AuthException(
          'This email is already registered. Please sign in instead or use a different email.',
          code: 'email_exists',
        );
      }
      
      final isRedirectError = message.contains('redirect') || message.contains('url');

      if (kIsWeb && isRedirectError) {
        try {
          final AuthResponse fallbackResponse = await _supabase.auth.signUp(
            email: email,
            password: password,
            data: name != null ? {'full_name': name} : null,
          );
          if (fallbackResponse.user == null) {
            throw AuthException('Registration failed. Please try again.');
          }
          return fallbackResponse.user;
        } on AuthApiException catch (fallbackError) {
          final fallbackMessage = fallbackError.message.toLowerCase();
          
          // Check for duplicate email in fallback as well
          if (fallbackMessage.contains('already') || 
              fallbackMessage.contains('registered') || 
              fallbackMessage.contains('exists') ||
              fallbackMessage.contains('duplicate') ||
              fallbackMessage.contains('user with this email already exists')) {
            throw AuthException(
              'This email is already registered. Please sign in instead or use a different email.',
              code: 'email_exists',
            );
          }
          
          throw AuthException(fallbackError.message,
              code: fallbackError.statusCode);
        }
      }

      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  /// Resend email confirmation link
  Future<void> resendConfirmationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } on AuthApiException catch (e) {
      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthException('Failed to resend confirmation: ${e.toString()}');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final redirectTo = kIsWeb ? '${Uri.base.origin}/#/reset-password' : null;
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );
    } on AuthApiException catch (e) {
      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthException('Failed to send reset email: ${e.toString()}');
    }
  }

  /// Verify current password by re-authenticating
  Future<void> verifyPassword(String password) async {
    final email = currentUser?.email;
    if (email == null || email.isEmpty) {
      throw AuthException('Email not available for this account.');
    }

    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthApiException catch (e) {
      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthException('Password verification failed: ${e.toString()}');
    }
  }

  /// Update password for current user (used for reset flow)
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthApiException catch (e) {
      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthException('Failed to update password: ${e.toString()}');
    }
  }

  /// Change password with old password verification
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    await verifyPassword(oldPassword);
    await updatePassword(newPassword);
  }

  /// Sign out from both Supabase and Google
  Future<void> signOut() async {
    try {
      // Sign out from Google (clears cached credentials)
      await _googleSignIn.signOut();

      // Sign out from Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      throw AuthException('Sign-out failed: ${e.toString()}');
    }
  }

  /// Get user profile data from Supabase
  Map<String, dynamic>? get userMetadata => currentUser?.userMetadata;

  /// Get user's display name
  String? get displayName =>
      userMetadata?['full_name'] ?? userMetadata?['display_name'] ?? userMetadata?['name'];

  /// Refresh current user data from Supabase
  Future<void> refreshUserData() async {
    try {
      await _supabase.auth.refreshSession();
    } catch (e) {
    }
  }

  /// Get user's email
  String? get email => currentUser?.email;

  /// Get user's avatar URL
  String? get avatarUrl =>
      userMetadata?['avatar_url'] ?? userMetadata?['picture'];

  /// Check if account is active (not deactivated)
  Future<bool> checkAccountActive(String userId) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('is_active, account_status')
          .eq('id', userId)
          .maybeSingle();
      
      if (response == null) {
        // No profile yet, account is active by default
        return true;
      }
      
      final isActive = response['is_active'] as bool? ?? true;
      final accountStatus = response['account_status'] as String? ?? 'Active';
      
      // Account is active if is_active is true AND status is not 'Deleted'
      return isActive && accountStatus != 'Deleted';
    } catch (e) {
      // If we can't check, assume active to avoid blocking legitimate users
      return true;
    }
  }

  /// Set password for Google-only users
  /// This allows Google users to create a password for account deactivation
  Future<void> setPasswordForGoogleUser(String password) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: password),
      );
    } on AuthApiException catch (e) {
      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthException('Failed to set password: ${e.toString()}');
    }
  }
}