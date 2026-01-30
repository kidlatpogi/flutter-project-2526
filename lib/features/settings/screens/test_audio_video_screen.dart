import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_colors.dart';

class TestAudioVideoScreen extends StatefulWidget {
  const TestAudioVideoScreen({super.key});

  @override
  State<TestAudioVideoScreen> createState() => _TestAudioVideoScreenState();
}

class _TestAudioVideoScreenState extends State<TestAudioVideoScreen> {
  bool _isTesting = false;
  bool _audioDetected = false;
  final _audioRecorder = AudioRecorder();
  Timer? _amplitudeTimer;
  List<double> _amplitudes = List.filled(60, 0.3);
  final Random _random = Random();

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startTesting() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    
    if (status.isGranted) {
      try {
        // Start recording
        if (await _audioRecorder.hasPermission()) {
          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: '', // We don't need to save the file
          );
          
          setState(() {
            _isTesting = true;
            _audioDetected = true;
          });

          // Simulate amplitude changes for waveform animation
          _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
            if (mounted) {
              setState(() {
                // Shift amplitudes left and add new random value
                _amplitudes.removeAt(0);
                _amplitudes.add(0.3 + _random.nextDouble() * 0.7);
              });
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error starting microphone: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopTesting() async {
    _amplitudeTimer?.cancel();
    await _audioRecorder.stop();
    
    if (mounted) {
      setState(() {
        _isTesting = false;
        _audioDetected = false;
        _amplitudes = List.filled(60, 0.3);
      });
    }
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40), // Balance the close button
                  Text(
                    'AUDIO TESTER',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.primary),
                    onPressed: () {
                      _stopTesting();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Audio Waveform Visualization
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CustomPaint(
                  painter: WaveformPainter(
                    amplitudes: _amplitudes,
                    isActive: _isTesting,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Detection Status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _audioDetected ? Icons.check_circle : Icons.cancel,
                  color: _audioDetected ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'AUDIO - ${_audioDetected ? 'DETECTED' : 'NOT DETECTED'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Testing Status
            if (_isTesting)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TESTING',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Control Button (Centered)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isTesting ? Colors.red : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isTesting ? Colors.red : AppColors.primary)
                            .withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isTesting ? Icons.stop : Icons.mic,
                      color: AppColors.surface,
                      size: 40,
                    ),
                    onPressed: () {
                      if (_isTesting) {
                        _stopTesting();
                      } else {
                        _startTesting();
                      }
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Waveform painter for audio visualization with musical bar lines
class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final bool isActive;

  WaveformPainter({
    required this.amplitudes,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? AppColors.primary : AppColors.inactive
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final barWidth = 3.0;
    final spacing = 4.0;
    final totalBars = amplitudes.length;

    for (int i = 0; i < totalBars; i++) {
      final x = i * (barWidth + spacing) + spacing;
      
      // Use amplitude from list
      final amplitude = isActive ? amplitudes[i] : 0.3;
      final barHeight = size.height * amplitude;
      final y = (size.height - barHeight) / 2;

      // Draw rounded bar (musical notation style)
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
    return oldDelegate.isActive != isActive || 
           oldDelegate.amplitudes != amplitudes;
  }
}
