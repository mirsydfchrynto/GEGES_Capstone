
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../../mocks/auth_service_test.mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Refund Logic Tests', () {
    late FakeFirebaseFirestore fakeFs;
    late MockFirebaseAuth mockAuth;
    late QueueService service;
    const String queueId = 'queue_refund_test';
    const String userId = 'user_refund_test';

    setUp(() async {
      fakeFs = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      service = QueueService(firestore: fakeFs, auth: mockAuth);

      // Create initial booked queue
      await fakeFs.collection('queues').doc(queueId).set({
        'customer_id': userId,
        'status': 'booked',
        'total_price': 100000,
        'payment_proof_base64': 'proof_base64',
        'created_at': Timestamp.now(),
      });
    });

    test('Customer requests cancellation (refund logic)', () async {
      await service.customerRequestCancellation(
        queueId,
        reason: 'Changed mind',
        customerId: userId,
      );

      final doc = await fakeFs.collection('queues').doc(queueId).get();
      final data = doc.data()!;

      expect(data['status'], 'cancellation_requested');
      expect(data['cancellation_reason'], 'Changed mind');
      expect(data['refund_amount'], 90000); // 90% of 100000
      expect(data['refund_deduction'], 10000); // 10% deduction
    });

    test('Admin processes refund', () async {
      // First, move to cancellation_requested
      await fakeFs.collection('queues').doc(queueId).update({
        'status': 'cancellation_requested',
        'refund_amount': 90000,
      });

      await service.adminProcessRefund(
        queueId,
        refundProofBase64: 'refund_transfer_proof',
        adminUid: 'admin_1',
        adminNotes: 'Refunded via bank transfer',
      );

      final doc = await fakeFs.collection('queues').doc(queueId).get();
      final data = doc.data()!;

      // Expect refund_completed
      expect(data['status'], 'refund_completed');
      expect(data['refund_proof_base64'], 'refund_transfer_proof');
      expect(data['is_refunded'], true);
      expect(data['admin_refund_notes'], 'Refunded via bank transfer');
    });

    test('Customer cancels awaiting_payment with proof (should calculate refund)', () async {
      const qId = 'queue_awaiting_proof';
      await fakeFs.collection('queues').doc(qId).set({
        'customer_id': userId,
        'status': 'awaiting_payment',
        'total_price': 50000,
        'payment_proof_base64': 'proof_exists', // Proof uploaded!
      });

      await service.customerRequestCancellation(
        qId,
        reason: 'Mistake',
        customerId: userId,
      );

      final doc = await fakeFs.collection('queues').doc(qId).get();
      final data = doc.data()!;

      expect(data['status'], 'cancellation_requested');
      expect(data['refund_amount'], 45000); // 90% of 50000
    });

    test('Customer fails to cancel awaiting_payment WITHOUT proof', () async {
      const qId = 'queue_no_proof';
      await fakeFs.collection('queues').doc(qId).set({
        'customer_id': userId,
        'status': 'awaiting_payment',
        'total_price': 50000,
        'payment_proof_base64': null, // No proof
      });

      expect(
        () async => await service.customerRequestCancellation(
          qId,
          reason: 'Mistake',
          customerId: userId,
        ),
        throwsException, // Should throw because status is invalid for refund request
      );
    });
  });
}
