import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final providers = user.appMetadata['providers'] as List? ?? [];
    return providers.length == 1 && providers.contains('google');
  }

  /// Check if user has password authentication
  bool get hasPasswordAuth {
    final user = currentUser;
    if (user == null) return false;
    final providers = user.appMetadata['providers'] as List? ?? [];
    return providers.contains('email');
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
  /// On Web: Uses Supabase OAuth flow (opens popup)
  /// On Mobile: Uses native Google Sign-In flow
  ///
  /// Throws [AuthException] if sign-in fails or is cancelled
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: Use Supabase OAuth flow (more reliable for web)
        // Use the current page origin for redirect
        final redirectTo = Uri.base.origin;
        
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectTo,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        // OAuth flow redirects, so we return null here
        // The auth state change listener will handle the session
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
}