import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Exception thrown when audio operations fail
class AudioException implements Exception {
  final String message;
  AudioException(this.message);

  @override
  String toString() => 'AudioException: $message';
}

/// Service for audio recording and file management
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get the path of the current/last recording
  String? get currentRecordingPath => _currentRecordingPath;

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Start recording audio
  /// Returns the file path where the recording will be saved
  Future<String> startRecording() async {
    // Check permission
    if (!await hasPermission()) {
      final granted = await requestPermission();
      if (!granted) {
        throw AudioException('Microphone permission denied');
      }
    }

    // Check if already recording
    if (_isRecording) {
      throw AudioException('Already recording');
    }

    // Get temp directory for recording
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _currentRecordingPath = '${directory.path}/recording_$timestamp.wav';

    // Configure and start recording
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );
      _isRecording = true;
      return _currentRecordingPath!;
    } catch (e) {
      throw AudioException('Failed to start recording: $e');
    }
  }

  /// Stop recording and return the file path
  Future<File?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null) {
        _currentRecordingPath = path;
        return File(path);
      }
      return null;
    } catch (e) {
      _isRecording = false;
      throw AudioException('Failed to stop recording: $e');
    }
  }

  /// Cancel current recording and delete the file
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }

    // Delete the file if it exists
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _currentRecordingPath = null;
    }
  }

  /// Get recording amplitude (for waveform visualization)
  Future<double> getAmplitude() async {
    if (!_isRecording) return 0.0;
    try {
      final amplitude = await _recorder.getAmplitude();
      // Normalize amplitude to 0-1 range
      // Amplitude is typically in dB, so we need to convert
      final normalized = (amplitude.current + 60) / 60; // Assuming -60dB to 0dB range
      return normalized.clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

  /// Check if recording is supported on this device
  Future<bool> isEncoderSupported() async {
    return await _recorder.isEncoderSupported(AudioEncoder.wav);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await cancelRecording();
    await _recorder.dispose();
  }
}