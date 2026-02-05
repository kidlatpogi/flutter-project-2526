import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_names.dart';
import '../../dashboard/widgets/dashboard_navbar.dart';

class ProgressAnalyticsScreen extends StatefulWidget {
  const ProgressAnalyticsScreen({super.key});

  @override
  State<ProgressAnalyticsScreen> createState() =>
      _ProgressAnalyticsScreenState();
}

class _ProgressAnalyticsScreenState extends State<ProgressAnalyticsScreen> {
  int _currentIndex = 1; // Progress is selected
  bool _isLoading = true;
  int _totalSessions = 0;
  int _avgScore = 0;
  List<Map<String, dynamic>> _recentHistory = [];
  List<double> _trendScores = [];
  List<String> _trendLabels = []; // Labels for X-axis (Mon, Jan, 2024, etc.)
  List<Map<String, dynamic>> _allSessions =
      []; // Store all sessions for filtering
  String _selectedPeriod = 'Week'; // Week, Month, Year
  List<Map<String, dynamic>> _recommendations = []; // Personalized tips
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    try {
      // Fetch more sessions to support Year view (up to 365 days of data)
      // Limit based on period: Week=20, Month=50, Year=200
      final limit = _selectedPeriod == 'Year'
          ? 200
          : (_selectedPeriod == 'Month' ? 50 : 20);

      // Fetch sessions and total count in parallel
      final sessionsFuture = _apiService.getSessions(limit: limit);
      final countFuture = _apiService.getTotalSessionsCount();

      final results = await Future.wait([sessionsFuture, countFuture]);
      final response = results[0] as List<Map<String, dynamic>>;
      final totalCount = results[1] as int;

      final sessions = response.map((session) {
        final createdAt = DateTime.parse(session['created_at']);
        return {
          'id': session['id'].toString(),
          'title': session['script_title'] ?? 'Untitled Session',
          'date': _formatDate(createdAt),
          'duration': _formatDuration(session['duration_seconds'] ?? 0),
          'confidenceScore': (session['confidence_score'] ?? 0).round(),
          'createdAt': createdAt,
        };
      }).toList();

      final scores = sessions
          .map((s) => (s['confidenceScore'] as int))
          .toList();
      final avgScore = scores.isEmpty
          ? 0
          : (scores.reduce((a, b) => a + b) / scores.length).round();

      final trendData = _buildTrendScores(sessions, _selectedPeriod);
      final recs = _generateRecommendations(sessions);

      if (mounted) {
        setState(() {
          _totalSessions = totalCount;
          _avgScore = avgScore;
          _recentHistory = sessions.take(5).toList();
          _trendScores = trendData.scores;
          _trendLabels = trendData.labels;
          _allSessions = sessions;
          _recommendations = recs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _totalSessions = 0;
          _avgScore = 0;
          _recentHistory = [];
          _trendScores = [];
          _recommendations = [];
          _isLoading = false;
        });
      }
    }
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

