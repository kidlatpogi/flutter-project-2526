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
  List<Map<String, dynamic>> _allSessions = []; // Store all sessions for filtering
  String _selectedPeriod = 'Week'; // Week, Month, Year
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  Future<void> _loadProgressData() async {
    try {
      print('Loading progress data...');
      
      // Fetch more sessions to support Year view (up to 365 days of data)
      // Limit based on period: Week=20, Month=50, Year=200
      final limit = _selectedPeriod == 'Year' ? 200 : (_selectedPeriod == 'Month' ? 50 : 20);
      
      // Fetch sessions and total count in parallel
      final sessionsFuture = _apiService.getSessions(limit: limit);
      final countFuture = _apiService.getTotalSessionsCount();
      
      final results = await Future.wait([sessionsFuture, countFuture]);
      final response = results[0] as List<Map<String, dynamic>>;
      final totalCount = results[1] as int;
      
      print('Progress: got ${response.length} sessions, total: $totalCount');

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

      final trendScores = _buildTrendScores(sessions, _selectedPeriod);

      if (mounted) {
        setState(() {
          _totalSessions = totalCount;
          _avgScore = avgScore;
          _recentHistory = sessions.take(5).toList();
          _trendScores = trendScores;
          _allSessions = sessions;
          _isLoading = false;
        });
        print('Progress loaded: $_totalSessions total, $_avgScore avg');
      }
    } catch (e) {
      print('Progress load error: $e');
      if (mounted) {
        setState(() {
          _totalSessions = 0;
          _avgScore = 0;
          _recentHistory = [];
          _trendScores = [];
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
                                  onTap: () {
                                    setState(() {
                                      _selectedPeriod = period;
                                    });
                                    // Reload data with appropriate limit for the period
                                    _loadProgressData();
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
                            painter: LineChartPainter(scores: _trendScores),
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
          RouteNames.analysis,
          arguments: {'sessionId': sessionId},
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

  List<double> _buildTrendScores(List<Map<String, dynamic>> sessions, String period) {
    if (sessions.isEmpty) return [];

    // Filter sessions based on period
    final now = DateTime.now();
    DateTime cutoffDate;
    
    switch (period) {
      case 'Week':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        cutoffDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'Year':
        cutoffDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        cutoffDate = now.subtract(const Duration(days: 7));
    }

    final filteredSessions = sessions.where((s) {
      final createdAt = s['createdAt'] as DateTime;
      return createdAt.isAfter(cutoffDate);
    }).toList();

    if (filteredSessions.isEmpty) return [];

    final sorted = [...filteredSessions]
      ..sort(
        (a, b) =>
            (a['createdAt'] as DateTime).compareTo(b['createdAt'] as DateTime),
      );

    final scores = sorted
        .map((s) => (s['confidenceScore'] as int).toDouble())
        .toList();

    // Use a rolling average to smooth the trend (window size 3)
    const window = 3;
    final smoothed = <double>[];
    for (var i = 0; i < scores.length; i++) {
      final start = (i - (window - 1)) < 0 ? 0 : i - (window - 1);
      final slice = scores.sublist(start, i + 1);
      final avg = slice.reduce((a, b) => a + b) / slice.length;
      smoothed.add(avg);
    }

    // Keep last 6 points for chart
    final lastPoints = smoothed.length > 6
        ? smoothed.sublist(smoothed.length - 6)
        : smoothed;
    return lastPoints;
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

// Simple line chart painter with score labels
class LineChartPainter extends CustomPainter {
  final List<double> scores;

  LineChartPainter({required this.scores});

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
    const bottomPadding = 25.0;
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

    // Draw session number labels at bottom
    for (int i = 0; i < points.length; i++) {
      textPainter.text = TextSpan(text: '${i + 1}', style: labelStyle);
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
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] != oldDelegate.scores[i]) return true;
    }
    return false;
  }
}
