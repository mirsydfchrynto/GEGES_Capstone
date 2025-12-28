import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

void main() {
  test('verifyTenant sets status to active when approved', () async {
    final fs = FakeFirebaseFirestore();
    final service = TenantService(firestore: fs);

    final tenantRef = fs.collection('tenants').doc('t1');
    await tenantRef.set({'status': 'pending_payment'});

    await service.verifyTenant(
      tenantId: 't1',
      approve: true,
      verifiedBy: 'admin1',
    );

    final doc = await tenantRef.get();
    expect(doc.data()!['status'], 'active');
    expect(doc.data()!['verified_by'], 'admin1');
    expect(doc.data()!['verified_at'], isA<Timestamp>());
  });

  test('verifyTenant sets status to rejected when not approved', () async {
    final fs = FakeFirebaseFirestore();
    final service = TenantService(firestore: fs);

    final tenantRef = fs.collection('tenants').doc('t2');
    await tenantRef.set({'status': 'pending_payment'});

    await service.verifyTenant(
      tenantId: 't2',
      approve: false,
      verifiedBy: 'admin2',
      reason: 'invalid docs',
    );

    final doc = await tenantRef.get();
    expect(doc.data()!['status'], 'rejected');
    expect(doc.data()!['verified_by'], 'admin2');
    expect(doc.data()!['rejection_reason'], 'invalid docs');
  });
}
