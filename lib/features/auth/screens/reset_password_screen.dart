import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  bool _hasMinLength = false;
  bool _hasNumber = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final password = _newPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasNumber = password.contains(RegExp(r'[0-9]'));
    });
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Reset Password Title
                Text(
                  'Reset Password',
                  style: AppTextStyles.header,
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'Create a new, strong password for your\naccount.',
                  style: AppTextStyles.paragraph,
                ),
                
                const SizedBox(height: 40),
                
                // New Password Field
                Text(
                  'New Password',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    hintText: 'Enter new password',
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
                        _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Password Requirements
                Row(
                  children: [
                    Icon(
                      _hasMinLength ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: _hasMinLength ? Colors.green : AppColors.inactive,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '8+ chars',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _hasMinLength ? Colors.green : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Icon(
                      _hasNumber ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: _hasNumber ? Colors.green : AppColors.inactive,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '1 Number',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _hasNumber ? Colors.green : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Confirm New Password Field
                Text(
                  'Confirm New Password',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Re-enter new password',
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
                
                const SizedBox(height: 200),
                
                // Save new password Button
                SizedBox(
                  width: double.infinity,
                  height: AppConstants.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_newPasswordController.text == _confirmPasswordController.text &&
                          _hasMinLength &&
                          _hasNumber) {
                        // TODO: Implement password reset logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset successful')),
                        );
                        Navigator.popUntil(context, (route) => route.isFirst);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please check your password requirements')),
                        );
                      }
                    },
                    child: const Text('Save new password'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}