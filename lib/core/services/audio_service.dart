import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../utils/web_audio_utils.dart';

/// Exception thrown when audio operations fail
class AudioException implements Exception {
  final String message;
  AudioException(this.message);

  @override
  String toString() => 'AudioException: $message';
}

class RecordedAudio {
  final File? file;
  final Uint8List? bytes;
  final String fileName;

  const RecordedAudio({this.file, this.bytes, required this.fileName});
}

/// Service for audio recording and file management
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;
  bool _isRecording = false;
  static const Duration _recordingRetention = Duration(days: 14);

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Get the path of the current/last recording
  String? get currentRecordingPath => _currentRecordingPath;

  /// Request microphone permission
  Future<bool> requestPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    if (kIsWeb) return true;
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

    // Get temp directory for recording (not available on web)
    String? path;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (!kIsWeb) {
      final directory = await getTemporaryDirectory();
      path = '${directory.path}/recording_$timestamp.wav';
      _currentRecordingPath = path;
    } else {
      path = 'recording_$timestamp.webm';
      _currentRecordingPath = path;
    }

    // Configure and start recording
    try {
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
      );
      await _recorder.start(config, path: path);
      _isRecording = true;
      return _currentRecordingPath ?? '';
    } catch (e) {
      throw AudioException('Failed to start recording: $e');
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (!_isRecording) return;
    try {
      await _recorder.pause();
    } catch (e) {
      throw AudioException('Failed to pause recording: $e');
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (!_isRecording) return;
    try {
      await _recorder.resume();
    } catch (e) {
      throw AudioException('Failed to resume recording: $e');
    }
  }

  /// Stop recording and return the file path
  Future<RecordedAudio?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    try {
      final path = await _recorder.stop();
      _isRecording = false;

      if (path != null) {
        _currentRecordingPath = path;
        final fileName = path.split('/').last;
        if (kIsWeb) {
          final bytes = await readWebFileBytes(path);
          return RecordedAudio(bytes: bytes, fileName: fileName);
        }
        return RecordedAudio(file: File(path), fileName: fileName);
      }
      return null;
    } catch (e) {
      _isRecording = false;
      throw AudioException('Failed to stop recording: $e');
    }
  }

  /// Save recording locally by session ID
  /// 
  /// On native platforms: Saves to local cache directory
  /// On web: Recording is already on the backend from analysis, no local save needed
  Future<String?> saveRecordingForSession(
    File sourceFile,
    String sessionId,
  ) async {
    // Web recordings are stored on backend during analysis
    // No need to save locally
    if (kIsWeb) return null;

    try {
      final directory = await _getRecordingCacheDir();
      if (directory == null) return null;

      final fileName = 'session_$sessionId.wav';
      final targetPath = '${directory.path}/$fileName';

      // Copy to cache directory
      final saved = await sourceFile.copy(targetPath);

      // Clean old recordings after saving
      await purgeOldRecordings();

      return saved.path;
    } catch (e) {
      return null;
    }
  }

  /// Get recording path or URL for a session
  /// 
  /// For native platforms (iOS, Android, Windows, macOS, Linux):
  /// Returns the local file path from cache directory
  /// 
  /// For web:
  /// Returns a backend URL to stream the recording
  /// The URL format is constructed from the API service base URL
  Future<String?> getRecordingPathForSession(String sessionId) async {
    // On web, return a streaming URL from the backend
    if (kIsWeb) {
      // Format: /sessions/{sessionId}/recording
      // This assumes your backend provides a GET endpoint to serve recordings
      return '/sessions/$sessionId/recording';
    }

    final directory = await _getRecordingCacheDir();
    if (directory == null) return null;

    final filePath = '${directory.path}/session_$sessionId.wav';
    final file = File(filePath);
    if (!await file.exists()) return null;

    // Delete if expired
    final modified = await file.lastModified();
    final now = DateTime.now();
    if (now.difference(modified) > _recordingRetention) {
      await file.delete();
      return null;
    }

    return filePath;
  }

  /// Delete cached recordings older than retention period
  Future<void> purgeOldRecordings() async {
    if (kIsWeb) return;
    final directory = await _getRecordingCacheDir();
    if (directory == null) return;

    final now = DateTime.now();
    final files = directory.listSync().whereType<File>();
    for (final file in files) {
      try {
        final modified = await file.lastModified();
        if (now.difference(modified) > _recordingRetention) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  /// Clear all cached recordings
  Future<void> clearRecordingCache() async {
    if (kIsWeb) return;
    final directory = await _getRecordingCacheDir();
    if (directory == null) return;
    final files = directory.listSync().whereType<File>();
    for (final file in files) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<Directory?> _getRecordingCacheDir() async {
    if (kIsWeb) return null;
    final baseDir = await getApplicationSupportDirectory();
    final recordingsDir = Directory('${baseDir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  /// Cancel current recording and delete the file
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }

    // Delete the file if it exists
    if (_currentRecordingPath != null && !kIsWeb) {
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
      final normalized =
          (amplitude.current + 60) / 60; // Assuming -60dB to 0dB range
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
