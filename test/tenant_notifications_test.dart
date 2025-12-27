import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

class FakeEmailOutbox {
  bool queued = false;
  String? to;
  String? subject;
  String? body;
  Map<String, dynamic>? metadata;

  Future<void> queueEmail({required String to, required String subject, required String body, Map<String, dynamic>? metadata}) async {
    queued = true;
    this.to = to;
    this.subject = subject;
    this.body = body;
    this.metadata = metadata;
  }
}

void main() {
  test('verifyTenant queues notification and email', () async {
    final fs = FakeFirebaseFirestore();
    final tenantId = 't-notify';

    await fs.collection('tenants').doc(tenantId).set({
      'owner_uid': 'u1',
      'owner_email': 'owner@example.com',
      'business_name': 'Test Shop',
      'status': 'pending_payment',
    });

    final fakeEmail = FakeEmailOutbox();

    final service = TenantService(firestore: fs, storage: null, emailOutboxService: fakeEmail);

    await service.verifyTenant(tenantId: tenantId, approve: true, verifiedBy: 'admin1');

    final tenant = await fs.collection('tenants').doc(tenantId).get();
    expect(tenant.data()!['status'], 'active');

    final notifs = await fs.collection('notifications').where('user_id', isEqualTo: 'u1').get();
    expect(notifs.docs, isNotEmpty);

    expect(fakeEmail.queued, isTrue);
    expect(fakeEmail.to, 'owner@example.com');
  });
}
