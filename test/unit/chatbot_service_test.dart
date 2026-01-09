// test/unit/chatbot_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:geges_smartbarber/services/chatbot_service.dart';
import 'package:geges_smartbarber/models/chatbot_response.dart';

// Generate Mock: flutter pub run build_runner build (Manual) atau pakai Custom Mock class sederhana
// Untuk kecepatan, kita buat MockClient manual tanpa build_runner
class MockClient extends Mock implements http.Client {
  @override
  Future<http.Response> post(Uri? url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    return super.noSuchMethod(
      Invocation.method(#post, [url], {#headers: headers, #body: body, #encoding: encoding}),
      returnValue: Future.value(http.Response('', 200)),
    );
  }
}

void main() {
  group('ChatbotService Tests', () {
    late ChatbotService chatbotService;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      chatbotService = ChatbotService(client: mockClient);
    });

    test('askQuestion returns ChatbotResponse on 200 OK', () async {
      // ARRANGE
      final mockResponse = {
        "answer": "Halo, saya Gia.",
        "detection_mode": "GENERAL_CHAT",
        "confidence": "High",
        "sources": [],
        "process_time": 0.5
      };
      
      when(mockClient.post(
        any, 
        headers: anyNamed('headers'), 
        body: anyNamed('body')
      )).thenAnswer((_) async => http.Response(jsonEncode(mockResponse), 200));

      // ACT
      final result = await chatbotService.askQuestion("Halo");

      // ASSERT
      expect(result, isA<ChatbotResponse>());
      expect(result.answer, "Halo, saya Gia.");
      expect(result.detectionMode, "GENERAL_CHAT");
    });

    test('askQuestion throws Exception on error code', () async {
      // ARRANGE
      when(mockClient.post(
        any, 
        headers: anyNamed('headers'), 
        body: anyNamed('body')
      )).thenAnswer((_) async => http.Response('Internal Server Error', 500));

      // ACT & ASSERT
      expect(chatbotService.askQuestion("Halo"), throwsException);
    });
  });
}
