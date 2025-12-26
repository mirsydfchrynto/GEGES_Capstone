import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

void main() {
  group('TenantService', () {
    test('createTenantApplication writes document and returns id', () async {
      final fakeFs = FakeFirebaseFirestore();
      final service = TenantService(firestore: fakeFs);

      final id = await service.createTenantApplication({'business_name': 'Toko Test', 'owner_email': 'a@b.c'});

      expect(id, isNotNull);
      final doc = await fakeFs.collection('tenants').doc(id).get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['business_name'], 'Toko Test');
      expect(data['owner_email'], 'a@b.c');
      expect(data['status'], 'draft');
    });

    test('updateTenantApplication merges fields', () async {
      final fakeFs = FakeFirebaseFirestore();
      final service = TenantService(firestore: fakeFs);
      final id = await service.createTenantApplication({'business_name': 'B1'});

      await service.updateTenantApplication(id, {'status': 'pending_payment'});

      final doc = await fakeFs.collection('tenants').doc(id).get();
      expect(doc.data()!['status'], 'pending_payment');
    });
  });
}
