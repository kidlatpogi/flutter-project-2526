import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_names.dart';
import '../../dashboard/widgets/dashboard_navbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentIndex = 3; // Profile is selected
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _authService = AuthService();
  final _userProfileService = UserProfileService();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _nickname;
  String? _avatarUrl;
  String? _originalFullName;
  String? _originalAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Load data from Supabase auth
      final authFullName = _authService.displayName ?? '';
      final authEmail = _authService.email ?? '';
      final authAvatarUrl = _authService.avatarUrl;

      // Load profile from database (fallback for full name)
      final profile = await _userProfileService.getUserProfile();
      final profileFullName = profile?['full_name'] ?? '';

      final resolvedFullName = authFullName.isNotEmpty
          ? authFullName
          : (profileFullName as String);

      _fullNameController.text = resolvedFullName;
      _emailController.text = authEmail;
      _avatarUrl = authAvatarUrl;

      // Store original values
      _originalFullName = resolvedFullName;
      _originalAvatarUrl = authAvatarUrl;

      // Load nickname
      _nickname = profile?['nickname'];

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _hasUnsavedChanges() {
    return _fullNameController.text != _originalFullName ||
        _avatarUrl != _originalAvatarUrl;
  }

  Future<void> _handleCancel() async {
    if (_hasUnsavedChanges()) {
      final shouldCancel = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Discard Changes?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          content: Text(
            'You have unsaved changes. Are you sure you want to discard them?',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep Editing',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Discard',
                style: GoogleFonts.inter(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldCancel == true && mounted) {
        Navigator.pushReplacementNamed(context, RouteNames.dashboard);
      }
    } else {
      // No changes, go to dashboard
      Navigator.pushReplacementNamed(context, RouteNames.dashboard);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      // Use the cross-platform image upload service
      final image = await ImageUploadService.pickImage();

      if (image == null) return;

      setState(() => _isUploadingImage = true);

      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) throw Exception('Not authenticated');

      // Upload to Supabase Storage - store in user folder
      final fileName =
          '${currentUser.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();

      await supabase.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      // Update user metadata
      await supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': publicUrl}),
      );

      if (mounted) {
        setState(() {
          _avatarUrl = publicUrl;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final fullName = _fullNameController.text.trim();
      
      // Update backend profile
      await _userProfileService.updateUserProfile(fullName: fullName);
      
      // Update Supabase auth user metadata for full_name (consistent with authService)
      final supabase = Supabase.instance.client;
      await supabase.auth.updateUser(
        UserAttributes(
          data: {'full_name': fullName},
        ),
      );
      
      // Refresh user data to update displayName getter
      await _authService.refreshUserData();
      
      // Update local state
      if (mounted) {
        setState(() {
          _originalFullName = fullName;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Edit Profile',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 32),

                // Profile Picture
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.inactive.withOpacity(0.3),
                        ),
                        child: _avatarUrl != null
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: _avatarUrl!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                  memCacheWidth: 240,
                                  memCacheHeight: 240,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.person,
                                    size: 60,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 60,
                                color: AppColors.primary,
                              ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _isUploadingImage ? null : _pickAndUploadImage,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _isUploadingImage
                                  ? AppColors.inactive
                                  : AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 3,
                              ),
                            ),
                            child: _isUploadingImage
                                ? Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.surface,
                                    ),
                                  )
                                : Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: AppColors.surface,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Full Name
                Text(
                  'Full Name',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _fullNameController,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.inactive.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.inactive.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Email
                Text(
                  'Email',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  readOnly: true, // Email cannot be changed
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.inactive.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.inactive.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.inactive.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.inactive.withOpacity(0.3),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Nickname (read-only with edit button)
                Text(
                  'Nickname',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final result = await Navigator.pushNamed(
                      context,
                      RouteNames.editNickname,
                    );
                    if (result == true) {
                      // Refresh user data if nickname was updated
                      _loadUserData();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.inactive.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _nickname ?? 'No nickname set',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: _nickname != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Icon(Icons.edit, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Change Password
                InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, RouteNames.changePassword);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.inactive.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Change Password',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: AppColors.primary,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _handleCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.inactive.withOpacity(0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 80), // Space for bottom nav
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DashboardNavbar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            setState(() {
              _currentIndex = index;
            });
            // Navigate based on index
            if (index == 0) {
              // Scripts
              Navigator.pushReplacementNamed(context, RouteNames.script);
            } else if (index == 1) {
              // Progress
              Navigator.pushReplacementNamed(context, RouteNames.progress);
            } else if (index == 2) {
              // Home
              Navigator.pushReplacementNamed(context, RouteNames.dashboard);
            } else if (index == 4) {
              // Settings
              Navigator.pushReplacementNamed(context, RouteNames.settings);
            }
          }
        },
      ),
    );
  }
}
