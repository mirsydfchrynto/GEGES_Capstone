import 'package:cloud_firestore/cloud_firestore.dart';

class AppRating {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final double rating;
  final String feedback;
  final String platform;
  final DateTime createdAt;
  final String? sentiment;
  final double? sentimentConfidence;

  AppRating({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.rating,
    required this.feedback,
    required this.platform,
    required this.createdAt,
    this.sentiment,
    this.sentimentConfidence,
  });

  factory AppRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppRating(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      feedback: data['feedback'] ?? '',
      platform: data['platform'] ?? 'unknown',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      sentiment: data['sentiment'],
      sentimentConfidence: (data['sentimentConfidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'rating': rating,
      'feedback': feedback,
      'platform': platform,
      'createdAt': FieldValue.serverTimestamp(), // Firestore Server Timestamp
      'processed': false, // Flag untuk diolah model AI nantinya
      'sentiment': sentiment,
      'sentimentConfidence': sentimentConfidence,
    };
  }
}   