import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/greeting_utils.dart';
import '../../../routing/route_names.dart';
import '../widgets/dashboard_navbar.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 2; // Home is selected
  final _userProfileService = UserProfileService();
  final _authService = AuthService();
  final _apiService = ApiService();
  String? _nickname;
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isStatsLoading = true;
  int _streakDays = 0;
  int _avgScore = 0;
  List<Map<String, dynamic>> _recentSessions = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadDashboardData();
  }

  Future<void> _loadUserProfile() async {
    try {
      _avatarUrl = _authService.avatarUrl;

      // Try to get nickname or display name from service
      final nickname = await _userProfileService.getNicknameOrDisplayName();

      if (mounted) {
        setState(() {
          _nickname = nickname ?? 'there';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Fallback to generic greeting
          _nickname = 'there';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      if (_authService.currentUser == null) {
        if (mounted) {
          setState(() {
            _isStatsLoading = false;
          });
        }
        return;
      }

      final response = await _apiService.getSessions(limit: 6);

      final sessions = response.map((session) {
        final createdAt = DateTime.parse(session['created_at']);
        return {
          'id': session['id'].toString(),
          'title': session['script_title'] ?? 'Untitled Session',
          'date': _formatDate(createdAt),
          'duration': _formatDuration(session['duration_seconds'] ?? 0),
          'confidenceScore': (session['confidence_score'] ?? 0).round(),
          'pitchScore': (session['pitch_score'] ?? 0).round(),
          'voiceQualityScore': (session['voice_quality_score'] ?? 0).round(),
          'paceScore': (session['pace_score'] ?? 0).round(),
          'fluencyScore': (session['fluency_score'] ?? 0).round(),
          'transcription': session['transcription'] ?? '',
          'createdAt': createdAt,
        };
      }).toList();

      final scores = sessions
          .map((s) => (s['confidenceScore'] as int))
          .toList();
      final avgScore = scores.isEmpty
          ? 0
          : (scores.reduce((a, b) => a + b) / scores.length).round();

      final streakDays = _calculateStreakDays(
        sessions.map((s) => s['createdAt'] as DateTime).toList(),
      );

      if (mounted) {
        setState(() {
          _recentSessions = sessions.take(5).toList();
          _avgScore = avgScore;
          _streakDays = streakDays;
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recentSessions = [];
          _avgScore = 0;
          _streakDays = 0;
          _isStatsLoading = false;
        });
      }
    }
  }

  int _calculateStreakDays(List<DateTime> dates) {
    if (dates.isEmpty) return 0;
    final uniqueDays =
        dates.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()
          ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime currentDay = DateTime.now();
    currentDay = DateTime(currentDay.year, currentDay.month, currentDay.day);

    for (final day in uniqueDays) {
      if (day == currentDay) {
        streak++;
        currentDay = currentDay.subtract(const Duration(days: 1));
      } else if (day == currentDay.subtract(const Duration(days: 1))) {
        streak++;
        currentDay = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  String _formatDate(DateTime date) {
    // Convert to Philippine Time (UTC+8)
    final phTime = date.toUtc().add(const Duration(hours: 8));
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final todayStart = DateTime(now.year, now.month, now.day);
    final phDateStart = DateTime(phTime.year, phTime.month, phTime.day);
    final dayDiff = todayStart.difference(phDateStart).inDays;

    final hour = phTime.hour == 0
        ? 12
        : (phTime.hour > 12 ? phTime.hour - 12 : phTime.hour);
    final period = phTime.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:${phTime.minute.toString().padLeft(2, '0')} $period';

    if (dayDiff == 0) {
      return 'Today at $timeStr';
    } else if (dayDiff == 1) {
      return 'Yesterday at $timeStr';
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[phTime.month - 1]} ${phTime.day}, ${phTime.year} at $timeStr';
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with logo and profile icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bigkas',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, RouteNames.profile);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: _avatarUrl != null
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: _avatarUrl!,
                                  fit: BoxFit.cover,
                                  width: 40,
                                  height: 40,
                                  memCacheWidth: 80,
                                  memCacheHeight: 80,
                                  placeholder: (context, url) => Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.person_outline,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.person_outline,
                                color: AppColors.primary,
                                size: 24,
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Greeting
                Text(
                  '${GreetingUtils.getGreeting()},',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                _isLoading
                    ? SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        _nickname ?? 'there',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),

                const SizedBox(height: 24),

                // Ready to speak card - More engaging design
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.record_voice_over,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isStatsLoading
                                      ? '...'
                                      : '$_streakDays day streak',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'Ready to speak?',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Description
                      Text(
                        'Practice makes perfect! Start your daily session\nand improve your public speaking skills.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Start Practice button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              RouteNames.practiceSetup,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_circle_filled,
                                size: 22,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Start Practice',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Quick Stats with better design
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Sessions Today
                      Expanded(
                        child: _buildQuickStat(
                          icon: Icons.calendar_today,
                          iconColor: Colors.blue,
                          value: _isStatsLoading
                              ? '—'
                              : '${_recentSessions.where((s) => (s['date'] as String).startsWith('Today')).length}',
                          label: 'Today',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.inactive.withOpacity(0.3),
                      ),
                      // Average Score
                      Expanded(
                        child: _buildQuickStat(
                          icon: Icons.analytics,
                          iconColor: Colors.green,
                          value: _isStatsLoading ? '—' : '$_avgScore',
                          label: 'Avg Score',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.inactive.withOpacity(0.3),
                      ),
                      // Streak
                      Expanded(
                        child: _buildQuickStat(
                          icon: Icons.local_fire_department,
                          iconColor: Colors.orange,
                          value: _isStatsLoading ? '—' : '$_streakDays',
                          label: 'Streak',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Motivation and Tips Section - 2 columns 1 row with equal height
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Motivation Quote
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.format_quote,
                                    color: Colors.black.withOpacity(0.6),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'MOTIVATION',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black.withOpacity(0.7),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Text(
                                  _getMotivationalQuote(),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Daily Tip of the Day
                      Expanded(child: _buildDailyTipCard()),
                    ],
                  ),
                ),

                const SizedBox(height: 80), // Space for bottom nav
              ],
            ),
          ),
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
            if (index == 0) {
              // Scripts
              Navigator.pushReplacementNamed(context, RouteNames.script);
            } else if (index == 1) {
              // Progress
              Navigator.pushReplacementNamed(context, RouteNames.progress);
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

  // Daily speaking tips that rotate based on day of year
  static const List<Map<String, String>> _speakingTips = [
    {
      'title': 'Breathe from your diaphragm',
      'content':
          'Deep breathing supports your voice and reduces nervousness. Place one hand on your belly and feel it expand as you inhale.',
      'icon': 'air',
    },
    {
      'title': 'Pause for emphasis',
      'content':
          'Strategic pauses give your audience time to absorb key points and make you appear more confident and in control.',
      'icon': 'pause_circle',
    },
    {
      'title': 'Make eye contact',
      'content':
          'Connect with individuals in your audience for 2-3 seconds each. This builds trust and keeps listeners engaged.',
      'icon': 'visibility',
    },
    {
      'title': 'Vary your vocal pitch',
      'content':
          'A monotone voice loses attention. Use higher pitch for excitement and lower pitch for serious points.',
      'icon': 'music_note',
    },
    {
      'title': 'Practice power poses',
      'content':
          'Standing tall with shoulders back for 2 minutes before speaking can boost confidence and reduce stress hormones.',
      'icon': 'accessibility_new',
    },
    {
      'title': 'Slow down your pace',
      'content':
          'Speaking too fast signals nervousness. Aim for 120-150 words per minute and let your words breathe.',
      'icon': 'speed',
    },
    {
      'title': 'Use gestures naturally',
      'content':
          'Hand movements help emphasize points and release nervous energy. Keep them purposeful and above your waist.',
      'icon': 'pan_tool',
    },
    {
      'title': 'Eliminate filler words',
      'content':
          'Replace "um," "uh," and "like" with brief pauses. Record yourself to identify your most common fillers.',
      'icon': 'block',
    },
    {
      'title': 'Start with a hook',
      'content':
          'Open with a surprising fact, question, or story to grab attention in the first 30 seconds.',
      'icon': 'bolt',
    },
    {
      'title': 'Practice the rule of three',
      'content':
          'People remember things in threes. Structure key messages in groups of three for maximum impact.',
      'icon': 'looks_3',
    },
    {
      'title': 'Project your voice',
      'content':
          'Speak to the back of the room without shouting. Good projection comes from your diaphragm, not your throat.',
      'icon': 'campaign',
    },
    {
      'title': 'End with a call to action',
      'content':
          'Tell your audience exactly what you want them to do next. A clear ending is more memorable than fading out.',
      'icon': 'trending_up',
    },
    {
      'title': 'Smile genuinely',
      'content':
          'A warm smile relaxes your voice and makes you more approachable. It also releases endorphins to calm nerves.',
      'icon': 'sentiment_satisfied',
    },
    {
      'title': 'Know your opening cold',
      'content':
          'Memorize your first 30 seconds perfectly. A confident start sets the tone for your entire presentation.',
      'icon': 'play_arrow',
    },
  ];

  Map<String, String> _getTodaysTip() {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    return _speakingTips[dayOfYear % _speakingTips.length];
  }

  Widget _buildQuickStat({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  static const List<String> _motivationalQuotes = [
    '"The only way to do great work is to love what you do." — Steve Jobs',
    '"Speech is power: speech is to persuade, to convert, to compel." — Ralph Waldo Emerson',
    '"The more you practice, the better you get, the more freedom you have to create." — Jocko Willink',
    '"Your voice is a powerful tool. Use it wisely and it will open doors." — Unknown',
    '"Courage is what it takes to stand up and speak." — Winston Churchill',
    '"Words are singularly the most powerful force available to humanity." — Yehuda Berg',
    '"Be a voice, not an echo." — Albert Einstein',
    '"The art of communication is the language of leadership." — James Humes',
  ];

  String _getMotivationalQuote() {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    return _motivationalQuotes[dayOfYear % _motivationalQuotes.length];
  }

  Widget _buildDailyTipCard() {
    final tip = _getTodaysTip();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.black.withOpacity(0.6),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'TIP OF THE DAY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.7),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip['title'] ?? 'Speaking Tip',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tip['content'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
