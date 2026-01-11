import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

class MockAuth extends Mock implements FirebaseAuth {}

void main() {
  late FakeFirebaseFirestore fs;
  late QueueService queueSvc;
  late MockAuth mockAuth;
  const barbershopId = 'shop_1';

  setUp(() async {
    fs = FakeFirebaseFirestore();
    mockAuth = MockAuth();
    queueSvc = QueueService(firestore: fs, auth: mockAuth);

    // Setup Barbershop
    await fs.collection('barbershops').doc(barbershopId).set({
      'name': 'Test Shop',
      'open_hour': 9,
      'close_hour': 21,
      'isOpen': true,
      'isActive': true,
    });

    // Setup 3 Barbers
    for (int i = 1; i <= 3; i++) {
      await fs.collection('barbermen').doc('b$i').set({
        'name': 'Barber $i',
        'barbershop_id': barbershopId,
        'isActive': true,
        'onLeave': false,
        'offDays': [],
        'specificOffDays': [],
      });
    }
  });

  test('Should reject 4th booking when only 3 barbermen are available for the same slot', () async {
    final bookingTime = DateTime.now().add(const Duration(days: 1));
    final tomorrow = DateTime(bookingTime.year, bookingTime.month, bookingTime.day, 10, 0);

    // 1. Create 3 successful bookings for the same slot
    for (int i = 1; i <= 3; i++) {
      await queueSvc.createQueue({
        'barbershop_id': barbershopId,
        'customer_id': 'cust_$i',
        'barberman_id': 'b$i',
        'service_ids': ['s1'],
        'booking_time': tomorrow,
        'status': 'booked',
      });
    }

    // 2. Attempt the 4th booking (this should fail)
    expect(
      () => queueSvc.createQueue({
        'barbershop_id': barbershopId,
        'customer_id': 'cust_4',
        'barberman_id': 'b1', // Try to assign to b1 or use random
        'service_ids': ['s1'],
        'booking_time': tomorrow,
        'status': 'booked',
      }),
      throwsA(predicate((e) => e.toString().contains('semua slot barberman sudah penuh'))),
    );
  });
}
