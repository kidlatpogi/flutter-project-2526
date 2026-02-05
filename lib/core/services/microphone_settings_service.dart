import 'dart:convert';
import 'storage_service.dart';

/// Model for microphone settings
class MicrophoneSettings {
  final String? selectedMicrophoneId;
  final String? selectedMicrophoneName;

  MicrophoneSettings({
    this.selectedMicrophoneId,
    this.selectedMicrophoneName,
  });

  Map<String, dynamic> toJson() => {
    'selectedMicrophoneId': selectedMicrophoneId,
    'selectedMicrophoneName': selectedMicrophoneName,
  };

  factory MicrophoneSettings.fromJson(Map<String, dynamic> json) {
    return MicrophoneSettings(
      selectedMicrophoneId: json['selectedMicrophoneId'],
      selectedMicrophoneName: json['selectedMicrophoneName'],
    );
  }
}

/// Service for managing microphone selection persistence
class MicrophoneSettingsService {
  static const String _storageKey = 'microphone_settings';
  final StorageService _storage = StorageService();

  /// Load saved microphone settings or return null if not set
  Future<MicrophoneSettings?> loadSettings() async {
    try {
      final jsonString = await _storage.read(_storageKey);
      if (jsonString == null) {
        return null;
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return MicrophoneSettings.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  /// Save microphone selection to storage
  Future<void> saveSettings(MicrophoneSettings settings) async {
    try {
      final jsonString = jsonEncode(settings.toJson());
      await _storage.write(_storageKey, jsonString);
    } catch (e) {
    }
  }

  /// Save just the microphone ID
  Future<void> saveMicrophoneSelection(String microphoneId, String microphoneName) async {
    final settings = MicrophoneSettings(
      selectedMicrophoneId: microphoneId,
      selectedMicrophoneName: microphoneName,
    );
    await saveSettings(settings);
  }

  /// Clear microphone settings (use default)
  Future<void> clearSettings() async {
    try {
      await _storage.delete(_storageKey);
    } catch (e) {
    }
  }
}
