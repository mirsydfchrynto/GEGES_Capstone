// lib/services/chatbot_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geges_smartbarber/models/chatbot_response.dart';

class ChatbotService {
  static const String _baseUrl = 'https://mirsydfchyrnto-chatbot-api-demo.hf.space/chat';
  final http.Client _client;

  ChatbotService({http.Client? client}) : _client = client ?? http.Client();

  Future<ChatbotResponse> askQuestion(String question) async {
    try {
      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'question': question,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return ChatbotResponse.fromJson(data);
      } else {
        throw Exception('Failed to get answer from chatbot: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error communicating with chatbot API: $e');
    }
  }
}
