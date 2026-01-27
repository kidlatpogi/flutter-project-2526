import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/analysis_model.dart';
import '../../../routing/route_names.dart';

class AnalysisResultScreen extends StatelessWidget {
  final AnalysisModel? analysisResult;

  const AnalysisResultScreen({super.key, this.analysisResult});

  @override
  Widget build(BuildContext context) {
    // Get the analysis result from arguments if not passed directly
    final result = analysisResult ??
        ModalRoute.of(context)?.settings.arguments as AnalysisModel?;

    // If no result, show error state
    if (result == null) {
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
                  'No analysis data available',
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
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            RouteNames.progress,
                            (route) => false,
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
        border: Border.all(
          color: AppColors.inactive.withOpacity(0.3),
        ),
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
        border: Border.all(
          color: AppColors.inactive.withOpacity(0.3),
        ),
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
    final fillerRatio =
        totalWords > 0 ? (fillerCount / totalWords * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.inactive.withOpacity(0.3),
        ),
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
        border: Border.all(
          color: AppColors.inactive.withOpacity(0.3),
        ),
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
