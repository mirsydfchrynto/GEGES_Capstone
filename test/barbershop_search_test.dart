import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

void main() {
  group('BarbershopService Search Logic', () {
    late FakeFirebaseFirestore firestore;
    late BarbershopService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = BarbershopService(firestore: firestore);

      // Seed data
      await firestore.collection('barbershops').doc('shop1').set({
        'name': 'Geges Barber',
        'addres': 'Jalan Mawar',
        'isOpen': true,
        'services': ['Haircut'],
        'rating': 4.5,
      });
      
      await firestore.collection('barbershops').doc('shop2').set({
        'name': 'Luxury Cuts',
        'addres': 'Jalan Melati',
        'isOpen': true,
        'services': ['Shave'],
        'rating': 5.0,
      });

      await firestore.collection('barbershops').doc('shop3').set({
        'name': 'Closed Barber',
        'addres': 'Jalan Anggrek',
        'isOpen': false, // Should not appear
        'services': ['Haircut'],
        'rating': 4.0,
      });
    });

    test('Empty query returns all active shops', () async {
      final results = await service.searchBarbershops('');
      expect(results.length, 2);
      expect(results.any((s) => s.id == 'shop3'), isFalse);
    });

    test('Search by name (case-insensitive)', () async {
      final results = await service.searchBarbershops('geges');
      expect(results.length, 1);
      expect(results.first.name, 'Geges Barber');
    });

    test('Search by address (substring)', () async {
      final results = await service.searchBarbershops('melati');
      expect(results.length, 1);
      expect(results.first.name, 'Luxury Cuts');
    });

    test('Search non-existent returns empty', () async {
      final results = await service.searchBarbershops('Unknown');
      expect(results.isEmpty, isTrue);
    });
  });
}
