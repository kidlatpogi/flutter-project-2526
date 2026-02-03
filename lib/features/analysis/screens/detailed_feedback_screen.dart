import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/analysis_model.dart';
import '../../../routing/route_names.dart';

class DetailedFeedbackScreen extends StatefulWidget {
  final AnalysisModel? analysisResult;
  final String? sessionId;

  const DetailedFeedbackScreen({
    super.key,
    this.analysisResult,
    this.sessionId,
  });

  @override
  State<DetailedFeedbackScreen> createState() => _DetailedFeedbackScreenState();
}

class _DetailedFeedbackScreenState extends State<DetailedFeedbackScreen> {
  late final ApiService _apiService;
  late final AudioService _audioService;
  late final AudioPlayer _audioPlayer;
  Future<AnalysisModel>? _analysisFuture;
  String? _recordingPath;
  String? _recordingSessionId;
  bool _isRecordingLoading = false;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

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

    // Listen to player completion
    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _currentPosition = Duration.zero;
      });
    });

    // Listen to duration changes
    _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _totalDuration = duration;
      });
    });

    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
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
    if (kIsWeb || sessionId == null || sessionId == _recordingSessionId) return;
    setState(() {
      _isRecordingLoading = true;
      _recordingSessionId = sessionId;
    });
    final path = await _audioService.getRecordingPathForSession(sessionId);
    if (mounted) {
      setState(() {
        _recordingPath = path;
        _isRecordingLoading = false;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordingPath == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      try {
        // Stop any existing playback first
        await _audioPlayer.stop();
        
        // On web, _recordingPath is a URL path like /sessions/{id}/recording
        // On native, it's a file path
        if (_recordingPath!.startsWith('/') || _recordingPath!.startsWith('http')) {
          // Play from URL (web or network)
          final fullUrl = _recordingPath!.startsWith('http') 
              ? _recordingPath! 
              : 'https://flutter-project-2526-production.up.railway.app${_recordingPath!}';
          await _audioPlayer.play(UrlSource(fullUrl));
        } else {
          // Play from file (native)
          await _audioPlayer.play(DeviceFileSource(_recordingPath!));
        }
      } catch (e) {
        print('Error playing recording: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error playing recording: $e')),
          );
        }
      }
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
    if (!kIsWeb &&
        resolvedSessionId != null &&
        resolvedSessionId != _recordingSessionId &&
        !_isRecordingLoading) {
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
                'Loading detailed feedback...',
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnalysisModel result) {
    final overallScore = result.overallScore;
    final pitchScore = result.confidenceScore.pitchScore;
    final fluencyScore = result.confidenceScore.fluencyScore;
    final voiceQualityScore = result.confidenceScore.voiceQualityScore;
    final paceScore = result.confidenceScore.paceScore;

    // Find weakest and strongest areas
    final scores = {
      'Pitch Stability': pitchScore,
      'Fluency': fluencyScore,
      'Voice Quality': voiceQualityScore,
      'Speaking Pace': paceScore,
    };
    final sortedScores = scores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final weakestArea = sortedScores.first;
    final strongestArea = sortedScores.last;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.primary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'DETAILED FEEDBACK',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 1,
                      ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overall Score Summary
                    _buildOverallSummaryCard(overallScore),

                    const SizedBox(height: 16),

                    if (!kIsWeb)
                      Container(
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
                                  'Session Recording',
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

                    const SizedBox(height: 24),

                    // Strengths Section
                    _buildSectionTitle(
                      'YOUR STRENGTHS',
                      Icons.star,
                      Colors.amber,
                    ),
                    const SizedBox(height: 12),
                    _buildStrengthCard(
                      strongestArea.key,
                      strongestArea.value,
                      result,
                    ),

                    const SizedBox(height: 24),

                    // Areas to Improve Section
                    _buildSectionTitle(
                      'AREAS TO IMPROVE',
                      Icons.trending_up,
                      AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    _buildImprovementCard(
                      weakestArea.key,
                      weakestArea.value,
                      result,
                    ),

                    const SizedBox(height: 24),

                    // Detailed Breakdown
                    _buildSectionTitle(
                      'SKILL BREAKDOWN',
                      Icons.analytics,
                      AppColors.accent,
                    ),
                    const SizedBox(height: 12),

                    _buildDetailedSkillCard(
                      'Pitch Stability',
                      pitchScore,
                      Icons.music_note,
                      _getPitchFeedback(result),
                      _getPitchTips(pitchScore),
                    ),

                    const SizedBox(height: 12),

                    _buildDetailedSkillCard(
                      'Voice Quality',
                      voiceQualityScore,
                      Icons.graphic_eq,
                      _getVoiceQualityFeedback(result),
                      _getVoiceQualityTips(voiceQualityScore),
                    ),

                    const SizedBox(height: 12),

                    _buildDetailedSkillCard(
                      'Speaking Pace',
                      paceScore,
                      Icons.speed,
                      _getPaceFeedback(result),
                      _getPaceTips(result),
                    ),

                    const SizedBox(height: 12),

                    _buildDetailedSkillCard(
                      'Fluency',
                      fluencyScore,
                      Icons.record_voice_over,
                      _getFluencyFeedback(result),
                      _getFluencyTips(result),
                    ),

                    const SizedBox(height: 24),

                    // Transcription Section
                    _buildSectionTitle(
                      'YOUR SPEECH',
                      Icons.text_fields,
                      AppColors.accent,
                    ),
                    const SizedBox(height: 12),
                    _buildTranscriptionCard(result),

                    // Mispronunciations Section - always show for awareness
                    ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        'MISPRONUNCIATIONS',
                        Icons.record_voice_over,
                        Colors.red,
                      ),
                      const SizedBox(height: 12),
                      _buildMispronunciationsCard(result),
                    ],

                    const SizedBox(height: 24),

                    // Personalized Action Plan
                    _buildSectionTitle(
                      'ACTION PLAN',
                      Icons.checklist,
                      Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildActionPlanCard(result, weakestArea.key),

                    const SizedBox(height: 32),

                    // Buttons
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
                          'Practice Again',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            RouteNames.dashboard,
                            (route) => false,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                        child: Text(
                          'Back to Dashboard',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallSummaryCard(double score) {
    final label = _getOverallLabel(score);
    final color = _getScoreColor(score);
    final message = _getOverallMessage(score);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toInt().toString(),
                style: GoogleFonts.inter(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '/100',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildStrengthCard(String area, double score, AnalysisModel result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                area,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${score.toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getStrengthMessage(area, score, result),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementCard(
    String area,
    double score,
    AnalysisModel result,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                area,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${score.toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getImprovementMessage(area, score, result),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedSkillCard(
    String title,
    double score,
    IconData icon,
    String feedback,
    List<String> tips,
  ) {
    final color = _getScoreColor(score);

    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      _getScoreLabel(score),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              _buildCircularProgress(score, color),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            feedback,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tips to improve:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress(double score, Color color) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 4,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                '${score.toInt()}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionCard(AnalysisModel result) {
    final fillerWords = result.fluencyMetrics.fillerWordsFound;
    final transcription = result.transcription;

    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(Icons.format_quote, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transcription',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              transcription.isEmpty
                  ? 'No transcription available'
                  : transcription,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.text,
                height: 1.6,
                fontStyle: transcription.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
          if (fillerWords.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Filler words detected:',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fillerWords.map((word) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    '"$word"',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(double seconds) {
    final minutes = (seconds ~/ 60).toString();
    final secs = (seconds % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Widget _buildMispronunciationsCard(AnalysisModel result) {
    // Check if this is a scripted speech (has accuracy score)
    final isScriptedSpeech = result.confidenceScore.overallScore > 0;
    
    // Show empty state if no mispronunciations
    if (result.mispronunciations.isEmpty) {
      return Container(
        width: double.infinity,
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
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Perfect Pronunciation!',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isScriptedSpeech
                  ? 'No mispronunciations detected.\nYour pronunciation matched the script perfectly!'
                  : 'Free speech analysis complete.\nYour speech is clear and well-articulated!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                '${result.mispronunciations.length} word${result.mispronunciations.length > 1 ? 's' : ''} need attention',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...result.mispronunciations.map((mispronunciation) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    // Timestamp
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatTimestamp(mispronunciation.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Words comparison
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Expected: ',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '"${mispronunciation.expectedWord}"',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                'You said: ',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                mispronunciation.spokenWord.isEmpty 
                                    ? '(omitted)'
                                    : '"${mispronunciation.spokenWord}"',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: mispronunciation.spokenWord.isEmpty 
                                      ? AppColors.textSecondary
                                      : Colors.red.shade700,
                                  fontStyle: mispronunciation.spokenWord.isEmpty 
                                      ? FontStyle.italic 
                                      : FontStyle.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'Tip: Practice saying these words slowly and clearly before your next session.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPlanCard(AnalysisModel result, String weakestArea) {
    final actions = _getActionPlan(result, weakestArea);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your personalized practice plan:',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          ...actions.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Helper methods
  String _getOverallLabel(double score) {
    if (score >= 80) return 'EXCELLENT';
    if (score >= 60) return 'GOOD';
    if (score >= 40) return 'NEEDS WORK';
    return 'KEEP PRACTICING';
  }

  String _getScoreLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Needs improvement';
    return 'Keep practicing';
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _getOverallMessage(double score) {
    if (score >= 80) {
      return 'Outstanding performance! You\'re demonstrating excellent speaking skills. Keep up the great work and continue refining your delivery.';
    }
    if (score >= 60) {
      return 'Great job! You\'re showing solid speaking abilities. Focus on the areas below to take your skills to the next level.';
    }
    if (score >= 40) {
      return 'You\'re making progress! With targeted practice on the areas highlighted below, you\'ll see significant improvement.';
    }
    return 'Every speaker starts somewhere! Focus on the fundamentals below, and you\'ll be amazed at how quickly you improve.';
  }

  String _getStrengthMessage(String area, double score, AnalysisModel result) {
    switch (area) {
      case 'Pitch Stability':
        return 'Your voice maintains consistent pitch, which conveys confidence and authority. This is a key trait of effective speakers!';
      case 'Voice Quality':
        return 'Your voice quality is clear and pleasant, making your message easy to listen to and understand.';
      case 'Speaking Pace':
        final wpm = result.wpm;
        if (wpm >= 120 && wpm <= 160) {
          return 'You\'re speaking at an ideal pace ($wpm words/min), giving your audience time to absorb your message while keeping them engaged.';
        }
        return 'Your speaking pace shows good control. Continue practicing to maintain this consistency.';
      case 'Fluency':
        return 'Your speech flows smoothly with minimal interruptions, making your delivery professional and easy to follow.';
      default:
        return 'This area is one of your strengths. Keep it up!';
    }
  }

  String _getImprovementMessage(
    String area,
    double score,
    AnalysisModel result,
  ) {
    switch (area) {
      case 'Pitch Stability':
        return 'Your pitch varies more than ideal, which can make you sound uncertain. Practice speaking with a steady, confident tone.';
      case 'Voice Quality':
        return 'There\'s room to improve your voice clarity. Focus on breathing from your diaphragm and relaxing your throat muscles.';
      case 'Speaking Pace':
        final wpm = result.wpm;
        if (wpm > 160) {
          return 'You\'re speaking quite fast ($wpm words/min). Try slowing down to give your audience time to process your message.';
        } else if (wpm < 120) {
          return 'Your pace is a bit slow ($wpm words/min). Try to increase your energy and speak with more momentum.';
        }
        return 'Work on maintaining a consistent pace throughout your speech.';
      case 'Fluency':
        final fillerCount = result.fillerCount;
        if (fillerCount > 0) {
          return 'You used $fillerCount filler words. Practice pausing silently instead of using "um", "uh", or "like".';
        }
        return 'Focus on speaking in complete, flowing sentences without unnecessary pauses.';
      default:
        return 'This is an area where focused practice will yield great results.';
    }
  }

  String _getPitchFeedback(AnalysisModel result) {
    final pitchMean = result.audioMetrics.pitchMean;
    final pitchStd = result.audioMetrics.pitchStd;
    final score = result.confidenceScore.pitchScore;

    if (score >= 80) {
      return 'Excellent pitch control! Your average pitch of ${pitchMean.toStringAsFixed(0)} Hz with a variation of ${pitchStd.toStringAsFixed(1)} Hz shows confident, authoritative speaking.';
    } else if (score >= 60) {
      return 'Good pitch stability. Your average pitch is ${pitchMean.toStringAsFixed(0)} Hz. Some variation (${pitchStd.toStringAsFixed(1)} Hz) is natural, but reducing it slightly would strengthen your delivery.';
    } else {
      return 'Your pitch varies quite a bit (${pitchStd.toStringAsFixed(1)} Hz variance), which can convey uncertainty. Practice speaking with a steadier tone.';
    }
  }

  List<String> _getPitchTips(double score) {
    if (score >= 80) {
      return [
        'Continue practicing to maintain this excellent control',
        'Try varying your pitch intentionally for emphasis on key points',
        'Record yourself to ensure consistency across different topics',
      ];
    } else if (score >= 60) {
      return [
        'Practice deep breathing before speaking to relax your vocal cords',
        'Read aloud for 5-10 minutes daily to build consistency',
        'Record yourself and listen for pitch fluctuations',
      ];
    } else {
      return [
        'Start each sentence on a steady, comfortable pitch',
        'Practice humming before speaking to find your natural pitch',
        'Speak more slowly to give yourself time to control your voice',
        'Try reading the same passage multiple times to build muscle memory',
      ];
    }
  }

  String _getVoiceQualityFeedback(AnalysisModel result) {
    final jitter = result.audioMetrics.jitterLocal;
    final shimmer = result.audioMetrics.shimmerLocal;
    final score = result.confidenceScore.voiceQualityScore;

    if (score >= 80) {
      return 'Your voice quality is excellent! Low jitter (${jitter.toStringAsFixed(2)}%) and shimmer (${shimmer.toStringAsFixed(2)}%) indicate a clear, professional voice.';
    } else if (score >= 60) {
      return 'Your voice quality is good. Jitter (${jitter.toStringAsFixed(2)}%) and shimmer (${shimmer.toStringAsFixed(2)}%) are within acceptable ranges with room for improvement.';
    } else {
      return 'Your voice shows some strain (jitter: ${jitter.toStringAsFixed(2)}%, shimmer: ${shimmer.toStringAsFixed(2)}%). Focus on relaxation and proper breathing techniques.';
    }
  }

  List<String> _getVoiceQualityTips(double score) {
    if (score >= 80) {
      return [
        'Stay hydrated to maintain vocal health',
        'Continue your good breathing habits',
        'Warm up your voice before important presentations',
      ];
    } else if (score >= 60) {
      return [
        'Practice diaphragmatic breathing exercises',
        'Stay well-hydrated throughout the day',
        'Avoid straining your voice by speaking from your chest, not throat',
        'Do vocal warm-ups before speaking sessions',
      ];
    } else {
      return [
        'Practice deep belly breathing for 5 minutes daily',
        'Drink plenty of water before and during speaking',
        'Avoid caffeine and alcohol before speaking',
        'Do lip trills and humming exercises to relax your voice',
        'Consider consulting a voice coach for personalized guidance',
      ];
    }
  }

  String _getPaceFeedback(AnalysisModel result) {
    final wpm = result.wpm;

    if (wpm >= 120 && wpm <= 160) {
      return 'Your speaking pace of $wpm words per minute is ideal! This allows your audience to easily follow and absorb your message.';
    } else if (wpm > 160) {
      return 'You\'re speaking at $wpm words per minute, which is faster than ideal. Your audience may struggle to keep up. Try slowing down.';
    } else if (wpm < 100) {
      return 'At $wpm words per minute, your pace is quite slow. While clarity is important, a faster pace can help maintain audience engagement.';
    } else if (wpm < 120) {
      return 'Your pace of $wpm words per minute is slightly slow. Try increasing your energy to keep your audience engaged.';
    } else {
      return 'Your pace of $wpm words per minute is slightly fast. Consider slowing down just a bit for better comprehension.';
    }
  }

  List<String> _getPaceTips(AnalysisModel result) {
    final wpm = result.wpm;

    if (wpm >= 120 && wpm <= 160) {
      return [
        'Great pace! Vary it slightly for emphasis on key points',
        'Use strategic pauses to let important ideas sink in',
        'Match your pace to your content - slow for complex ideas, faster for enthusiasm',
      ];
    } else if (wpm > 160) {
      return [
        'Consciously pause after each main point',
        'Practice reading aloud with a metronome or timer',
        'Take a breath before starting each new sentence',
        'Record yourself and count pauses - aim for more',
      ];
    } else {
      return [
        'Practice speaking with more energy and enthusiasm',
        'Read aloud at progressively faster speeds',
        'Eliminate unnecessary pauses between words',
        'Think ahead to what you\'ll say next while speaking',
      ];
    }
  }

  String _getFluencyFeedback(AnalysisModel result) {
    final fillerCount = result.fillerCount;
    final totalWords = result.fluencyMetrics.totalWords;
    final fillerRatio = totalWords > 0 ? (fillerCount / totalWords * 100) : 0;
    final score = result.confidenceScore.fluencyScore;

    if (score >= 80) {
      return 'Excellent fluency! You spoke $totalWords words with only $fillerCount filler words (${fillerRatio.toStringAsFixed(1)}%). Your speech flows naturally and professionally.';
    } else if (score >= 60) {
      return 'Good fluency with $fillerCount filler words in $totalWords total words. Reducing filler words will make your speech sound even more polished.';
    } else {
      return 'You used $fillerCount filler words out of $totalWords words (${fillerRatio.toStringAsFixed(1)}%). Filler words can undermine your credibility - let\'s work on reducing them.';
    }
  }

  List<String> _getFluencyTips(AnalysisModel result) {
    final score = result.confidenceScore.fluencyScore;

    if (score >= 80) {
      return [
        'Excellent! Keep practicing to maintain this fluency',
        'Challenge yourself with impromptu speaking exercises',
        'Help others improve their fluency by sharing your techniques',
      ];
    } else if (score >= 60) {
      return [
        'Practice pausing silently instead of saying "um" or "uh"',
        'Prepare and rehearse key points before speaking',
        'Record yourself and count filler words to track progress',
        'Slow down slightly to give yourself time to think',
      ];
    } else {
      return [
        'Replace filler words with silent pauses - it sounds more confident',
        'Practice speaking about familiar topics without any filler words',
        'Have a friend count your filler words during conversations',
        'Write out key points and practice saying them smoothly',
        'Join a speaking group like Toastmasters for regular practice',
      ];
    }
  }

  List<String> _getActionPlan(AnalysisModel result, String weakestArea) {
    final actions = <String>[];

    // Add general action
    actions.add(
      'Practice for 10-15 minutes daily, focusing on ${weakestArea.toLowerCase()}.',
    );

    // Add specific actions based on weakest area
    switch (weakestArea) {
      case 'Pitch Stability':
        actions.add(
          'Do daily humming exercises to find and maintain your natural pitch.',
        );
        actions.add(
          'Record yourself reading the same passage 3 times and compare consistency.',
        );
        break;
      case 'Voice Quality':
        actions.add(
          'Start each practice session with 5 minutes of breathing exercises.',
        );
        actions.add(
          'Drink 8 glasses of water daily to keep your voice hydrated.',
        );
        break;
      case 'Speaking Pace':
        if (result.wpm > 160) {
          actions.add(
            'Set a timer and practice speaking for 2 minutes at 140 words per minute.',
          );
          actions.add('Add intentional pauses after every sentence.');
        } else {
          actions.add(
            'Practice reading passages with increasing speed while maintaining clarity.',
          );
          actions.add(
            'Record yourself and gradually increase your pace over several sessions.',
          );
        }
        break;
      case 'Fluency':
        actions.add(
          'Practice impromptu speaking for 1-2 minutes on random topics.',
        );
        actions.add('When you feel an "um" coming, pause silently instead.');
        break;
    }

    // Add progress tracking
    actions.add(
      'Track your progress by practicing with Bigkas at least 3 times per week.',
    );

    return actions;
  }
}
