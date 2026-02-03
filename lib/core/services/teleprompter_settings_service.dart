import 'dart:convert';
import '../../data/models/teleprompter_settings_model.dart';
import 'storage_service.dart';

/// Service for managing teleprompter settings persistence
class TeleprompterSettingsService {
  static const String _storageKey = 'teleprompter_settings';
  final StorageService _storage = StorageService();

  /// Load saved settings or return defaults
  Future<TeleprompterSettings> loadSettings() async {
    try {
      final jsonString = await _storage.read(_storageKey);
      if (jsonString == null) {
        return const TeleprompterSettings();
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return TeleprompterSettings.fromJson(json);
    } catch (e) {
      // If error loading, return defaults
      return const TeleprompterSettings();
    }
  }

  /// Save settings to storage
  Future<void> saveSettings(TeleprompterSettings settings) async {
    try {
      final jsonString = jsonEncode(settings.toJson());
      await _storage.write(_storageKey, jsonString);
    } catch (e) {
      // Silently fail if storage fails
    }
  }

  /// Clear settings (reset to defaults)
  Future<void> clearSettings() async {
    await _storage.delete(_storageKey);
  }
}
