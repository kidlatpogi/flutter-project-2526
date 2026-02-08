import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/web_oauth_utils.dart' as web_oauth;
import '../../../routing/route_names.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _userProfileService = UserProfileService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Don't listen to auth state changes here - let AuthWrapper handle OAuth redirects
    // OAuth will redirect and trigger auth state change which AuthWrapper will process
  }

  @override
  void dispose() {
    web_oauth.cancelOAuthListener();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handle email/password login
  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validation
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter email and password');
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmail(email, password);

      // Check if widget is still mounted before proceeding
      if (!mounted) {
        return;
      }

      // Check if user has nickname
      bool hasNickname = false;
      try {
        hasNickname = await _userProfileService.hasNickname();
      } catch (e) {
        // If backend is down, skip nickname check and go to dashboard
        // The dashboard will handle the error gracefully
        hasNickname = true;
      }

      if (!mounted) {
        return;
      }

      if (!hasNickname) {
        Navigator.pushReplacementNamed(context, RouteNames.nicknameSetup);
      } else {
        Navigator.pushReplacementNamed(context, RouteNames.dashboard);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Login failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Handle Google Sign-In
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signInWithGoogle();

      if (kIsWeb) {
        // On web, OAuth opens in a popup window.
        // The popup sends the OAuth callback URL back via postMessage.
        // We listen for that message, extract the refresh_token, and
        // call setSession() which triggers the auth state change.
        // AuthWrapper will detect the signedIn event and handle navigation.
        web_oauth.listenForOAuthCallback((url) async {
          try {
            final uri = Uri.parse(url);
            final fragment = uri.fragment;
            if (fragment.isEmpty) {
              throw Exception('No OAuth callback data received');
            }

            final params = Uri.splitQueryString(fragment);
            final refreshToken = params['refresh_token'];

            if (refreshToken == null || refreshToken.isEmpty) {
              throw Exception('No refresh token in OAuth callback');
            }

            // This stores the session and fires AuthChangeEvent.signedIn.
            // AuthWrapper listens for this event and handles all navigation.
            await Supabase.instance.client.auth.setSession(refreshToken);

            // Navigation is handled by AuthWrapper's auth state listener.
            // No need to navigate from here - LoginScreen will be swapped
            // out by AuthWrapper automatically.
          } catch (e) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Google sign-in failed: ${e.toString()}';
                _isLoading = false;
              });
            }
          }
        });
        // Stop loading spinner so user can interact while popup is open
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      if (user != null && mounted) {
        // Check if account is deactivated
        final isActive = await _authService.checkAccountActive(user.id);
        if (!isActive) {
          await _authService.signOut();
          setState(
            () => _errorMessage =
                'Your account has been deactivated. Please contact support if you believe this is an error.',
          );
          return;
        }

        // Check if user has nickname
        bool hasNickname = false;
        try {
          hasNickname = await _userProfileService.hasNickname();
        } catch (e) {
          // If backend is down, skip nickname check and go to dashboard
          hasNickname = true;
        }

        if (!hasNickname) {
          Navigator.pushReplacementNamed(context, RouteNames.nicknameSetup);
        } else {
          Navigator.pushReplacementNamed(context, RouteNames.dashboard);
        }
      }
    } on AuthException catch (e) {
      if (e.code != 'cancelled') {
        setState(() => _errorMessage = e.message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button during OAuth flow
        if (_isLoading) {
          return false; // Don't allow back while login is in progress
        }
        return true; // Allow back otherwise
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Bigkas Logo
                  Row(
                    children: [
                      Icon(
                        Icons.graphic_eq,
                        size: 24,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppConstants.appName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Login Title
                  Text('Login', style: AppTextStyles.header),

                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    'Continue your public speaking journey.',
                    style: AppTextStyles.paragraph,
                  ),

                  const SizedBox(height: 28),

                  // Email Address Field
                  Text(
                    'EMAIL ADDRESS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'student@example.com',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.inactive,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.inactive),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.inactive),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Password Field
                  Text(
                    'PASSWORD',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.inactive,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.inactive),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.inactive),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.forgotPassword);
                      },
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Log In Button
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleEmailLogin,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Log In'),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Divider with "or"
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.inactive)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: AppColors.inactive)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: AppConstants.buttonHeight,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/3840px-Google_%22G%22_logo.svg.png',
                        height: 20,
                        width: 20,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(height: 20, width: 20),
                      ),
                      label: Text(
                        'Continue with Google',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.inactive),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Create Account Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            RouteNames.createAccount,
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
