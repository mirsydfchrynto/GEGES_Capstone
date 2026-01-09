import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

class FakeEmailOutbox {
  bool queued = false;
  Map<String, dynamic>? lastArgs;

  Future<void> queueEmail({
    required String to,
    required String subject,
    required String body,
    Map<String, dynamic>? metadata,
  }) async {
    queued = true;
    lastArgs = {
      'to': to,
      'subject': subject,
      'body': body,
      'metadata': metadata,
    };
  }
}

void main() {
  test(
    'verifyTenant creates notification and queues email when owner info present (approve)',
    () async {
      final fs = FakeFirebaseFirestore();
      final fakeOutbox = FakeEmailOutbox();
      final service = TenantService(
        firestore: fs,
        emailOutboxService: fakeOutbox,
      );

      // prepare tenant doc
      final tenantRef = fs.collection('tenants').doc('t-approve');
      await tenantRef.set({
        'status': 'pending_review',
        'owner_uid': 'owner123',
        'owner_email': 'owner@example.com',
        'business_name': 'Toko Foo',
      });

      await service.verifyTenant(
        tenantId: 't-approve',
        approve: true,
        verifiedBy: 'admin1',
      );

      final tdoc = await tenantRef.get();
      expect(tdoc.data()!['status'], 'active');

      // notification added
      final notifs = await fs
          .collection('notifications')
          .where('user_id', isEqualTo: 'owner123')
          .get();
      expect(notifs.docs.length, 1);
      final notif = notifs.docs.first.data();
      expect(notif['title'], contains('Disetujui'));

      // email queued
      expect(fakeOutbox.queued, isTrue);
      expect(fakeOutbox.lastArgs!['to'], 'owner@example.com');
      final subjectLower = (fakeOutbox.lastArgs!['subject'] as String)
          .toLowerCase();
      expect(
        subjectLower.contains('approved') || subjectLower.contains('disetujui'),
        isTrue,
      );
    },
  );

  test(
    'verifyTenant creates notification and queues email when owner info present (reject)',
    () async {
      final fs = FakeFirebaseFirestore();
      final fakeOutbox = FakeEmailOutbox();
      final service = TenantService(
        firestore: fs,
        emailOutboxService: fakeOutbox,
      );

      // prepare tenant doc
      final tenantRef = fs.collection('tenants').doc('t-reject');
      await tenantRef.set({
        'status': 'pending_review',
        'owner_uid': 'owner456',
        'owner_email': 'owner2@example.com',
        'business_name': 'Toko Bar',
      });

      await service.verifyTenant(
        tenantId: 't-reject',
        approve: false,
        verifiedBy: 'admin2',
        reason: 'invalid docs',
      );

      final tdoc = await tenantRef.get();
      expect(tdoc.data()!['status'], 'rejected');

      final notifs = await fs
          .collection('notifications')
          .where('user_id', isEqualTo: 'owner456')
          .get();
      expect(notifs.docs.length, 1);
      final notif = notifs.docs.first.data();
      final title = (notif['title'] as String).toLowerCase();
      expect(title.contains('ditolak') || title.contains('rejected'), isTrue);

      // email queued
      expect(fakeOutbox.queued, isTrue);
      expect(fakeOutbox.lastArgs!['to'], 'owner2@example.com');
      final subjLower = (fakeOutbox.lastArgs!['subject'] as String)
          .toLowerCase();
      expect(
        subjLower.contains('rejected') || subjLower.contains('ditolak'),
        isTrue,
      );
    },
  );
}
