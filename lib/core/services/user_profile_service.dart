import 'dart:convert';
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
      final response = await _client
          .get(uri, headers: _buildHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } else if (response.statusCode == 404) {
        // Profile not found
        return null;
      } else {
        throw Exception('Failed to get profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get profile: $e');
    }
  }

  /// Update user profile (create if doesn't exist)
  Future<Map<String, dynamic>> updateUserProfile({
    String? nickname,
    String? fullName,
  }) async {
    final uri = Uri.parse('$baseUrl/profile');
    
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (fullName != null) body['full_name'] = fullName;

    try {
      final response = await _client
          .put(
            uri,
            headers: _buildHeaders(),
            body: json.encode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
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
      return false;
    }
  }

  /// Get user's nickname
  Future<String?> getNickname() async {
    try {
      final profile = await getUserProfile();
      return profile?['nickname'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get user's nickname with fallback to display name
  Future<String?> getNicknameOrDisplayName() async {
    try {
      final profile = await getUserProfile();
      final nickname = profile?['nickname'] as String?;
      
      // If we have a nickname, return it
      if (nickname != null && nickname.isNotEmpty) {
        return nickname;
      }
      
      // Otherwise, try to get display name from current user
      final user = Supabase.instance.client.auth.currentUser;
      final displayName = user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];
      
      if (displayName != null) {
        // Return first name from display name
        return (displayName as String).split(' ').first;
      }
      
      return null;
    } catch (e) {
      // If backend fails, try to get display name from current user
      final user = Supabase.instance.client.auth.currentUser;
      final displayName = user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'];
      
      if (displayName != null) {
        return (displayName as String).split(' ').first;
      }
      
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
