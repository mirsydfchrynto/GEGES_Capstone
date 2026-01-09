import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

void main() {
  group('TenantService', () {
    late FakeFirebaseFirestore fakeFs;
    late TenantService service;

    setUp(() {
      fakeFs = FakeFirebaseFirestore();
      service = TenantService(firestore: fakeFs);
    });

    test('createTenantApplication writes document and returns id', () async {
      final id = await service.createTenantApplication({
        'business_name': 'Toko Test',
        'owner_email': 'a@b.c',
      });

      expect(id, isNotNull);
      final doc = await fakeFs.collection('tenants').doc(id).get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['business_name'], 'Toko Test');
      expect(data['owner_email'], 'a@b.c');
      // Status defaults to draft unless specified (updated logic check)
      expect(data['status'], 'draft'); 
    });

    test('updateTenantApplication merges fields', () async {
      final id = await service.createTenantApplication({'business_name': 'B1'});
      await service.updateTenantApplication(id, {'status': 'pending_payment'});

      final doc = await fakeFs.collection('tenants').doc(id).get();
      expect(doc.data()!['status'], 'pending_payment');
    });

    test('getActiveRegistrationForOwner returns correct active tenant', () async {
      // 1. Create a cancelled/rejected tenant (should be ignored)
      await fakeFs.collection('tenants').add({
        'owner_uid': 'user1',
        'status': 'rejected',
        'business_name': 'Rejected Shop',
      });

      // 2. Create an active tenant (awaiting_payment)
      final activeRef = await fakeFs.collection('tenants').add({
        'owner_uid': 'user1',
        'status': 'awaiting_payment',
        'business_name': 'Active Shop',
        'document_base64': 'base64',
        'package_id': 'pkg1',
      });

      // 3. Query
      final result = await service.getActiveRegistrationForOwner('user1');

      expect(result, isNotNull);
      expect(result!.id, activeRef.id);
      expect(result.businessName, 'Active Shop');
    });

    test('cancelExpiredInvoices cancels only expired pending invoices', () async {
      final now = DateTime.now();
      final expired = Timestamp.fromDate(now.subtract(const Duration(hours: 2)));
      final future = Timestamp.fromDate(now.add(const Duration(hours: 2)));

      // 1. Expired + Waiting Proof (Should be cancelled)
      final t1 = await fakeFs.collection('tenants').add({
        'invoice': {
          'status': 'waiting_proof',
          'payment_deadline': expired,
        }
      });

      // 2. Not Expired + Waiting Proof (Should NOT be cancelled)
      final t2 = await fakeFs.collection('tenants').add({
        'invoice': {
          'status': 'waiting_proof',
          'payment_deadline': future,
        }
      });

      // 3. Expired + Already Paid/Active (Should NOT be cancelled)
      final t3 = await fakeFs.collection('tenants').add({
        'status': 'active', // Top level status overrides or logic check depends on invoice status
        'invoice': {
          'status': 'paid', // Status not in the target list
          'payment_deadline': expired,
        }
      });

      // 4. Run Cleanup
      final count = await service.cancelExpiredInvoices();

      // 5. Verify
      expect(count, 1, reason: 'Only t1 should be cancelled');

      final d1 = await t1.get();
      expect(d1.data()!['invoice']['status'], 'payment_timeout_cancelled');

      final d2 = await t2.get();
      expect(d2.data()!['invoice']['status'], 'waiting_proof');

      final d3 = await t3.get();
      expect(d3.data()!['invoice']['status'], 'paid');
    });
  });
}