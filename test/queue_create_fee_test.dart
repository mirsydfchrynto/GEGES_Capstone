import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  group('QueueService.createQueue with barber fee', () {
    late FakeFirebaseFirestore fs;
    late MockFirebaseAuth mockAuth;
    late QueueService svc;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      svc = QueueService(firestore: fs, auth: mockAuth);
    });

    test('stores barber_selection_fee and paid flag', () async {
      final payload = {
        'barbershop_id': 'shop1',
        'customer_id': 'u1',
        'barberman_id': 'b1',
        'service_ids': ['s1'],
        'total_price': 55000,
        'barber_selection_fee': 5000,
        'paid_barber_selection': true,
        'booking_time': Timestamp.fromDate(
          DateTime(
            DateTime.now().add(const Duration(days: 1)).year,
            DateTime.now().add(const Duration(days: 1)).month,
            DateTime.now().add(const Duration(days: 1)).day,
            11,
            0,
          ),
        ),
      };

      final ref = await svc.createQueue(payload);

      final doc = await ref.get();
      final data = doc.data()!;

      expect(data['barber_selection_fee'], 5000);
      expect(data['paid_barber_selection'], true);
      expect(data['total_price'], 55000);
    });
  });
}
