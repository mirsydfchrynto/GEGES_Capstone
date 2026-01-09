// lib/models/chatbot_response.dart

class ChatbotResponse {
  final String answer;
  final String detectionMode;
  final String confidence;
  final List<dynamic> sources;
  final double processTime;

  ChatbotResponse({
    required this.answer,
    required this.detectionMode,
    required this.confidence,
    required this.sources,
    required this.processTime,
  });

  factory ChatbotResponse.fromJson(Map<String, dynamic> json) {
    return ChatbotResponse(
      answer: json['answer'] ?? '',
      detectionMode: json['detection_mode'] ?? '',
      confidence: json['confidence'] ?? '',
      sources: json['sources'] ?? [],
      processTime: (json['process_time'] ?? 0).toDouble(),
    );
  }
}
