import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../routing/route_names.dart';

class SplashScreen2 extends StatelessWidget {
  const SplashScreen2({super.key});

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
              
              // Person with speech bubble icon
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.person,
                    size: AppConstants.mediumIconSize,
                    color: AppColors.primary,
                  ),
                  Positioned(
                    top: -10,
                    right: -20,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppConstants.largeSpacing),
              
              // Title
              Text(
                'Practice public\nspeaking safely',
                textAlign: TextAlign.center,
                style: AppTextStyles.splashTitle,
              ),
              
              const SizedBox(height: AppConstants.mediumSpacing),
              
              // Subtitle
              Text(
                'Build your confidence in a judgement-free\nspace with real-time feedback.',
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
                ],
              ),
              
              const SizedBox(height: AppConstants.largeSpacing),
              
              // Next button
              SizedBox(
                width: double.infinity,
                height: AppConstants.buttonHeight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, RouteNames.splash3);
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