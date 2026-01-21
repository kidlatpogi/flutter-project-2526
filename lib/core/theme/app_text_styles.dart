import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Header - Font Size 32, Inter, Bold
  static TextStyle header = GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  // Sub Header - Font Size 16, Semi-bold, Inter
  static TextStyle subHeader = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  // Paragraph - Font Size 13 Regular, Inter
  static TextStyle paragraph = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  // Button text
  static TextStyle button = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  // Title for splash screens
  static TextStyle splashTitle = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );
}