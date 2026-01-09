import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import '../../mocks/auth_service_test.mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Multi-Barber Capacity Logic', () {
    late FakeFirebaseFirestore fs;
    late MockFirebaseAuth auth;
    late QueueService svc;
    const shopId = 'shop_capacity_test';

    setUp(() async {
      fs = FakeFirebaseFirestore();
      auth = MockFirebaseAuth();
      svc = QueueService(firestore: fs, auth: auth);

      // Setup 3 Barbers (A, B, C)
      // Barber A & B active, C is on leave (Capacity = 2)
      await fs.collection('barbermen').add({
        'barbershop_id': shopId,
        'name': 'Barber A',
        'isActive': true,
        'onLeave': false,
        'offDays': [],
      });
      await fs.collection('barbermen').add({
        'barbershop_id': shopId,
        'name': 'Barber B',
        'isActive': true,
        'onLeave': false,
        'offDays': [],
      });
      await fs.collection('barbermen').add({
        'barbershop_id': shopId,
        'name': 'Barber C',
        'isActive': true,
        'onLeave': true, // Cuti
        'offDays': [],
      });
    });

    test('Slot remains open if load < capacity', () async {
      final date = DateTime.now();
      final bookingTime = DateTime(date.year, date.month, date.day, 12, 0);

      // 1 Booking at 12:00
      await fs.collection('queues').add({
        'barbershop_id': shopId,
        'booking_time': Timestamp.fromDate(bookingTime),
        'status': 'booked',
        'estimated_duration': 30,
      });

      // Capacity = 2 (A, B). Load = 1.
      // Expect: 12:00 NOT in busy slots
      final busy = await svc.getShopBusySlots(barbershopId: shopId, date: date);
      
      // Check if any range covers 12:00
      final isBlocked = busy.any((range) => 
        range.start.hour == 12 && range.start.minute == 0
      );

      expect(isBlocked, false, reason: 'Slot 12:00 should be open (1/2 filled)');
    });

    test('Slot closes if load == capacity', () async {
      final date = DateTime.now();
      final bookingTime = DateTime(date.year, date.month, date.day, 14, 0);

      // 2 Bookings at 14:00 (Full Capacity)
      await fs.collection('queues').add({
        'barbershop_id': shopId,
        'booking_time': Timestamp.fromDate(bookingTime),
        'status': 'booked',
        'estimated_duration': 30,
      });
      await fs.collection('queues').add({
        'barbershop_id': shopId,
        'booking_time': Timestamp.fromDate(bookingTime),
        'status': 'booked',
        'estimated_duration': 30,
      });

      // Capacity = 2. Load = 2.
      // Expect: 14:00 IN busy slots
      final busy = await svc.getShopBusySlots(barbershopId: shopId, date: date);
      
      final isBlocked = busy.any((range) => 
        range.start.hour == 14 && range.start.minute == 0
      );

      expect(isBlocked, true, reason: 'Slot 14:00 should be blocked (2/2 filled)');
    });
  });
}
