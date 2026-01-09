import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/models/app_rating.dart';

class RatingService {
  final FirebaseFirestore _firestore;
  final http.Client _client;
  static const String _sentimentApiUrl = 'https://mirsydfchyrnto-review-api.hf.space/predict';

  RatingService({FirebaseFirestore? firestore, http.Client? client})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _client = client ?? http.Client();

  Future<void> submitRating(AppRating rating) async {
    try {
      // 1. Analyze Sentiment
      final sentimentResult = await _analyzeSentiment(rating.feedback);
      
      final prediction = sentimentResult['prediction'];
      
      // 2. Filter Logic: Only save if prediction is 'positif' or 'negatif'
      if (prediction == 'positif' || prediction == 'negatif') {
         // Create a new Map for saving, including sentiment data
         final data = rating.toJson();
         data['sentiment'] = prediction;
         data['sentimentConfidence'] = (sentimentResult['confidence'] as num?)?.toDouble();
         
         await _firestore.collection('app_ratings').add(data);
      } else {
        // "jika hasil bukan negatif atau positif jangan masukan ke database"
        // We do not save it. We return silently so the UI treats it as "handled".
        // This keeps the database clean.
        return;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _analyzeSentiment(String text) async {
    try {
      final response = await _client.post(
        Uri.parse(_sentimentApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'review': text}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Sentiment analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to sentiment service: $e');
    }
  }

  Future<bool> hasUserRated(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('app_ratings')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
