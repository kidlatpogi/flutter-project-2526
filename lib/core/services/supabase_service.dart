import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for direct Supabase database operations
/// Handles profile, sessions, and data management without backend
class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get the current user's ID
  String? get _userId => _supabase.auth.currentUser?.id;

  /// Fetch user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_userId == null) return null;

    try {
      final response = await _supabase
          .from('user_profiles')
          .select('id,nickname,full_name,custom_full_name,is_active,account_status,created_at,updated_at')
          .eq('id', _userId!)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Create user profile
  /// Creates initial profile with Google account data
  Future<Map<String, dynamic>?> createUserProfile({
    required String nickname,
    String? fullName,
  }) async {
    if (_userId == null) return null;

    try {
      // Get user metadata from Supabase auth (contains Google full name if signed in via Google)
      final authUser = _supabase.auth.currentUser;
      final googleFullName = authUser?.userMetadata?['full_name'] as String?;
      
      final data = {
        'id': _userId,
        'nickname': nickname,
        // full_name will be synced from Google OAuth by Supabase
        'full_name': fullName ?? googleFullName,
        // custom_full_name stores user's preference (separate from Google sync)
        'custom_full_name': fullName,
        'is_active': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await _supabase
          .from('user_profiles')
          .insert(data)
          .select()
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Update user profile
  /// Note: Only updates fields that are explicitly provided (not null)
  /// This allows preserving existing values when updating just one field
  Future<Map<String, dynamic>?> updateUserProfile({
    String? nickname,
    String? fullName,
  }) async {
    if (_userId == null) return null;

    try {
      final data = <String, dynamic>{};
      if (nickname != null) data['nickname'] = nickname;
      // Update custom_full_name (user's preference, not synced from Google)
      if (fullName != null) data['custom_full_name'] = fullName;

      if (data.isEmpty) return null;

      final response = await _supabase
          .from('user_profiles')
          .update(data)
          .eq('id', _userId!)
          .select()
          .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Fetch recent sessions for the current user
  Future<List<Map<String, dynamic>>> getSessions({int limit = 20}) async {
    if (_userId == null) return [];

    try {
      final response = await _supabase
          .from('sessions')
          .select()
          .eq('user_id', _userId!)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Get total sessions count for the current user
  Future<int> getTotalSessionsCount() async {
    if (_userId == null) return 0;

    try {
      final response = await _supabase
          .from('sessions')
          .select()
          .eq('user_id', _userId!);

      return response.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get a specific session by ID
  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    if (_userId == null) return null;

    try {
      final response = await _supabase
          .from('sessions')
          .select()
          .eq('session_id', sessionId)
          .eq('user_id', _userId!)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Get analysis results for a session
  Future<Map<String, dynamic>?> getAnalysisBySession(String sessionId) async {
    if (_userId == null) return null;

    try {
      final response = await _supabase
          .from('analysis_results')
          .select()
          .eq('session_id', sessionId)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Clear all user data (sessions and analysis results)
  Future<Map<String, dynamic>> clearUserData() async {
    if (_userId == null) {
      return {'success': false, 'message': 'User not authenticated'};
    }

    try {
      // First, get all session IDs to delete associated recordings
      final sessions = await _supabase
          .from('sessions')
          .select('session_id, recording_path')
          .eq('user_id', _userId!);

      final sessionIds = sessions.map((s) => s['session_id']).toList();
      final recordingPaths = sessions
          .map((s) => s['recording_path'])
          .where((path) => path != null)
          .toList();

      // Delete analysis results first (foreign key constraint)
      for (final sessionId in sessionIds) {
        try {
          await _supabase
              .from('analysis_results')
              .delete()
              .eq('session_id', sessionId);
        } catch (e) {
        }
      }

      // Delete sessions
      await _supabase
          .from('sessions')
          .delete()
          .eq('user_id', _userId!);

      // Delete recordings from storage
      int deletedFiles = 0;
      for (final path in recordingPaths) {
        try {
          final cleanPath = path.toString().replaceAll('/storage/v1/object/public/recordings/', '');
          await _supabase.storage
              .from('recordings')
              .remove([cleanPath]);
          deletedFiles++;
        } catch (e) {
        }
      }

      return {
        'success': true,
        'deleted_sessions': sessions.length,
        'deleted_files': deletedFiles,
        'message': 'All user data cleared successfully'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to clear user data: ${e.toString()}'
      };
    }
  }

  /// Stream sessions in real-time
  Stream<List<Map<String, dynamic>>> watchSessions({int limit = 20}) {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId!)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  /// Stream user profile in real-time
  Stream<Map<String, dynamic>?> watchUserProfile() {
    if (_userId == null) {
      return Stream.value(null);
    }

    return _supabase
        .from('user_profiles')
        .stream(primaryKey: ['id'])
        .eq('id', _userId!)
        .map((data) => data.isEmpty ? null : data.first);
  }
}
