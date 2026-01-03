import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/models/app_rating.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitRating(AppRating rating) async {
    try {
      await _firestore.collection('app_ratings').add(rating.toJson());
    } catch (e) {
      rethrow;
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
