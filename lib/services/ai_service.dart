import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

/// AIService handles communication with the AI Backend (StyleScan and Chatbot).
/// Uses standard 'http' package configured to strictly mimic curl requests for maximum compatibility.
class AIService {
  final String _endpoint = const String.fromEnvironment(
    'AI_API_URL',
    defaultValue: '',
  );

  /// Provides a response for the AI chatbot.
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
      } catch (_) {}
    }
    await Future.delayed(const Duration(seconds: 2));
    final lc = message.toLowerCase();
    if (lc.contains('jam buka')) {
      return 'Kami buka setiap hari dari jam 10:00 pagi sampai 21:00 malam.';
    }
    return 'Terima kasih sudah bertanya. Saat ini saya adalah bot sederhana.';
  }

  /// Sends the image to the AI StyleScan API.
  /// Uses standard http.MultipartRequest with strict MIME type enforcement.
  /// Strategy: Raw Bytes + Hardcoded Filename + Explicit MediaType.
  Future<Map<String, dynamic>> scanImage(File image) async {
    const String styleScanUrl = 'https://mirsydfchyrnto-stylescan-api.hf.space/predict';

    try {
      debugPrint("AI Service: Reading file bytes...");
      final imageBytes = await image.readAsBytes();
      
      // 1. Detect Real Extension
      String ext = image.path.split('.').last.toLowerCase();
      // Handle cache file extensions like 'jpg_temp' or 'image_picker_...jpg'
      if (ext.contains('jpg') || ext.contains('jpeg')) {
        ext = 'jpg';
      } else if (ext.contains('png')) {
        ext = 'png';
      } else if (ext.contains('webp')) {
        ext = 'webp';
      } else {
        ext = 'jpg'; // Fallback default
      }

      final mimeType = MediaType('image', ext == 'jpg' ? 'jpeg' : ext);
      final fileName = 'scan.$ext';

      debugPrint("AI Service: Sending as $mimeType with name $fileName");
      
      var request = http.MultipartRequest('POST', Uri.parse(styleScanUrl));
      
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
        contentType: mimeType,
      ));

      // Send
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("AI Service Response Code: ${response.statusCode}");
      debugPrint("AI Service Body: ${response.body}");

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'status': body['status'], 
          'message': body['message'],
          'data': body['data'],
        };
      } else {
        // Try to parse error detail
        String errorMsg = 'Gagal memproses gambar (Error ${response.statusCode})';
        try {
          final err = jsonDecode(response.body);
          if (err['detail'] != null) errorMsg += ": ${err['detail']}";
        } catch (_) {}
        
        return {
          'success': false,
          'message': errorMsg,
        };
      }
    } catch (e) {
      debugPrint("AI Service Error: $e");
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi: $e',
      };
    }
  }

  Future<String> getStyleSuggestion(File image) async {
    final result = await scanImage(image);
    if (result['success'] == true) {
      final data = result['data'];
      final best = data['best_match'];
      if (best != null) {
        return "Rekomendasi Gaya: ${best['label']} (${(best['confidence'] * 100).toStringAsFixed(0)}%)\n\n${data['note'] ?? ''}";
      }
      return data['note'] ?? "Tidak ada gaya yang cocok terdeteksi.";
    }
    return 'Gagal melakukan scan.';
  }
}