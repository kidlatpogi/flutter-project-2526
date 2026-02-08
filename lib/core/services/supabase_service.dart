import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for direct Supabase database operations
/// Handles profile, sessions, and data management without backend
class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get the current user's ID
  String? get _userId => _supabase.auth.currentUser?.id;

  /// Fetch user profile using RPC function (bypasses RLS)
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (_userId == null) return null;

    try {
      developer.log('Fetching user profile for user: $_userId');
      final response = await _supabase.rpc('get_my_profile');

      if (response == null) {
        developer.log('RPC returned null, trying direct query');
      } else {
        developer.log('RPC response: $response');
      }

      if (response == null) return null;
      if (response is List && response.isNotEmpty) {
        final profile = Map<String, dynamic>.from(response.first as Map);
        developer.log('User profile fetched (from list): $profile');
        return profile;
      }
      if (response is Map) {
        final profile = Map<String, dynamic>.from(response);
        developer.log('User profile fetched (from map): $profile');
        return profile;
      }
      return null;
    } catch (e) {
      developer.log('RPC error: $e, trying direct query fallback');
      // Fallback to direct query if RPC doesn't exist yet
      try {
        final response = await _supabase
            .from('user_profiles')
            .select(
              'id,nickname,full_name,custom_full_name,is_active,account_status,has_password,created_at,updated_at',
            )
            .eq('id', _userId!)
            .maybeSingle();
        developer.log('Direct query succeeded: $response');
        return response;
      } catch (e2) {
        developer.log('Direct query also failed: $e2');
        return null;
      }
    }
  }

  /// Create user profile
  /// Creates initial profile with Google account data
  Future<Map<String, dynamic>?> createUserProfile({
    required String nickname,
    String? fullName,
    bool? hasPassword,
  }) async {
    if (_userId == null) return null;

    try {
      // Get user metadata from Supabase auth (contains Google data if signed in via Google)
      final authUser = _supabase.auth.currentUser;
      final userMetadata = authUser?.userMetadata;

      // Extract name data from Google OAuth (multiple possible keys)
      final googleFullName =
          userMetadata?['full_name'] ?? userMetadata?['name'] as String?;
      final givenName = userMetadata?['given_name'] as String?;

      // Use given_name as fallback for empty nickname
      final effectiveNickname = nickname.isNotEmpty
          ? nickname
          : (givenName ?? '');

      developer.log(
        'Creating profile for user $_userId with nickname: $effectiveNickname',
      );

      // Try RPC first
      try {
        final response = await _supabase.rpc(
          'upsert_my_profile',
          params: {
            'p_nickname': effectiveNickname,
            'p_full_name': fullName ?? googleFullName,
            'p_custom_full_name': fullName,
            'p_is_active': true,
            'p_has_password': hasPassword ?? false,
          },
        );

        developer.log('RPC upsert_my_profile succeeded: $response');
        if (response == null) return null;
        if (response is List && response.isNotEmpty) {
          return Map<String, dynamic>.from(response.first as Map);
        }
        if (response is Map) {
          return Map<String, dynamic>.from(response);
        }
      } catch (rpcError) {
        developer.log('RPC failed, trying direct insert: $rpcError');
        // Fallback: Direct insert if RPC fails
        try {
          final response = await _supabase
              .from('user_profiles')
              .insert({
                'id': _userId,
                'nickname': effectiveNickname,
                'full_name': fullName ?? googleFullName,
                'custom_full_name': fullName,
                'is_active': true,
                'has_password': hasPassword ?? false,
              })
              .select()
              .maybeSingle();
          developer.log('Direct insert succeeded: $response');
          return response;
        } catch (insertError) {
          developer.log('Direct insert also failed: $insertError');
        }
      }
      return null;
    } catch (e) {
      developer.log('createUserProfile error: $e');
      return null;
    }
  }

  /// Update user profile
  /// Note: Only updates fields that are explicitly provided (not null)
  /// This allows preserving existing values when updating just one field
  Future<Map<String, dynamic>?> updateUserProfile({
    String? nickname,
    String? fullName,
    bool? isActive,
    String? accountStatus,
    bool? hasPassword,
  }) async {
    if (_userId == null) return null;

    try {
      developer.log(
        'Updating profile for user $_userId: nickname=$nickname, fullName=$fullName',
      );

      // Try RPC first
      try {
        final response = await _supabase.rpc(
          'upsert_my_profile',
          params: {
            'p_nickname': nickname,
            'p_full_name': fullName,
            'p_custom_full_name': fullName,
            'p_is_active': isActive,
            'p_account_status': accountStatus,
            'p_has_password': hasPassword,
          },
        );

        developer.log('RPC update succeeded: $response');
        if (response == null) return null;
        if (response is List && response.isNotEmpty) {
          return Map<String, dynamic>.from(response.first as Map);
        }
        if (response is Map) {
          return Map<String, dynamic>.from(response);
        }
      } catch (rpcError) {
        developer.log('RPC failed, trying direct update: $rpcError');
        // Fallback: Direct update if RPC fails
        try {
          final updateData = <String, dynamic>{};
          if (nickname != null) updateData['nickname'] = nickname;
          if (fullName != null) updateData['full_name'] = fullName;
          if (fullName != null) updateData['custom_full_name'] = fullName;
          if (isActive != null) updateData['is_active'] = isActive;
          if (accountStatus != null)
            updateData['account_status'] = accountStatus;
          if (hasPassword != null) updateData['has_password'] = hasPassword;

          final response = await _supabase
              .from('user_profiles')
              .update(updateData)
              .eq('id', _userId!)
              .select()
              .maybeSingle();

          developer.log('Direct update succeeded: $response');
          return response;
        } catch (updateError) {
          developer.log('Direct update also failed: $updateError');
        }
      }
      return null;
    } catch (e) {
      developer.log('updateUserProfile error: $e');
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
        } catch (e) {}
      }

      // Delete sessions
      await _supabase.from('sessions').delete().eq('user_id', _userId!);

      // Delete recordings from storage
      int deletedFiles = 0;
      for (final path in recordingPaths) {
        try {
          final cleanPath = path.toString().replaceAll(
            '/storage/v1/object/public/recordings/',
            '',
          );
          await _supabase.storage.from('recordings').remove([cleanPath]);
          deletedFiles++;
        } catch (e) {}
      }

      return {
        'success': true,
        'deleted_sessions': sessions.length,
        'deleted_files': deletedFiles,
        'message': 'All user data cleared successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to clear user data: ${e.toString()}',
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
