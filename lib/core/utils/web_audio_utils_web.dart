import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List> readWebFileBytes(String url) async {
  final response = await html.HttpRequest.request(
    url,
    responseType: 'arraybuffer',
  );
  final buffer = response.response as ByteBuffer;
  return Uint8List.view(buffer);
}
