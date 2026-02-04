import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../routing/route_names.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _userProfileService = UserProfileService();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _authService;
    super.dispose();
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate password strength
  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 12) {
      return 'Password must be at least 12 characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  /// Build password requirement indicator
  Widget _buildPasswordRequirement(String label, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: met ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: met ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  /// Handle account creation
  Future<void> _handleCreateAccount() async {
    print('Create Account button clicked');
    
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    print('Full Name: $fullName');
    print('Email: $email');
    print('Password length: ${password.length}');

    // Validation
    if (fullName.isEmpty) {
      print('Validation failed: Full name is empty');
      setState(() => _errorMessage = 'Please enter your full name');
      return;
    }

    if (email.isEmpty) {
      print('Validation failed: Email is empty');
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }

    if (!_isValidEmail(email)) {
      print('Validation failed: Invalid email format');
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      print('Validation failed: $passwordError');
      setState(() => _errorMessage = passwordError);
      return;
    }

    if (password != confirmPassword) {
      print('Validation failed: Passwords do not match');
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    print('All validations passed, attempting signup...');
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('Calling signUpWithEmail...');
      final user = await _authService.signUpWithEmail(
        email,
        password,
        name: fullName,
      );

      final hasSession = _authService.currentSession != null;
      final isEmailConfirmed = user?.emailConfirmedAt != null;

      // If email confirmation is not required, go straight to app flow
      if (hasSession || isEmailConfirmed) {
        if (hasSession) {
          await _userProfileService.updateUserProfile(fullName: fullName);
        }
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.authWrapper,
          (route) => false,
        );
        return;
      }

      print('Signup successful, prompting email confirmation...');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email to confirm your account before logging in.'),
            backgroundColor: Colors.green,
          ),
        );
        // After signup, go to verify email screen
        Navigator.pushReplacementNamed(
          context,
          RouteNames.verifyEmail,
          arguments: email,
        );
      }
    } on AuthException catch (e) {
      print('AuthException caught: ${e.message}');
      setState(() => _errorMessage = e.message);
    } catch (e) {
      print('Unexpected error caught: $e');
      setState(() => _errorMessage = 'Failed to create account. Please try again.');
    } finally {
      if (mounted) {
        print('Setting loading to false');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'BIGKAS',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Create Account Title
                Text(
                  'Create\nAccount',
                  style: AppTextStyles.header,
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'Start Tracking your speaking\npractice with AI analysis.',
                  style: AppTextStyles.paragraph,
                ),
                
                const SizedBox(height: 40),
                
                // Full Name Field
                Text(
                  'FULL NAME',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    hintText: 'Juan dela Cruz',
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
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
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
                  maxLength: 50,
                  decoration: InputDecoration(
                    hintText: 'juandelacruz@email',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.inactive,
                    ),
                    counterText: '${_emailController.text.length}/50',
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
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                
                const SizedBox(height: 24),
                
                // Password Field
                Text(
                  'PASSWORD (Minimum 12 characters)',
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
                  onChanged: (_) => setState(() {}),
                  maxLength: 128,
                  decoration: InputDecoration(
                    hintText: '••••••••',
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
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                if (_passwordController.text.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPasswordRequirement(
                        'At least 12 characters',
                        _passwordController.text.length >= 12,
                      ),
                      const SizedBox(height: 4),
                      _buildPasswordRequirement(
                        'Uppercase letter (A-Z)',
                        _passwordController.text.contains(RegExp(r'[A-Z]')),
                      ),
                      const SizedBox(height: 4),
                      _buildPasswordRequirement(
                        'Lowercase letter (a-z)',
                        _passwordController.text.contains(RegExp(r'[a-z]')),
                      ),
                      const SizedBox(height: 4),
                      _buildPasswordRequirement(
                        'Number (0-9)',
                        _passwordController.text.contains(RegExp(r'[0-9]')),
                      ),
                      const SizedBox(height: 4),
                      _buildPasswordRequirement(
                        'Special character (!@#\$%^&*)',
                        _passwordController.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]')),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 16),
                
                const SizedBox(height: 24),
                
                // Confirm Password Field
                Text(
                  'CONFIRM PASSWORD',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
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
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Error Message
                if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
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
                const SizedBox(height: 16),
              ],
              
              // Sign up Button
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreateAccount,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Account'),
                ),
              ),
                
                const SizedBox(height: 24),
                
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Login',
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
    );
  }
}