import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

// Conditional imports for web only
import 'dart:html' if (dart.library.html) 'dart:html' as web_html;
import 'dart:typed_data' if (dart.library.html) 'dart:typed_data' as web_typed_data;

/// Image upload service that works on both web and mobile platforms
class ImageUploadService {
  static final _imagePicker = ImagePicker();

  /// Pick an image from gallery (works on all platforms)
  static Future<XFile?> pickImage() async {
    if (kIsWeb) {
      return await _pickImageWeb();
    } else {
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
      return null;
    }
  }

  /// Web implementation using HTML file input
  static Future<XFile?> _pickImageWeb() async {
    try {
      // Use reflection to access dart:html without compilation issues
      if (!kIsWeb) return null;

      // This code uses dart:html when available (only on web)
      return await _webFilePickerImpl();
    } catch (e) {
      return null;
    }
  }

  /// Web file picker implementation
  static Future<XFile?> _webFilePickerImpl() async {
    // Create file input dynamically
    final input = web_html.FileUploadInputElement() as dynamic
      ..accept = 'image/*'
      ..click();

    // Wait for file selection
    await input.onChange.first;
    final files = input.files as List?;

    if (files == null || files.isEmpty) return null;

    final file = files[0] as dynamic;
    final reader = web_html.FileReader() as dynamic;

    // Read file as array buffer
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    // Get the bytes from the file reader
    final bytes = reader.result as List<int>;

    // Create XFile from bytes
    return XFile.fromData(
      web_typed_data.Uint8List.fromList(bytes),
      mimeType: file.type as String?,
      name: file.name as String,
    );
  }
}
