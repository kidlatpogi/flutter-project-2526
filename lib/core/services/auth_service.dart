import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

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
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : null,
          authScreenLaunchMode: LaunchMode.platformDefault,
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
            'Failed to get Google ID token. Please try again.',
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
      return response.user;
    } on AuthApiException catch (e) {
      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthException('Sign-in failed: ${e.toString()}');
    }
  }

  /// Register with email and password
  Future<User?> signUpWithEmail(String email, String password,
      {String? name}) async {
    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'full_name': name} : null,
      );
      return response.user;
    } on AuthApiException catch (e) {
      throw AuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AuthException('Registration failed: ${e.toString()}');
    }
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
      userMetadata?['full_name'] ?? userMetadata?['name'];

  /// Get user's email
  String? get email => currentUser?.email;

  /// Get user's avatar URL
  String? get avatarUrl =>
      userMetadata?['avatar_url'] ?? userMetadata?['picture'];
}