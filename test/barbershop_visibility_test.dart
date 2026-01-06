import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/models/barbershop.dart';

void main() {
  group('Barbershop Visibility (isActive) Tests', () {
    late FakeFirebaseFirestore fs;
    late BarbershopService service;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      service = BarbershopService(firestore: fs);

      // Seed Data
      // Shop 1: Active
      await fs.collection('barbershops').doc('shop_active').set({
        'name': 'Active Barber',
        'address': 'Jalan Hidup',
        'isActive': true,
        'isOpen': true,
        'services': ['Cut'],
      });

      // Shop 2: Inactive (Soft Deleted / Banned)
      await fs.collection('barbershops').doc('shop_inactive').set({
        'name': 'Inactive Barber',
        'address': 'Jalan Mati',
        'isActive': false, // This should hide it
        'isOpen': true,
        'services': ['Cut'],
      });
    });

    test('getAllBarbershops returns only active shops', () async {
      final shops = await service.getAllBarbershops(forceRefresh: true);
      
      expect(shops.length, 1);
      expect(shops.first.id, 'shop_active');
      expect(shops.any((s) => s.id == 'shop_inactive'), false);
    });

    test('searchBarbershops respects active status', () async {
      // Search for "Barber" (matches both names)
      final results = await service.searchBarbershops('Barber');
      
      expect(results.length, 1);
      expect(results.first.name, 'Active Barber');
    });

    test('setBarbershopActiveStatus updates visibility', () async {
      // Deactivate the active shop
      await service.setBarbershopActiveStatus('shop_active', false);
      
      final shopsAfterDeactivation = await service.getAllBarbershops(forceRefresh: true);
      expect(shopsAfterDeactivation.isEmpty, true);

      // Reactivate the inactive shop
      await service.setBarbershopActiveStatus('shop_inactive', true);
      
      final shopsAfterReactivation = await service.getAllBarbershops(forceRefresh: true);
      expect(shopsAfterReactivation.length, 1);
      expect(shopsAfterReactivation.first.id, 'shop_inactive');
    });
  });
}
