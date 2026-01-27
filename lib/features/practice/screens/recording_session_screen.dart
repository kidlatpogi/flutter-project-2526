import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../core/services/api_service.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/analysis_model.dart';
import '../../../routing/route_names.dart';

class RecordingSessionScreen extends StatefulWidget {
  const RecordingSessionScreen({super.key});

  @override
  State<RecordingSessionScreen> createState() => _RecordingSessionScreenState();
}

class _RecordingSessionScreenState extends State<RecordingSessionScreen> {
  final AudioService _audioService = AudioService();
  final ApiService _apiService = ApiService();
  
  bool _isRecording = false;
  bool _isAnalyzing = false;
  int _seconds = 0;
  Timer? _timer;
  bool _showScript = true;
  String? _errorMessage;
  double _amplitude = 0.0;
  Timer? _amplitudeTimer;

  @override
  void initState() {
    super.initState();
    _initRecording();
  }

  Future<void> _initRecording() async {
    try {
      // Request permission and start recording automatically
      final hasPermission = await _audioService.requestPermission();
      if (hasPermission) {
        await _startRecording();
      } else {
        setState(() {
          _errorMessage = 'Microphone permission is required to record';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize recording: $e';
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      await _audioService.startRecording();
      setState(() {
        _isRecording = true;
        _errorMessage = null;
      });
      _startTimer();
      _startAmplitudeMonitor();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start recording: $e';
      });
    }
  }

  void _startAmplitudeMonitor() {
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (_isRecording) {
        final amp = await _audioService.getAmplitude();
        setState(() {
          _amplitude = amp;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  Future<void> _stopAndAnalyze() async {
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
    });
    _timer?.cancel();
    _amplitudeTimer?.cancel();

    try {
      // Stop recording and get the file
      final File? audioFile = await _audioService.stopRecording();
      
      if (audioFile == null) {
        throw Exception('No audio file was recorded');
      }

      // Upload to backend for analysis
      final AnalysisModel result = await _apiService.uploadAudio(audioFile);

      // Navigate to analysis result with the data
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          RouteNames.analysis,
          arguments: result,
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Analysis failed: $e';
      });
    }
  }

  void _toggleRecording() {
    if (_isAnalyzing) return;
    
    if (_isRecording) {
      _stopAndAnalyze();
    } else {
      _startRecording();
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
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
                    icon: Icon(Icons.close, color: AppColors.primary),
                    onPressed: () {
                      _showExitDialog();
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'SPEECH 1',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _showScript
                    ? SingleChildScrollView(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              height: 1.8,
                              color: AppColors.primary,
                            ),
                            children: [
                              TextSpan(
                                text: 'It is a long established\n',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              TextSpan(
                                text: 'fact that a reader will be distracted by the readable content ',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              TextSpan(
                                text: 'of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using \'Content here, content here\', making it look like readable English.',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Center(
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.inactive.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Waveform
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 60,
                child: CustomPaint(
                  painter: WaveformPainter(isActive: _isRecording),
                  size: const Size(double.infinity, 60),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Timer
            Text(
              _formatTime(_seconds),
              style: GoogleFonts.inter(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1,
              ),
            ),

            const SizedBox(height: 8),

            // Recording indicator or analyzing state
            if (_isAnalyzing) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Analyzing your speech...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : AppColors.inactive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isRecording ? 'RECORDING' : 'PAUSED',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Control Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Left button (Toggle script/video)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.inactive.withOpacity(0.3),
                        width: 2,
                      ),
                      color: AppColors.surface,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _showScript ? Icons.videocam_off : Icons.videocam,
                        color: AppColors.inactive,
                      ),
                      onPressed: () {
                        setState(() {
                          _showScript = !_showScript;
                        });
                      },
                    ),
                  ),

                  // Center button (Stop/Start recording)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.stop_rounded,
                        color: AppColors.surface,
                        size: 40,
                      ),
                      onPressed: _toggleRecording,
                    ),
                  ),

                  // Right button (Settings/Options)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.inactive.withOpacity(0.3),
                        width: 2,
                      ),
                      color: AppColors.surface,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.more_horiz,
                        color: AppColors.inactive,
                      ),
                      onPressed: () {
                        // TODO: Show options
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Exit Recording',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        content: Text(
          'Are you sure you want to stop recording? Your progress will be lost.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue Recording',
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit recording screen
            },
            child: Text(
              'Exit',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Waveform painter for audio visualization
class WaveformPainter extends CustomPainter {
  final bool isActive;

  WaveformPainter({required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    final barWidth = 3.0;
    final spacing = 2.0;
    final totalBars = (size.width / (barWidth + spacing)).floor();

    for (int i = 0; i < totalBars; i++) {
      final x = i * (barWidth + spacing);

      // Generate varying heights for waveform effect
      final heightFactor = isActive
          ? (i % 5 == 0
              ? 0.8
              : i % 3 == 0
                  ? 0.6
                  : i % 2 == 0
                      ? 0.4
                      : 0.3)
          : 0.2;

      final barHeight = size.height * heightFactor;
      final y = (size.height - barHeight) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.isActive != isActive;
  }
}
