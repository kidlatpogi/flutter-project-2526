import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';

class SplashScreen3 extends StatelessWidget {
  const SplashScreen3({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // Chart/Analytics icon
              Icon(
                Icons.trending_up,
                size: AppConstants.largeIconSize,
                color: AppColors.primary,
              ),
              
              const SizedBox(height: AppConstants.largeSpacing),
              
              // Title
              Text(
                'Track your growth',
                style: AppTextStyles.header,
              ),
              
              const SizedBox(height: AppConstants.mediumSpacing),
              
              // Subtitle
              Text(
                'See how your vocal confidence improves\nover time with detailed analytics.',
                textAlign: TextAlign.center,
                style: AppTextStyles.paragraph,
              ),
              
              const Spacer(flex: 2),
              
              // Page indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: AppConstants.indicatorSize,
                    height: AppConstants.indicatorSize,
                    decoration: const BoxDecoration(
                      color: AppColors.inactive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppConstants.smallSpacing),
                  Container(
                    width: AppConstants.indicatorSize,
                    height: AppConstants.indicatorSize,
                    decoration: const BoxDecoration(
                      color: AppColors.inactive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppConstants.smallSpacing),
                  Container(
                    width: AppConstants.indicatorSize,
                    height: AppConstants.indicatorSize,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppConstants.largeSpacing),
              
              // Create Account button
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Navigate to registration screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Create Account pressed')),
                    );
                  },
                  child: const Text('Create Account'),
                ),
              ),
              
              const SizedBox(height: AppConstants.mediumSpacing),
              
              // Login button
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: Navigate to login screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Login pressed')),
                    );
                  },
                  child: const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}