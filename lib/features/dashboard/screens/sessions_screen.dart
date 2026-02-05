import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_names.dart';
import '../widgets/dashboard_navbar.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  int _currentIndex = 2; // Home is selected
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _allSessions =
      []; // Store all sessions for filtering
  bool _isLoading = true;
  String _selectedFilter = 'All'; // All, Today, This Week, This Month
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final response = await _apiService.getSessions(limit: 100);

      if (mounted) {
        final sessions = response.map((session) {
          final createdAt = DateTime.parse(session['created_at']);
          final formattedDate = _formatDate(createdAt);
          final duration = _formatDuration(session['duration_seconds'] ?? 0);

          return {
            'id': session['id'].toString(),
            'title': session['script_title'] ?? 'Untitled Session',
            'date': formattedDate,
            'duration': duration,
            'confidenceScore': (session['confidence_score'] ?? 0).round(),
            'pitchScore': (session['pitch_score'] ?? 0).round(),
            'voiceQualityScore': (session['voice_quality_score'] ?? 0).round(),
            'paceScore': (session['pace_score'] ?? 0).round(),
            'fluencyScore': (session['fluency_score'] ?? 0).round(),
            'transcription': session['transcription'] ?? '',
            'createdAt': createdAt,
          };
        }).toList();

        setState(() {
          _allSessions = sessions;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sessions = [];
          _allSessions = [];
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (_selectedFilter) {
      case 'Today':
        _sessions = _allSessions.where((s) {
          final createdAt = s['createdAt'] as DateTime;
          return createdAt.isAfter(todayStart);
        }).toList();
        break;
      case 'This Week':
        final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        _sessions = _allSessions.where((s) {
          final createdAt = s['createdAt'] as DateTime;
          return createdAt.isAfter(weekStart);
        }).toList();
        break;
      case 'This Month':
        final monthStart = DateTime(now.year, now.month, 1);
        _sessions = _allSessions.where((s) {
          final createdAt = s['createdAt'] as DateTime;
          return createdAt.isAfter(monthStart);
        }).toList();
        break;
      case 'All':
      default:
        _sessions = List.from(_allSessions);
        break;
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
        child: Column(
          children: [
            // Header with Back Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: AppColors.primary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'All Sessions',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 40),
                    child: Text(
                      _isLoading
                          ? 'Loading...'
                          : '${_sessions.length} practice sessions',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Today', 'This Week', 'This Month'].map(
                        (filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedFilter = filter;
                                  _applyFilter();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.inactive.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  filter,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Sessions List
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_sessions.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: AppColors.inactive),
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
                        'Start a practice session to see your progress here',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return _buildSessionCard(session);
                  },
                ),
              ),

            const SizedBox(height: 80), // Space for bottom nav
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
            if (index == 0) {
              // Scripts
              Navigator.pushReplacementNamed(context, RouteNames.script);
            } else if (index == 1) {
              // Progress
              Navigator.pushReplacementNamed(context, RouteNames.progress);
            } else if (index == 2) {
              // Home
              Navigator.pushReplacementNamed(context, RouteNames.dashboard);
            } else if (index == 4) {
              // Settings
              Navigator.pushReplacementNamed(context, RouteNames.settings);
            }
          }
        },
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to session details
        Navigator.pushNamed(
          context,
          '${RouteNames.analysis}?sessionId=${session['id']}',
          arguments: {'sessionId': session['id']},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.inactive.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Icon - Score-based icon like in Recent Sessions
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _getScoreColor(
                  session['confidenceScore'],
                ).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getScoreIcon(session['confidenceScore']),
                color: _getScoreColor(session['confidenceScore']),
                size: 24,
              ),
            ),

            const SizedBox(width: 12),

            // Session Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session['title'],
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        session['date'],
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${session['duration']}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Confidence Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getScoreColor(
                  session['confidenceScore'],
                ).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${session['confidenceScore']}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getScoreColor(session['confidenceScore']),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Arrow
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 85) return Colors.amber; // Gold for Excellent
    if (score >= 70) return Colors.green; // Green for Good
    if (score >= 50) return Colors.blue; // Blue for Fair
    return Colors.orange; // Orange for needs improvement
  }

  IconData _getScoreIcon(int score) {
    if (score >= 85) return Icons.emoji_events; // Trophy for Excellent
    if (score >= 70) return Icons.star; // Star for Good
    if (score >= 50) return Icons.thumb_up; // Thumbs up for Fair
    return Icons.trending_up; // Improvement needed
  }
}
