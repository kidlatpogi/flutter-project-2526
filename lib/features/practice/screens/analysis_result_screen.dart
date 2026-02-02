import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/analysis_model.dart';
import '../../../routing/route_names.dart';

class AnalysisResultScreen extends StatefulWidget {
  final AnalysisModel? analysisResult;
  final String? sessionId;

  const AnalysisResultScreen({super.key, this.analysisResult, this.sessionId});

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  late final ApiService _apiService;
  late final AudioService _audioService;
  late final AudioPlayer _audioPlayer;
  Future<AnalysisModel>? _analysisFuture;
  String? _recordingPath;
  String? _recordingSessionId;
  bool _isRecordingLoading = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _audioService = AudioService();
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    if (widget.analysisResult == null && widget.sessionId != null) {
      _analysisFuture = _apiService.getAnalysis(widget.sessionId!);
    }
  }

  @override
  void dispose() {
    _apiService.dispose();
    _audioService.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _ensureRecordingPath(String? sessionId) async {
    if (sessionId == null) return;
    
    // Skip if we've already loaded this session
    if (_recordingSessionId == sessionId && _recordingPath != null) return;
    
    // Skip if already loading
    if (_isRecordingLoading && _recordingSessionId == sessionId) return;
    
    if (!mounted) return;
    
    setState(() {
      _isRecordingLoading = true;
      _recordingSessionId = sessionId;
    });
    
    try {
      final path = await _audioService.getRecordingPathForSession(sessionId);
      if (mounted && _recordingSessionId == sessionId) {
        setState(() {
          _recordingPath = path;
          _isRecordingLoading = false;
        });
      }
    } catch (e) {
      print('Error loading recording path: $e');
      if (mounted && _recordingSessionId == sessionId) {
        setState(() {
          _recordingPath = null;
          _isRecordingLoading = false;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordingPath == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(_recordingPath!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final AnalysisModel? directResult =
        widget.analysisResult ??
        (routeArgs is AnalysisModel ? routeArgs : null);
    final String? routeSessionId =
        widget.sessionId ??
        (routeArgs is Map<String, dynamic>
            ? routeArgs['sessionId'] as String?
            : null);

    final resolvedSessionId = directResult?.sessionId ?? routeSessionId;
    if (resolvedSessionId != null && resolvedSessionId != _recordingSessionId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureRecordingPath(resolvedSessionId);
      });
    }

    if (directResult == null &&
        _analysisFuture == null &&
        routeSessionId != null) {
      _analysisFuture = _apiService.getAnalysis(routeSessionId);
    }

    if (directResult != null) {
      return _buildContent(context, directResult);
    }

    if (_analysisFuture != null) {
      return FutureBuilder<AnalysisModel>(
        future: _analysisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading();
          }
          if (snapshot.hasError) {
            return _buildError(context, 'Failed to load analysis');
          }
          final result = snapshot.data;
          if (result == null) {
            return _buildError(context, 'No analysis data available');
          }
          return _buildContent(context, result);
        },
      );
    }

    return _buildError(context, 'No analysis data available');
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading analysis...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.inactive),
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  RouteNames.dashboard,
                  (route) => false,
                ),
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnalysisModel result) {
    // Helper to get score label and color
    String getScoreLabel(double score) {
      if (score >= 80) return 'EXCELLENT';
      if (score >= 60) return 'GOOD';
      if (score >= 40) return 'NEEDS WORK';
      return 'POOR';
    }

    Color getScoreColor(double score) {
      if (score >= 80) return Colors.green;
      if (score >= 60) return Colors.lightGreen;
      if (score >= 40) return Colors.orange;
      return Colors.red;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.primary),
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        RouteNames.dashboard,
                        (route) => false,
                      );
                    },
                  ),
                  Text(
                    'ANALYSIS RESULT',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Score Display
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: result.overallScore.toInt().toString(),
                            style: GoogleFonts.inter(
                              fontSize: 72,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: '/100',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Score Label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: getScoreColor(result.overallScore),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        getScoreLabel(result.overallScore),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'VOCAL CONFIDENCE SCORE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Feedback Message
                    Text(
                      _getFeedbackMessage(result.overallScore),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Listen to Voice Button (all platforms)
                    Container(
                      width: double.infinity,
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Listen to Your Voice',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _recordingPath != null
                                    ? 'Available for 14 days'
                                    : 'Not available',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (_isRecordingLoading)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              onPressed: _recordingPath != null
                                  ? _togglePlayback
                                  : null,
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 18,
                              ),
                              label: Text(
                                _isPlaying ? 'Pause' : 'Play',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Pitch Stability Card
                    _buildMetricCard(
                      title: 'PITCH STABILITY',
                      score: result.confidenceScore.pitchScore,
                      value:
                          '${result.audioMetrics.pitchMean.toStringAsFixed(1)} Hz',
                      subtitle: 'Mean pitch frequency',
                      getLabel: getScoreLabel,
                      getColor: getScoreColor,
                    ),

                    const SizedBox(height: 16),

                    // Voice Quality Card
                    _buildMetricCard(
                      title: 'VOICE QUALITY',
                      score: result.confidenceScore.voiceQualityScore,
                      value:
                          'Jitter: ${result.audioMetrics.jitterLocal.toStringAsFixed(2)}%',
                      subtitle:
                          'Shimmer: ${result.audioMetrics.shimmerLocal.toStringAsFixed(2)}%',
                      getLabel: getScoreLabel,
                      getColor: getScoreColor,
                    ),

                    const SizedBox(height: 16),

                    // Speaking Pace Card
                    _buildPaceCard(
                      wpm: result.wpm,
                      score: result.confidenceScore.paceScore,
                      getLabel: getScoreLabel,
                      getColor: getScoreColor,
                    ),

                    const SizedBox(height: 16),

                    // Fluency Card
                    _buildFluencyCard(
                      fillerCount: result.fillerCount,
                      totalWords: result.fluencyMetrics.totalWords,
                      score: result.confidenceScore.fluencyScore,
                      fillerWords: result.fluencyMetrics.fillerWordsFound,
                      getLabel: getScoreLabel,
                      getColor: getScoreColor,
                    ),

                    const SizedBox(height: 16),

                    // Transcription Card
                    _buildTranscriptionCard(result.transcription),

                    const SizedBox(height: 32),

                    // Practice Again Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            RouteNames.practiceSetup,
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Practice again',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // View Detailed Feedback Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            RouteNames.detailedFeedback,
                            arguments: result,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        child: Text(
                          'View detailed feedback',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFeedbackMessage(double score) {
    if (score >= 80) {
      return 'Excellent work! Your speaking\nskills are impressive.';
    } else if (score >= 60) {
      return 'Great effort! You\'re consistently\nimproving your delivery.';
    } else if (score >= 40) {
      return 'Good progress! Keep practicing\nto improve your confidence.';
    } else {
      return 'Keep going! Regular practice\nwill help you improve.';
    }
  }

  Widget _buildMetricCard({
    required String title,
    required double score,
    required String value,
    required String subtitle,
    required String Function(double) getLabel,
    required Color Function(double) getColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inactive.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: getColor(score),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  getLabel(score),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaceCard({
    required double wpm,
    required double score,
    required String Function(double) getLabel,
    required Color Function(double) getColor,
  }) {
    final isOptimal = wpm >= 120 && wpm <= 150;
    final feedback = isOptimal
        ? 'Great pace! Within optimal range (120-150 WPM)'
        : wpm < 120
        ? 'Consider speaking a bit faster (optimal: 120-150 WPM)'
        : 'Consider slowing down (optimal: 120-150 WPM)';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inactive.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SPEAKING PACE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: getColor(score),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  getLabel(score),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: wpm.toInt().toString(),
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                TextSpan(
                  text: ' WPM',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (wpm / 200).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.inactive.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(getColor(score)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feedback,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFluencyCard({
    required int fillerCount,
    required int totalWords,
    required double score,
    required List<String> fillerWords,
    required String Function(double) getLabel,
    required Color Function(double) getColor,
  }) {
    final fillerRatio = totalWords > 0 ? (fillerCount / totalWords * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inactive.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FLUENCY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: getColor(score),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  getLabel(score),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$fillerCount',
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Filler words',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalWords',
                      style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Total words',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (fillerWords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fillerWords.take(5).map((word) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inactive.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '"$word"',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${fillerRatio.toStringAsFixed(1)}% filler word ratio',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionCard(String transcription) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inactive.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRANSCRIPTION',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            transcription.isEmpty ? 'No speech detected' : transcription,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.primary,
              height: 1.6,
            ),
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
