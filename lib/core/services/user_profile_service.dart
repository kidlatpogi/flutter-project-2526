import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing user profiles
class UserProfileService {
  // Base URL for the FastAPI backend
  static const String baseUrl = 'http://localhost:8000';
  
  // For Android emulator, use: 'http://10.0.2.2:3000'

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 30);

  UserProfileService({http.Client? client}) : _client = client ?? http.Client();

  /// Get the current JWT access token from Supabase session
  String? get _accessToken =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  /// Build headers for API requests
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    return headers;
  }

  /// Get user profile from backend
  Future<Map<String, dynamic>?> getUserProfile() async {
    final uri = Uri.parse('$baseUrl/profile');

    try {
      print('Fetching profile from $uri');
      print('Authorization header: ${_buildHeaders()['Authorization']}');
      
      final response = await _client
          .get(uri, headers: _buildHeaders())
          .timeout(_timeout);

      print('Profile response status: ${response.statusCode}');
      print('Profile response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } else if (response.statusCode == 404) {
        // Profile not found
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Token may have expired.');
      } else {
        throw Exception('Failed to get profile: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching profile: $e');
      if (e.toString().contains('TimeoutException') || e.toString().contains('Connection timed out')) {
        throw Exception('Connection timeout. Make sure the backend server is running on port 8000.');
      } else if (e.toString().contains('Connection refused')) {
        throw Exception('Cannot connect to backend server at $baseUrl. Make sure it is running.');
      }
      rethrow;
    }
  }

  /// Update user profile (create if doesn't exist)
  Future<Map<String, dynamic>> updateUserProfile({
    String? nickname,
    String? fullName,
    bool? isActive,
  }) async {
    final uri = Uri.parse('$baseUrl/profile');
    
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (fullName != null) body['full_name'] = fullName;
    if (isActive != null) body['is_active'] = isActive;

    print('Updating profile with body: $body');
    print('Authorization header: ${_buildHeaders()['Authorization']}');
    print('Backend URL: $uri');

    try {
      final response = await _client
          .put(
            uri,
            headers: _buildHeaders(),
            body: json.encode(body),
          )
          .timeout(_timeout);

      print('Profile update response status: ${response.statusCode}');
      print('Profile update response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Token may have expired. Please log in again.');
      } else if (response.statusCode == 422) {
        throw Exception('Invalid nickname format. Please check your input.');
      } else {
        throw Exception('Failed to update profile: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (e.toString().contains('TimeoutException') || e.toString().contains('Connection timed out')) {
        throw Exception('Connection timeout. Make sure the backend server is running on port 8000. (http://localhost:8000)');
      } else if (e.toString().contains('Connection refused')) {
        throw Exception('Cannot connect to backend server. Make sure it is running on port 8000. Start it with: run_backend_8000.ps1');
      }
      rethrow;
    }
  }

  /// Check if user has set up their profile (has nickname)
  Future<bool> hasNickname() async {
    try {
      final profile = await getUserProfile();
      return profile != null &&
             profile['has_profile'] == true &&
             profile['nickname'] != null &&
             (profile['nickname'] as String).isNotEmpty;
    } catch (e) {
      print('Error checking nickname: $e');
      return false;
    }
  }

  /// Get user's nickname or display name (first name from full_name)
  Future<String?> getNicknameOrDisplayName() async {
    try {
      final profile = await getUserProfile();
      if (profile == null) return null;
      
      // Prefer nickname if available
      if (profile['nickname'] != null && (profile['nickname'] as String).isNotEmpty) {
        return profile['nickname'] as String;
      }
      
      // Fall back to first name from full_name
      if (profile['full_name'] != null && (profile['full_name'] as String).isNotEmpty) {
        return (profile['full_name'] as String).split(' ').first;
      }
      
      return null;
    } catch (e) {
      print('Error getting nickname or display name: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
