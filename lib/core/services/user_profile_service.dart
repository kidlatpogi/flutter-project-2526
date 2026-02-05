import 'supabase_service.dart';

/// Service for managing user profiles
/// Now uses SupabaseService for direct database access to reduce backend load
class UserProfileService {
  final SupabaseService _supabaseService = SupabaseService();

  /// Get user profile from Supabase directly
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      return await _supabaseService.getUserProfile();
    } catch (e) {
      return null;
    }
  }

  /// Update user profile (create if doesn't exist)
  Future<Map<String, dynamic>> updateUserProfile({
    String? nickname,
    String? fullName,
    bool? isActive,
    String? accountStatus,
  }) async {
    try {
      // Get existing profile
      final existingProfile = await _supabaseService.getUserProfile();

      if (existingProfile == null) {
        // Create new profile - let SupabaseService handle getting Google full name
        // Only pass fullName if explicitly provided
        final newProfile = await _supabaseService.createUserProfile(
          nickname: nickname ?? '',
          fullName: fullName, // Can be null - SupabaseService will use Google name
        );
        return newProfile ?? {};
      } else {
        // Profile exists - only update fields that are explicitly provided
        final updatedProfile = await _supabaseService.updateUserProfile(
          nickname: nickname,
          fullName: fullName, // Only updates if not null
        );
        return updatedProfile ?? existingProfile;
      }
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  /// Check if user has set up their profile (has nickname)
  Future<bool> hasNickname() async {
    try {
      final profile = await getUserProfile();
      return profile != null &&
          profile['nickname'] != null &&
          (profile['nickname'] as String).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get user's nickname or display name (first name from custom_full_name/full_name)
  Future<String?> getNicknameOrDisplayName() async {
    try {
      final profile = await getUserProfile();
      if (profile == null) return null;

      // Prefer nickname if available
      if (profile['nickname'] != null &&
          (profile['nickname'] as String).isNotEmpty) {
        return profile['nickname'] as String;
      }

      // Fall back to first name from custom_full_name, then full_name
      if (profile['custom_full_name'] != null &&
          (profile['custom_full_name'] as String).isNotEmpty) {
        return (profile['custom_full_name'] as String).split(' ').first;
      }

      if (profile['full_name'] != null &&
          (profile['full_name'] as String).isNotEmpty) {
        return (profile['full_name'] as String).split(' ').first;
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
