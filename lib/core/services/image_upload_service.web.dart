import 'package:image_picker/image_picker.dart';
import 'dart:html' as html;
import 'dart:typed_data' as typed_data;

/// Web-specific implementation of image upload using HTML file input
Future<XFile?> _pickImageWeb() async {
  try {
    // Create file input element that accepts images
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..click();

    // Wait for file selection
    await input.onChange.first;
    final files = input.files;
    
    if (files == null || files.isEmpty) return null;

    final file = files[0];
    final reader = html.FileReader();
    
    // Read file as array buffer
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    // Get the bytes from the file reader
    final bytes = reader.result as List<int>;
    
    // Create XFile from bytes
    return XFile.fromData(
      typed_data.Uint8List.fromList(bytes),
      mimeType: file.type,
      name: file.name,
    );
  } catch (e) {
    print('Error picking image on web: $e');
    rethrow;
  }
}
