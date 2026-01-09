import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'mocks/auth_service_test.mocks.dart'; // Import MockFirebaseAuth

void main() {
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth();
  });

  test(
    'resolve returns queue when doc id exists and owned by customer',
    () async {
      final fakeFs = FakeFirebaseFirestore();

      await fakeFs.collection('queues').doc('q-doc-1').set({
        'customer_id': 'user123',
        'total_price': 30000,
      });

      final svc = QueueService(firestore: fakeFs, auth: mockAuth);
      final q = await svc.resolveQueueForCustomerByIdOrOrder(
        'q-doc-1',
        'user123',
      );

      expect(q, isNotNull);
      expect(q!.id, 'q-doc-1');
      expect(q.customerId, 'user123');
    },
  );

  test('resolve falls back to order_id query when doc id missing', () async {
    final fakeFs = FakeFirebaseFirestore();

    final added = await fakeFs.collection('queues').add({
      'customer_id': 'user123',
      'total_price': 35000,
      'order_id': 'ORD-1',
    });

      final svc = QueueService(firestore: fakeFs, auth: mockAuth);
    final q = await svc.resolveQueueForCustomerByIdOrOrder('ORD-1', 'user123');

    expect(q, isNotNull);
    expect(q!.id, added.id);
    expect(q.customerId, 'user123');
    expect(q.totalPrice, 35000);
  });

  test(
    'resolve returns null when doc exists but not owned by customer',
    () async {
      final fakeFs = FakeFirebaseFirestore();

      await fakeFs.collection('queues').doc('q-doc-2').set({
        'customer_id': 'other',
        'total_price': 25000,
      });

        final svc = QueueService(firestore: fakeFs, auth: mockAuth);
      final q = await svc.resolveQueueForCustomerByIdOrOrder(
        'q-doc-2',
        'user123',
      );

      expect(q, isNull);
    },
  );
}
