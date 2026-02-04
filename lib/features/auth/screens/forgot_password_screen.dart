import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../core/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Forgot Password Title
              Text(
                'Forgot\nPassword',
                style: AppTextStyles.header,
              ),
              
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                'Enter your email address to receive a\npassword reset link.',
                style: AppTextStyles.paragraph,
              ),
              
              const SizedBox(height: 40),
              
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
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Send Code Button
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final email = _emailController.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter your email'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          if (!_isValidEmail(email)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid email address'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() => _isLoading = true);
                          try {
                            await _authService.sendPasswordResetEmail(email);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password reset email sent. Please check your inbox.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.pop(context);
                          } on AuthException catch (e) {
                            if (!mounted) return;
                            
                            // Check for rate limit error
                            final errorMsg = e.message.toLowerCase();
                            String displayMessage;
                            
                            if (errorMsg.contains('rate') || 
                                errorMsg.contains('too many') || 
                                errorMsg.contains('limit') ||
                                errorMsg.contains('email rate limit exceeded')) {
                              displayMessage = 'Too many requests. Please wait a few minutes before trying again.';
                            } else {
                              displayMessage = e.message;
                            }
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(displayMessage),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            final errorStr = e.toString().toLowerCase();
                            String displayMessage;
                            
                            if (errorStr.contains('rate') || 
                                errorStr.contains('too many') || 
                                errorStr.contains('limit')) {
                              displayMessage = 'Too many requests. Please wait a few minutes before trying again.';
                            } else {
                              displayMessage = 'Failed to send reset email. Please try again later.';
                            }
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(displayMessage),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send Link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}