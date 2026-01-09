import 'dart:convert';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/models/app_rating.dart';
import 'package:geges_smartbarber/services/rating_service.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'smart_rating_logic_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockClient mockClient;
  late RatingService ratingService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockClient = MockClient();
    ratingService = RatingService(
      firestore: fakeFirestore,
      client: mockClient,
    );
  });

  group('Smart Rating Service Logic', () {
    final validRating = AppRating(
      id: 'r1',
      userId: 'user1',
      userName: 'User One',
      userEmail: 'u1@test.com',
      rating: 5.0,
      feedback: 'Pelayanan sangat ramah dan tempat nyaman.',
      platform: 'android',
      createdAt: DateTime.now(),
    );

    test('1. Should SAVE rating to Firestore if sentiment is POSITIF', () async {
      // ARRANGE
      final apiResponse = {
        "prediction": "positif",
        "confidence": 0.98,
      };
      
      when(mockClient.post(
        any, 
        headers: anyNamed('headers'), 
        body: anyNamed('body')
      )).thenAnswer((_) async => http.Response(jsonEncode(apiResponse), 200));

      // ACT
      await ratingService.submitRating(validRating);

      // ASSERT
      final snapshot = await fakeFirestore.collection('app_ratings').get();
      expect(snapshot.docs.length, 1, reason: 'Should save 1 document');
      
      final data = snapshot.docs.first.data();
      expect(data['sentiment'], 'positif');
      expect(data['sentimentConfidence'], 0.98);
      expect(data['feedback'], validRating.feedback);
    });

    test('2. Should SAVE rating to Firestore if sentiment is NEGATIF', () async {
      // ARRANGE
      final negRating = AppRating(
        id: 'r2',
        userId: 'user2',
        userName: 'User Two',
        userEmail: 'u2@test.com',
        rating: 1.0,
        feedback: 'Antrian lama dan panas.',
        platform: 'ios',
        createdAt: DateTime.now(),
      );

      final apiResponse = {
        "prediction": "negatif",
        "confidence": 0.85,
      };
      
      when(mockClient.post(
        any, 
        headers: anyNamed('headers'), 
        body: anyNamed('body')
      )).thenAnswer((_) async => http.Response(jsonEncode(apiResponse), 200));

      // ACT
      await ratingService.submitRating(negRating);

      // ASSERT
      final snapshot = await fakeFirestore.collection('app_ratings').get();
      expect(snapshot.docs.length, 1);
      final data = snapshot.docs.first.data();
      expect(data['sentiment'], 'negatif');
      expect(data['feedback'], 'Antrian lama dan panas.');
    });

    test('3. Should DISCARD rating (not save) if sentiment is NEUTRAL/IRRELEVANT', () async {
      // ARRANGE
      final neutralRating = AppRating(
        id: 'r3',
        userId: 'user3',
        userName: 'User Three',
        userEmail: 'u3@test.com',
        rating: 3.0,
        feedback: 'Biasa saja.',
        platform: 'android',
        createdAt: DateTime.now(),
      );

      final apiResponse = {
        "prediction": "netral", // Bukan positif/negatif
        "confidence": 0.50,
      };
      
      when(mockClient.post(
        any, 
        headers: anyNamed('headers'), 
        body: anyNamed('body')
      )).thenAnswer((_) async => http.Response(jsonEncode(apiResponse), 200));

      // ACT
      await ratingService.submitRating(neutralRating);

      // ASSERT
      final snapshot = await fakeFirestore.collection('app_ratings').get();
      expect(snapshot.docs.length, 0, reason: 'Should discard neutral ratings');
    });

    test('4. Should THROW error if API fails', () async {
      // ARRANGE
      when(mockClient.post(
        any, 
        headers: anyNamed('headers'), 
        body: anyNamed('body')
      )).thenAnswer((_) async => http.Response('Server Error', 500));

      // ACT & ASSERT
      expect(
        () async => await ratingService.submitRating(validRating), 
        throwsA(isA<Exception>())
      );
    });
  });
}
