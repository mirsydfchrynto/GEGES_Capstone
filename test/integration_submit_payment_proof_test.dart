import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

void main() {
  test(
    'submitPaymentProofForQueue updates payment fields atomically',
    () async {
      final fakeFs = FakeFirebaseFirestore();

      final docRef = await fakeFs.collection('queues').add({
        'customer_id': 'user123',
        'total_price': 45000,
        'status': 'awaiting_payment',
      });

      final svc = QueueService(firestore: fakeFs);

      await svc.submitPaymentProofForQueue(
        queueId: docRef.id,
        userId: 'user123',
        base64Proof: 'proof-blob-123',
      );

      final updated = await fakeFs.collection('queues').doc(docRef.id).get();
      final data = updated.data()!;

      expect(data['payment_proof_base64'], 'proof-blob-123');
      expect(data['payment_method'], 'bank_transfer');
      expect(data['payment_amount'], 45000);
      expect(data.containsKey('payment_submitted_at'), true);
    },
  );

  test('submitPaymentProofForQueue enforces ownership', () async {
    final fakeFs = FakeFirebaseFirestore();

    final docRef = await fakeFs.collection('queues').add({
      'customer_id': 'other_user',
      'total_price': 43000,
      'status': 'awaiting_payment',
    });

    final svc = QueueService(firestore: fakeFs);

    expect(
      svc.submitPaymentProofForQueue(
        queueId: docRef.id,
        userId: 'user123',
        base64Proof: 'x',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
