import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_names.dart';
import '../widgets/script_list_item.dart';
import '../../dashboard/widgets/dashboard_navbar.dart';

class ScriptScreen extends StatefulWidget {
  const ScriptScreen({super.key});

  @override
  State<ScriptScreen> createState() => _ScriptScreenState();
}

class _ScriptScreenState extends State<ScriptScreen> {
  int _currentIndex = 0; // Scripts is selected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Scripts',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Navigate to create script
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'New Script',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scripts List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  ScriptListItem(
                    title: 'Graduation Speech Draft 1',
                    description:
                        'Follow students, teachers, and parents, Today marks the end of long journey, but also the beginning of an exciting new...',
                    editedTime: 'EDITED 2H AGO',
                    onUseInPractice: () {
                      // TODO: Navigate to practice with this script
                    },
                  ),
                  const SizedBox(height: 16),
                  ScriptListItem(
                    title: 'Debate Opening Statement',
                    description:
                        'The proposition clearly states that renewable energy is the only path forward for sustainable economic growth. To...',
                    editedTime: 'EDITED YESTERDAY',
                    onUseInPractice: () {
                      // TODO: Navigate to practice with this script
                    },
                  ),
                  const SizedBox(height: 16),
                  ScriptListItem(
                    title: 'Impromptu Practice',
                    description:
                        'Topic: If I could travel anywhere in time, I would choose the Renaissance period. The explosion of art, science and culture...',
                    editedTime: 'EDITED 30 AGO',
                    onUseInPractice: () {
                      // TODO: Navigate to practice with this script
                    },
                  ),
                  const SizedBox(height: 80), // Space for bottom nav
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DashboardNavbar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            setState(() {
              _currentIndex = index;
            });
            // Navigate based on index
            if (index == 1) {
              // Progress
              Navigator.pushReplacementNamed(context, RouteNames.progress);
            } else if (index == 2) {
              // Home
              Navigator.pushReplacementNamed(context, RouteNames.dashboard);
            } else if (index == 3) {
              // Profile
              Navigator.pushReplacementNamed(context, RouteNames.profile);
            } else if (index == 4) {
              // Settings
              Navigator.pushReplacementNamed(context, RouteNames.settings);
            }
          }
        },
      ),
    );
  }
}