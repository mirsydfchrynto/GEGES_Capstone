import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/models/barbershop.dart';

void main() {
  group('BarbershopService - Favorite Logic Tests', () {
    late FakeFirebaseFirestore firestore;
    late BarbershopService service;
    const String userId = 'user_test_123';
    const String shopId = 'shop_test_456';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = BarbershopService(firestore: firestore);
    });

    test('toggleFavorite adds a shop to favorites if not present', () async {
      // 1. Initial State: Empty users collection
      
      // 2. Action
      await service.toggleFavorite(userId, shopId);

      // 3. Verify
      final doc = await firestore.collection('users').doc(userId).get();
      final favorites = List<String>.from(doc.data()?['favorite_barbershops'] ?? []);
      
      expect(favorites, contains(shopId));
      expect(favorites.length, 1);
    });

    test('toggleFavorite removes a shop from favorites if already present', () async {
      // 1. Setup existing favorite
      await firestore.collection('users').doc(userId).set({
        'favorite_barbershops': [shopId],
      });

      // 2. Action
      await service.toggleFavorite(userId, shopId);

      // 3. Verify
      final doc = await firestore.collection('users').doc(userId).get();
      final favorites = List<String>.from(doc.data()?['favorite_barbershops'] ?? []);
      
      expect(favorites, isNot(contains(shopId)));
      expect(favorites.isEmpty, true);
    });

    test('isFavorite returns correct status', () async {
      await firestore.collection('users').doc(userId).set({
        'favorite_barbershops': [shopId],
      });

      final fav = await service.isFavorite(userId, shopId);
      final notFav = await service.isFavorite(userId, 'other_shop');

      expect(fav, isTrue);
      expect(notFav, isFalse);
    });

    test('getFavoriteBarbershops retrieves full Barbershop objects', () async {
      // 1. Seed Barbershop data
      await firestore.collection('barbershops').doc(shopId).set({
        'name': 'Geges Test Shop',
        'addres': 'Street 1',
        'imageUrl': 'img.jpg',
        'rating': 4.5,
        'open_hour': 9,
        'close_hour': 21,
        'isOpen': true,
        'services': ['s1'],
      });

      // 2. Seed User Favorite
      await firestore.collection('users').doc(userId).set({
        'favorite_barbershops': [shopId],
      });

      // 3. Action
      final results = await service.getFavoriteBarbershops(userId);

      // 4. Verify
      expect(results.length, 1);
      expect(results.first.id, shopId);
      expect(results.first.name, 'Geges Test Shop');
    });
  });
}
