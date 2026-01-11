import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

// AIService supports an optional backend endpoint via --dart-define=AI_API_URL="https://...".
// If the environment variable is not provided, it falls back to a local mock implementation to keep the app functional offline and in tests.
class AIService {
  final String _endpoint = const String.fromEnvironment(
    'AI_API_URL',
    defaultValue: '',
  );

  /// Provides a response for the AI chatbot, using remote endpoint when configured.
  Future<String> getChatbotResponse(String message) async {
    if (_endpoint.isNotEmpty) {
      try {
        final resp = await http
            .post(
              Uri.parse(_endpoint),
              headers: {HttpHeaders.contentTypeHeader: 'application/json'},
              body: jsonEncode({'message': message}),
            )
            .timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          return body['reply']?.toString() ?? 'Maaf, tidak ada jawaban.';
        }
      } catch (_) {
        // fallback to local.
      }
    }

    // Local fallback implementation (kept for offline/testing)
    await Future.delayed(const Duration(seconds: 2));
    final lc = message.toLowerCase();
    if (lc.contains('jam buka')) {
      return 'Kami buka setiap hari dari jam 10:00 pagi sampai 21:00 malam.';
    } else if (lc.contains('harga') || lc.contains('cukur')) {
      return 'Harga potong rambut standar adalah Rp 50.000. Untuk layanan lain, silakan cek di menu layanan kami.';
    } else if (lc.contains('lokasi') || lc.contains('alamat')) {
      return 'Kami berada di Jl. Kemerdekaan No. 45, Kota Keren. Anda bisa menemukan kami di Google Maps!';
    }

    return 'Terima kasih sudah bertanya. Saat ini saya adalah bot sederhana. Untuk pertanyaan lebih lanjut, silakan hubungi admin kami.';
  }

  /// Sends the image to the AI StyleScan API and returns the structured result.
  Future<Map<String, dynamic>> scanImage(File image) async {
    const String styleScanUrl = 'https://mirsydfchyrnto-stylescan-api.hf.space/predict';

    try {
      debugPrint("AI Service: Reading image bytes...");
      final imageBytes = await image.readAsBytes();
      
      debugPrint("AI Service: Sending ${imageBytes.length} bytes to $styleScanUrl");
      final request = http.MultipartRequest('POST', Uri.parse(styleScanUrl));
      
      request.headers['Accept'] = 'application/json';

      // UPLOAD AS BYTES (Most robust method)
      request.files.add(http.MultipartFile.fromBytes(
        'file', 
        imageBytes,
        filename: 'scan.jpg', // Hardcoded valid extension
      ));

      // Send request
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("AI Service Response: ${response.statusCode}");
      // debugPrint("AI Service Body: ${response.body}"); // Uncomment for deep debug

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'status': body['status'], 
          'message': body['message'],
          'data': body['data'],
        };
      } else {
        // Parse error detail
        String errorMsg = 'Gagal memproses gambar (Error ${response.statusCode})';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody['detail'] != null) {
             errorMsg += ': ${errBody['detail']}';
          }
        } catch (_) {
          // Fallback if not JSON
          errorMsg += ': ${response.body.substring(0, min(100, response.body.length))}';
        }
        
        return {
          'success': false,
          'message': errorMsg,
        };
      }
    } catch (e) {
      debugPrint("AI Service Exception: $e");
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: $e',
      };
    }
  }

  // Helper for min (if not available)
  int min(int a, int b) => a < b ? a : b;

  /// (Legacy/Fallback) Provides a mock suggestion.
  Future<String> getStyleSuggestion(File image) async {
    // Redirect to new method if needed, or keep for backward compatibility
    final result = await scanImage(image);
    if (result['success'] == true) {
      final data = result['data'];
      final best = data['best_match'];
      return "Gaya Rambut: ${best['label']} (${(best['confidence'] * 100).toStringAsFixed(0)}%)\n\n${data['note'] ?? ''}";
    }
    return _localStyleSuggestion();
  }

  String _localStyleSuggestion() =>
      'Berdasarkan analisis bentuk wajah Anda, gaya rambut "Undercut" dengan sedikit "Fade" di bagian samping akan sangat cocok. Ini akan memberikan kesan rapi namun tetap modern dan stylish.';
}