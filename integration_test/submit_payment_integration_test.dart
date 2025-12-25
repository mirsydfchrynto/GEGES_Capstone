import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'integration: submitPaymentProofForQueue (transactional) - passes on device',
    (WidgetTester tester) async {
      final fakeFs = FakeFirebaseFirestore();
      final docRef = await fakeFs.collection('queues').add({
        'customer_id': 'integration_user',
        'total_price': 72000,
        'status': 'awaiting_payment',
      });

      final svc = QueueService(firestore: fakeFs);

      await svc.submitPaymentProofForQueue(
        queueId: docRef.id,
        userId: 'integration_user',
        base64Proof: 'proof-integ',
      );

      final updated = await fakeFs.collection('queues').doc(docRef.id).get();
      final data = updated.data()!;

      expect(data['payment_proof_base64'], 'proof-integ');
      expect(data['payment_method'], 'bank_transfer');
      expect(data['payment_amount'], 72000);
    },
  );
}
