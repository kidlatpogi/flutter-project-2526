import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/analysis_model.dart';
import '../../../routing/route_names.dart';

class RecordingSessionScreen extends StatefulWidget {
  final bool isScripted;
  final String? scriptTitle;
  final String? scriptContent;

  const RecordingSessionScreen({
    super.key,
    this.isScripted = true,
    this.scriptTitle,
    this.scriptContent,
  });

  @override
  State<RecordingSessionScreen> createState() => _RecordingSessionScreenState();
}

class _RecordingSessionScreenState extends State<RecordingSessionScreen> with SingleTickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  final ApiService _apiService = ApiService();
  
  bool _isRecording = false;
  bool _isAnalyzing = false;
  bool _isPaused = false;
  final Stopwatch _stopwatch = Stopwatch();
  late final Ticker _ticker;
  int _elapsedSeconds = 0;
  bool _showScript = true;
  bool _isScripted = true;
  String? _scriptTitle;
  String? _scriptContent;
  final ScrollController _teleprompterController = ScrollController();
  bool _isTeleprompterRunning = false;
  double _teleprompterSpeed = 40.0; // pixels per second
  String? _errorMessage;
  double _currentAmplitude = 0.0;
  int _lastAmplitudeCheck = 0;

  @override
  void initState() {
    super.initState();
    _isScripted = widget.isScripted;
    _showScript = widget.isScripted;
    _scriptTitle = widget.scriptTitle;
    _scriptContent = widget.scriptContent;
    
    // Use Ticker for smooth, efficient updates
    _ticker = createTicker(_onTick);
    _ticker.start();
    
    _initRecording();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    
    // Update timer display (only when seconds change)
    if (_stopwatch.isRunning) {
      final newSeconds = _stopwatch.elapsed.inSeconds;
      if (newSeconds != _elapsedSeconds) {
        setState(() {
          _elapsedSeconds = newSeconds;
        });
      }
    }
    
    // Update amplitude every 300ms (not every frame)
    final now = elapsed.inMilliseconds;
    if (_isRecording && !_isPaused && now - _lastAmplitudeCheck >= 300) {
      _lastAmplitudeCheck = now;
      _updateAmplitude();
    }
    
    // Smooth teleprompter scrolling
    if (_isTeleprompterRunning && _teleprompterController.hasClients) {
      final max = _teleprompterController.position.maxScrollExtent;
      final pixelsPerFrame = _teleprompterSpeed / 60; // ~60 fps
      final next = (_teleprompterController.offset + pixelsPerFrame).clamp(0.0, max);
      if (next < max) {
        _teleprompterController.jumpTo(next);
      } else {
        _isTeleprompterRunning = false;
      }
    }
  }

  Future<void> _updateAmplitude() async {
    if (!_isRecording || _isPaused) return;
    try {
      final amp = await _audioService.getAmplitude();
      if (mounted && (_currentAmplitude - amp).abs() > 0.02) {
        setState(() {
          _currentAmplitude = amp;
        });
      }
    } catch (_) {}
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
        _isPaused = false;
        _errorMessage = null;
        _currentAmplitude = 0.0;
      });
      _stopwatch.start();
      _startTeleprompter();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start recording: $e';
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _teleprompterController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _startTeleprompter() {
    if (!_isScripted || !_showScript) return;
    // Small delay to ensure UI is rendered
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _isTeleprompterRunning = true;
      }
    });
  }

  void _stopTeleprompter() {
    _isTeleprompterRunning = false;
  }

  Future<void> _togglePauseResume() async {
    if (!_isRecording || _isAnalyzing) return;
    try {
      if (_isPaused) {
        await _audioService.resumeRecording();
        setState(() {
          _isPaused = false;
        });
        _stopwatch.start();
        _startTeleprompter();
      } else {
        await _audioService.pauseRecording();
        setState(() {
          _isPaused = true;
          _currentAmplitude = 0.0;
        });
        _stopwatch.stop();
        _stopTeleprompter();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to toggle pause: $e';
      });
    }
  }

  Future<void> _restartRecording() async {
    if (_isAnalyzing) return;
    try {
      await _audioService.cancelRecording();
      _stopTeleprompter();
      setState(() {
        _elapsedSeconds = 0;
        _isRecording = false;
        _isPaused = false;
        _currentAmplitude = 0.0;
      });
      _stopwatch
        ..reset()
        ..stop();
      if (_teleprompterController.hasClients) {
        _teleprompterController.jumpTo(0.0);
      }
      await _startRecording();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to restart recording: $e';
      });
    }
  }

  Future<void> _stopAndAnalyze() async {
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
      _isPaused = false;
      _currentAmplitude = 0.0;
    });
    _stopTeleprompter();
    _stopwatch.stop();

    try {
      // Stop recording and get the file
      final RecordedAudio? recorded = await _audioService.stopRecording();

      if (recorded == null) {
        throw Exception('No audio file was recorded');
      }

      // Upload to backend for analysis
      if (kIsWeb && recorded.bytes == null) {
        throw Exception('No audio data available for upload');
      }

      final AnalysisModel result = kIsWeb
          ? await _apiService.uploadAudioBytes(
              recorded.bytes ?? Uint8List(0),
              fileName: recorded.fileName,
              contentType: _getWebContentType(recorded.fileName),
            )
          : await _apiService.uploadAudio(recorded.file!);

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
    }
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _getWebContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.webm')) return 'audio/webm';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    return 'audio/wav';
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
                        _isScripted
                            ? (_scriptTitle?.toUpperCase() ?? 'SCRIPTED SPEECH')
                            : 'FREE SPEECH',
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
                child: _isScripted && _showScript
                    ? SingleChildScrollView(
                    controller: _teleprompterController,
                        child: Text(
                          _scriptContent?.trim().isNotEmpty == true
                              ? _scriptContent!
                              : 'No script content available.',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            height: 1.8,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _isScripted
                              ? 'Teleprompter hidden'
                              : 'Teleprompter disabled for Free Speech',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            // Waveform
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ((_isRecording && !_isPaused) ? _currentAmplitude : 0.0).clamp(0.0, 1.0),
                    backgroundColor: AppColors.inactive.withOpacity(0.2),
                    color: AppColors.primary,
                    minHeight: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Timer
            Text(
              _formatTime(_elapsedSeconds),
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
                      color: (_isRecording && !_isPaused)
                          ? Colors.red
                          : AppColors.inactive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (_isRecording && !_isPaused) ? 'RECORDING' : 'PAUSED',
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
              child: Column(
                children: [
                  // Toggle script button (only for scripted mode)
                  if (_isScripted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _showScript ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _showScript ? AppColors.primary : AppColors.inactive.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _showScript = !_showScript;
                            });
                            if (_showScript) {
                              _startTeleprompter();
                            } else {
                              _stopTeleprompter();
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showScript ? Icons.visibility : Icons.visibility_off,
                                color: _showScript ? AppColors.primary : AppColors.inactive,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _showScript ? 'Teleprompter ON' : 'Teleprompter OFF',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _showScript ? AppColors.primary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // Main control buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Left button (Pause/Resume)
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
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            color: _isRecording ? AppColors.inactive : AppColors.inactive.withOpacity(0.4),
                          ),
                          onPressed: _isRecording ? _togglePauseResume : null,
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
                            Icons.replay,
                            color: AppColors.inactive,
                          ),
                          onPressed: () {
                            _restartRecording();
                          },
                        ),
                      ),
                    ],
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

