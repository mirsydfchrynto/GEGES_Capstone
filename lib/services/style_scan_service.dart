import 'dart:io';
import 'dart:convert';
import 'dart:async';
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
  /// Backend supports up to 5MB and is header-agnostic.
  Future<Map<String, dynamic>> scanImage(File imageFile) async {
    final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/predict');

    try {
      final request = http.MultipartRequest('POST', uri);
      
      // Essential header for FastAPI response negotiation
      request.headers['accept'] = 'application/json';
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', 
          imageFile.path,
          filename: 'stylescan_input.jpg',
        ),
      );

      final streamed = await request.send().timeout(timeout);
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 200) {
        return json.decode(resp.body) as Map<String, dynamic>;
      } else {
        // Handle 400, 413, 422, and 500
        String errorMsg = 'Gagal memproses gambar.';
        try {
          final errBody = json.decode(resp.body);
          // FastAPI common error fields: 'detail' or 'message'
          errorMsg = errBody['detail']?.toString() ?? errBody['message']?.toString() ?? 'Error ${resp.statusCode}';
        } catch (_) {
          if (resp.statusCode == 413) errorMsg = 'File terlalu besar (Maks 5MB).';
          if (resp.statusCode == 404) errorMsg = 'Endpoint tidak ditemukan.';
        }
        throw HttpException(errorMsg);
      }
    } on SocketException {
      throw const HttpException('Gagal terhubung ke server. Periksa koneksi internet Anda.');
    } on TimeoutException {
      throw const HttpException('Koneksi terputus (Timeout). Coba lagi dengan gambar yang lebih kecil.');
    } catch (e) {
      rethrow;
    }
  }
}
