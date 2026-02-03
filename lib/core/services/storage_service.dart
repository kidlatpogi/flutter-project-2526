import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  /// Initialize the storage service
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get SharedPreferences instance
  Future<SharedPreferences> get _preferences async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save data to storage
  Future<void> write(String key, String value) async {
    final prefs = await _preferences;
    await prefs.setString(key, value);
  }

  /// Read data from storage
  Future<String?> read(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }

  /// Delete data from storage
  Future<void> delete(String key) async {
    final prefs = await _preferences;
    await prefs.remove(key);
  }

  /// Clear all storage
  Future<void> clear() async {
    final prefs = await _preferences;
    await prefs.clear();
  }

  // Legacy methods for compatibility
  Future<void> saveData(String key, String value) => write(key, value);
  Future<String?> getData(String key) => read(key);
  Future<void> removeData(String key) => delete(key);
}
