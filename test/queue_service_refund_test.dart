import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

void main() {
  group('QueueService.adminRefundBooking', () {
    late FakeFirebaseFirestore fs;
    late QueueService svc;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      svc = QueueService(firestore: fs);
    });

    test('cancels without marking refund when no payment exists', () async {
      final doc = await fs.collection('queues').add({
        'barbershop_id': 'shop1',
        'customer_id': 'u1',
        'status': 'booked',
        'total_price': 50000,
      });

      await svc.adminRefundBooking(
        doc.id,
        reason: 'Test cancel',
        adminUid: 'admin1',
      );

      final updated = await fs.collection('queues').doc(doc.id).get();
      final data = updated.data()!;

      expect(data['status'], 'cancelled');
      expect(data['is_refunded'] ?? false, false);
      expect(data['cancelled_by_uid'], 'admin1');
    });

    test('marks refund when payment proof exists', () async {
      final doc = await fs.collection('queues').add({
        'barbershop_id': 'shop1',
        'customer_id': 'u1',
        'status': 'booked',
        'total_price': 50000,
        'payment_proof_base64': 'AAA',
      });

      await svc.adminRefundBooking(
        doc.id,
        reason: 'Refund test',
        adminUid: 'admin2',
      );

      final updated = await fs.collection('queues').doc(doc.id).get();
      final data = updated.data()!;

      expect(data['status'], 'cancelled');
      expect(data['is_refunded'], true);
      expect(data['refunded_by'], 'admin2');
      expect(data.containsKey('payment_proof_base64'), false);
    });
  });
}
