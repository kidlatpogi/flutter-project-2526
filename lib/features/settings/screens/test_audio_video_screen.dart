import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class TestAudioVideoScreen extends StatefulWidget {
  const TestAudioVideoScreen({super.key});

  @override
  State<TestAudioVideoScreen> createState() => _TestAudioVideoScreenState();
}

class _TestAudioVideoScreenState extends State<TestAudioVideoScreen> {
  bool _isTesting = true;
  bool _audioDetected = true;
  bool _videoDetected = true;

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
                    'AUDIO/VIDEO TESTER',
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
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Video Preview Area
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.inactive.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    Icons.videocam,
                    size: 60,
                    color: AppColors.inactive,
                  ),
                ),
              ),
            ),

            // Audio Waveform Visualization
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CustomPaint(
                  painter: WaveformPainter(isActive: _isTesting),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Detection Status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _videoDetected ? Icons.check_circle : Icons.cancel,
                        color: _videoDetected ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'VIDEO - ${_videoDetected ? 'DETECTED' : 'NOT DETECTED'}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

            // Control Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Switch Camera Button
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.inactive.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.flip_camera_ios,
                        color: AppColors.inactive,
                      ),
                      onPressed: () {
                        // TODO: Switch camera
                      },
                    ),
                  ),

                  // Record/Stop Button
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isTesting ? Icons.stop : Icons.play_arrow,
                        color: AppColors.surface,
                        size: 40,
                      ),
                      onPressed: () {
                        setState(() {
                          _isTesting = !_isTesting;
                        });
                      },
                    ),
                  ),

                  // Settings Button
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.inactive.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: AppColors.inactive,
                      ),
                      onPressed: () {
                        // TODO: Open settings
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
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
      final x = i * (barWidth + spacing) + spacing;
      
      // Generate varying heights for waveform effect
      final baseHeight = size.height * 0.3;
      final variation = isActive 
          ? (i % 3 == 0 ? size.height * 0.7 : i % 2 == 0 ? size.height * 0.5 : size.height * 0.4)
          : baseHeight;
      
      final barHeight = variation;
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
