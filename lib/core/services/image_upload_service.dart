import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

/// Image upload service that works on both web and mobile platforms
class ImageUploadService {
  static final _imagePicker = ImagePicker();

  /// Pick an image from gallery (works on all platforms)
  static Future<XFile?> pickImage() async {
    if (kIsWeb) {
      // Use web-specific implementation
      return await _pickImageWeb();
    } else {
      // Use mobile implementation
      return await _pickImageMobile();
    }
  }

  /// Mobile implementation using image_picker package
  static Future<XFile?> _pickImageMobile() async {
    try {
      return await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
    } catch (e) {
      print('Error picking image on mobile: $e');
      return null;
    }
  }

  /// Web implementation - overridden in image_upload_service.web.dart
  static Future<XFile?> _pickImageWeb() async {
    print('Web image picker not implemented in stub');
    return null;
  }
}