  /// Generate personalized recommendations based on analytics data
  List<Map<String, dynamic>> _generateRecommendations(
    List<Map<String, dynamic>> sessions,
  ) {
    final recommendations = <Map<String, dynamic>>[];

    if (sessions.isEmpty) {
      recommendations.add({
        'icon': Icons.play_circle_outline,
        'color': Colors.blue,
        'title': 'Start Practicing',
        'description': 'Record your first session to get personalized tips!',
      });
      return recommendations;
    }

    // Analyze recent trends
    final recentScores = sessions.take(5).map((s) => s['confidenceScore'] as int).toList();
    final avgScore = recentScores.isEmpty ? 0 : recentScores.reduce((a, b) => a + b) ~/ recentScores.length;

    // Score-based recommendations
    if (avgScore < 50) {
      recommendations.add({
        'icon': Icons.record_voice_over,
        'color': Colors.orange,
        'title': 'Focus on Clarity',
        'description': 'Try speaking more slowly and enunciating clearly.',
      });
    }

    if (avgScore < 70) {
      recommendations.add({
        'icon': Icons.trending_up,
        'color': Colors.green,
        'title': 'Build Consistency',
        'description': 'Practice daily to improve your speaking rhythm.',
      });
    }

    // Check for improvement trend
    if (recentScores.length >= 3) {
      final firstHalf = recentScores.sublist(recentScores.length ~/ 2);
      final secondHalf = recentScores.sublist(0, recentScores.length ~/ 2);
      final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
      
      if (secondAvg > firstAvg + 5) {
        recommendations.add({
          'icon': Icons.emoji_events,
          'color': Colors.amber,
          'title': 'Great Progress!',
          'description': "You're improving! Keep up the momentum.",
        });
      } else if (firstAvg > secondAvg + 5) {
        recommendations.add({
          'icon': Icons.refresh,
          'color': Colors.purple,
          'title': 'Stay Consistent',
          'description': 'Your recent scores dipped. Try practicing more regularly.',
        });
      }
    }

    // Session frequency recommendation
    if (sessions.length >= 2) {
      final firstSession = sessions.first['createdAt'] as DateTime;
      final lastSession = sessions.last['createdAt'] as DateTime;
      final daysDiff = firstSession.difference(lastSession).inDays;
      final sessionsPerWeek = daysDiff > 0 ? (sessions.length / (daysDiff / 7)).round() : sessions.length;
      
      if (sessionsPerWeek < 3) {
        recommendations.add({
          'icon': Icons.calendar_today,
          'color': Colors.blue,
          'title': 'Practice More Often',
          'description': 'Aim for 3-5 sessions per week for best results.',
        });
      }
    }

    // High performer tips
    if (avgScore >= 80) {
      recommendations.add({
        'icon': Icons.star,
        'color': Colors.amber,
        'title': 'Challenge Yourself',
        'description': 'Try longer scripts or new topics to push your skills.',
      });
    }

    // Limit to top 3 recommendations
    return recommendations.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Progress',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 24),

                // Performance Trend Card
                Container(
                  padding: const EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Performance Trend Label and Period Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PERFORMANCE TREND',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          // Period Selector
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ['Week', 'Month', 'Year'].map((period) {
                                final isSelected = _selectedPeriod == period;
                                return GestureDetector(
                                  onTap: () async {
                                    // Reload data with new period
                                    setState(() {
                                      _selectedPeriod = period;
                                      _isLoading = true;
                                    });
                                    // Recalculate trend scores
                                    await Future.delayed(
                                      const Duration(milliseconds: 100),
                                    );
                                    if (mounted) {
                                      setState(() {
                                        final trendData = _buildTrendScores(
                                          _allSessions,
                                          period,
                                        );
                                        _trendScores = trendData.scores;
                                        _trendLabels = trendData.labels;
                                        _isLoading = false;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      period,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_trendScores.isEmpty)
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.show_chart,
                                size: 64,
                                color: AppColors.inactive,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No data yet',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Complete practice sessions to\nsee your performance trend',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondary.withOpacity(
                                    0.7,
                                  ),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          height: 180,
                          child: CustomPaint(
                            painter: LineChartPainter(
                              scores: _trendScores,
                              labels: _trendLabels,
                              period: _selectedPeriod,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    // Total Sessions
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.inactive.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 24,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isLoading ? '—' : '$_totalSessions',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total Sessions',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Average Score
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.inactive.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assessment,
                              size: 24,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isLoading ? '—' : '$_avgScore%',
                              style: GoogleFonts.inter(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Avg. Score',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Recommendations Section
                if (_recommendations.isNotEmpty) ...[
                  Text(
                    'Recommendations',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(_recommendations.map((rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (rec['color'] as Color).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (rec['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              rec['icon'] as IconData,
                              color: rec['color'] as Color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rec['title'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  rec['description'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )).toList()),
                  const SizedBox(height: 12),
                ],

                // Recent Session Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Session',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.sessions);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_recentHistory.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.inactive.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: AppColors.inactive,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No sessions yet',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your recent sessions will\nappear here',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary.withOpacity(0.7),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: _recentHistory.map((session) {
                      final score = session['confidenceScore'] as int;
                      final rating = _getRating(score);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildHistoryItem(
                          sessionId: session['id'] as String,
                          icon: _getScoreIcon(score),
                          iconColor: _getScoreColor(score),
                          title: session['title'] as String,
                          date: session['date'] as String,
                          subtitle: session['duration'] as String,
                          score: score.toString(),
                          rating: rating,
                        ),
                      );
                    }).toList(),
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
            // TODO: Handle other navigation items (3=Profile, 4=Settings)
          }
        },
      ),
    );
  }

  IconData _getScoreIcon(int score) {
    if (score >= 85) return Icons.emoji_events; // Trophy for Excellent
    if (score >= 70) return Icons.star; // Star for Good
    if (score >= 50) return Icons.thumb_up; // Thumbs up for Fair
    return Icons.trending_up; // Improvement needed
  }

  Color _getScoreColor(int score) {
    if (score >= 85) return Colors.amber; // Gold for Excellent
    if (score >= 70) return Colors.green; // Green for Good
    if (score >= 50) return Colors.blue; // Blue for Fair
    return Colors.orange; // Orange for needs improvement
  }

  Widget _buildHistoryItem({
    required String sessionId,
    required IconData icon,
    required String title,
    required String date,
    required String subtitle,
    required String score,
    required String rating,
    Color? iconColor,
  }) {
    final color = iconColor ?? AppColors.primary;
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '${RouteNames.analysis}?sessionId=$sessionId',
          arguments: {'sessionId': sessionId, 'fromProgress': true},
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.inactive.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),

            const SizedBox(width: 12),

            // Title and details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$date  •  $subtitle',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Score and rating
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      score,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      rating,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getRatingColor(rating),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: AppColors.primary, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ({List<double> scores, List<String> labels}) _buildTrendScores(
    List<Map<String, dynamic>> sessions,
    String period,
  ) {
    if (sessions.isEmpty) return (scores: [], labels: []);

    // Filter sessions based on period
    final now = DateTime.now();
    DateTime cutoffDate;
    int maxPoints;

    switch (period) {
      case 'Week':
        cutoffDate = now.subtract(const Duration(days: 7));
        maxPoints = 7; // Show up to 7 days
        break;
      case 'Month':
        cutoffDate = DateTime(now.year, now.month - 1, now.day);
        maxPoints = 5; // Show 5 weeks approximately
        break;
      case 'Year':
        cutoffDate = DateTime(now.year - 1, now.month, now.day);
        maxPoints = 12; // Show 12 months
        break;
      default:
        cutoffDate = now.subtract(const Duration(days: 7));
        maxPoints = 7;
    }

    final filteredSessions = sessions.where((s) {
      final createdAt = s['createdAt'] as DateTime;
      return createdAt.isAfter(cutoffDate);
    }).toList();

    if (filteredSessions.isEmpty) return (scores: [], labels: []);

    // Group sessions by time period with display labels
    final Map<String, List<int>> groupedScores = {};
    final Map<String, String> keyToLabel = {};
    
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    for (final session in filteredSessions) {
      final createdAt = session['createdAt'] as DateTime;
      final score = session['confidenceScore'] as int;
      String key;
      String label;

      switch (period) {
        case 'Week':
          // Group by day - show day name (Mon, Tue, etc.)
          key = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          label = dayNames[createdAt.weekday - 1];
          break;
        case 'Month':
          // Group by week number - show week range
          final weekNum = ((createdAt.day - 1) ~/ 7) + 1;
          key = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-W$weekNum';
          label = 'W$weekNum';
          break;
        case 'Year':
          // Group by month - show month name
          key = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
          label = monthNames[createdAt.month - 1];
          break;
        default:
          key = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          label = dayNames[createdAt.weekday - 1];
      }

      groupedScores.putIfAbsent(key, () => []);
      groupedScores[key]!.add(score);
      keyToLabel[key] = label;
    }

    // Calculate average for each group
    final List<MapEntry<String, double>> averages = groupedScores.entries.map((
      e,
    ) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return MapEntry(e.key, avg);
    }).toList();

    // Sort by key (date)
    averages.sort((a, b) => a.key.compareTo(b.key));

    // Get scores and labels
    final scores = averages.map((e) => e.value).toList();
    final labels = averages.map((e) => keyToLabel[e.key] ?? '').toList();

    // Limit to max points, keeping the most recent
    final lastScores = scores.length > maxPoints
        ? scores.sublist(scores.length - maxPoints)
        : scores;
    final lastLabels = labels.length > maxPoints
        ? labels.sublist(labels.length - maxPoints)
        : labels;

    return (scores: lastScores, labels: lastLabels);
  }

  Color _getRatingColor(String rating) {
    switch (rating) {
      case 'PERFECT':
        return Colors.green;
      case 'EXCELLENT':
        return Colors.green;
      case 'GOOD':
        return Colors.orange;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getRating(int score) {
    if (score >= 90) return 'PERFECT';
    if (score >= 80) return 'EXCELLENT';
    if (score >= 60) return 'GOOD';
    if (score >= 40) return 'FAIR';
    return 'NEEDS WORK';
  }
}

// Line chart painter with period-based labels
class LineChartPainter extends CustomPainter {
  final List<double> scores;
  final List<String> labels;
  final String period;

  LineChartPainter({
    required this.scores,
    required this.labels,
    required this.period,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final maxScore = 100.0;
    final minScore = 0.0;
    final count = scores.length;

    // Add padding for labels
    const leftPadding = 30.0;
    const topPadding = 20.0;
    const bottomPadding = 30.0;
    final chartWidth = size.width - leftPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final stepX = count == 1 ? 0.0 : chartWidth / (count - 1);

    final points = List<Offset>.generate(count, (i) {
      final x = leftPadding + stepX * i;
      final score = scores[i].clamp(minScore, maxScore);
      final normalized = (score - minScore) / (maxScore - minScore);
      final y = topPadding + chartHeight * (1 - normalized);
      return Offset(x, y);
    });

    // Draw Y-axis labels (0, 50, 100)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final labelStyle = TextStyle(
      color: Colors.grey[600],
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    for (final label in [100, 50, 0]) {
      final normalized = (label - minScore) / (maxScore - minScore);
      final y = topPadding + chartHeight * (1 - normalized);

      textPainter.text = TextSpan(text: '$label', style: labelStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));

      // Draw horizontal grid line
      final gridPaint = Paint()
        ..color = Colors.grey.withOpacity(0.2)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
    }

    // Draw line
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      final xc = (points[i - 1].dx + points[i].dx) / 2;
      final yc = (points[i - 1].dy + points[i].dy) / 2;
      path.quadraticBezierTo(points[i - 1].dx, points[i - 1].dy, xc, yc);
    }
    path.lineTo(points.last.dx, points.last.dy);

    canvas.drawPath(path, linePaint);

    // Draw dots and score labels
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      canvas.drawCircle(point, 5, dotPaint);

      // Draw score label above each point
      final scoreText = scores[i].round().toString();
      textPainter.text = TextSpan(
        text: scoreText,
        style: TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(point.dx - textPainter.width / 2, point.dy - 18),
      );
    }

    // Draw period-based X-axis labels (Mon, Tue... or Jan, Feb... or 2024, 2025...)
    for (int i = 0; i < points.length; i++) {
      final label = i < labels.length ? labels[i] : '${i + 1}';
      textPainter.text = TextSpan(text: label, style: labelStyle);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          points[i].dx - textPainter.width / 2,
          size.height - bottomPadding + 8,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    if (scores.length != oldDelegate.scores.length) return true;
    if (period != oldDelegate.period) return true;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] != oldDelegate.scores[i]) return true;
    }
    return false;
  }
}
