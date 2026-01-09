import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple service to call the style-scan API hosted on your VPS.
/// Usage: create with the baseUrl of your VPS, e.g. `http://1.2.3.4:5000`.
class StyleScanService {
  final String baseUrl;
  final Duration timeout;

  StyleScanService({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
  });

  /// Uploads [imageFile] to the `/predict` endpoint and returns the parsed JSON map.
  /// Throws on non-200 responses or network errors.
  Future<Map<String, dynamic>> scanImage(File imageFile) async {
    final uri = Uri.parse('${baseUrl.replaceAll(r"/\z", '')}/predict');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamed = await request.send().timeout(timeout);
    final resp = await http.Response.fromStream(streamed).timeout(timeout);

    if (resp.statusCode != 200) {
      throw HttpException('Server returned ${resp.statusCode}: ${resp.body}');
    }

    final Map<String, dynamic> body =
        json.decode(resp.body) as Map<String, dynamic>;
    return body;
  }
}
