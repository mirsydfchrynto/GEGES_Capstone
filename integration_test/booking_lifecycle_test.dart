import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integration: booking -> immediate pay -> admin confirm flow', (
    WidgetTester tester,
  ) async {
    final fakeFs = FakeFirebaseFirestore();
    final svc = QueueService(firestore: fakeFs);

    // 1) Customer creates a booking (status awaiting_payment for payment-first flow)
    final qRef = await fakeFs.collection('queues').add({
      'customer_id': 'cust_integ',
      'barbershop_id': 'shop_integ',
      'total_price': 50000,
      'status': 'awaiting_payment',
      'created_at': DateTime.now(),
    });

    // 2) Customer submits payment proof
    await svc.submitPaymentProofForQueue(
      queueId: qRef.id,
      userId: 'cust_integ',
      base64Proof: 'proofdata',
    );

    var after = await fakeFs.collection('queues').doc(qRef.id).get();
    var data = after.data()!;
    expect(data['payment_proof_base64'], 'proofdata');
    expect(data['payment_method'], 'bank_transfer');

    // 3) Admin confirms payment
    await svc.adminConfirmPayment(qRef.id, adminUid: 'admin_integ');

    final confirmed = await fakeFs.collection('queues').doc(qRef.id).get();
    final confirmedData = confirmed.data()!;
    expect(confirmedData['status'], 'booked');
    expect(confirmedData['payment_confirmed_by'], 'admin_integ');
    expect(confirmedData['booked_by'], 'admin_integ');
  });
}
