import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../routing/route_names.dart';

class SplashScreen1 extends StatelessWidget {
  const SplashScreen1({super.key});

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
              
              // Sound wave icon
              Icon(
                Icons.graphic_eq,
                size: AppConstants.largeIconSize,
                color: AppColors.primary,
              ),
              
              const SizedBox(height: AppConstants.largeSpacing),
              
              // Title
              Text(
                AppConstants.appName,
                style: AppTextStyles.header,
              ),
              
              const SizedBox(height: AppConstants.mediumSpacing),
              
              // Subtitle
              Text(
                AppConstants.appTagline,
                style: AppTextStyles.subHeader,
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
                      color: AppColors.primary,
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
                      color: AppColors.inactive,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppConstants.largeSpacing),
              
              // Next button
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, RouteNames.splash2);
                  },
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}