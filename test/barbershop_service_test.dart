import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('BarbershopService.pickDefaultBarber', () {
    late FakeFirebaseFirestore fs;
    late BarbershopService svc;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      svc = BarbershopService(firestore: fs);

      // create two barbermen
      await fs.collection('barbermen').doc('b1').set({
        'name': 'Andi',
        'barbershop_id': 'shop1',
        'avg_duration': 30,
        'rating': 4.5,
        'isActive': true,
        'onLeave': false,
      });

      await fs.collection('barbermen').doc('b2').set({
        'name': 'Budi',
        'barbershop_id': 'shop1',
        'avg_duration': 30,
        'rating': 4.5,
        'isActive': true,
        'onLeave': false,
      });
    });

    test('picks barber without bookings in next hour', () async {
      final now = DateTime.now();
      final bookingTime = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute + 10,
      );

      // create a conflicting booking for b2 within next hour
      await fs.collection('queues').add({
        'barberman_id': 'b2',
        'booking_time': Timestamp.fromDate(
          bookingTime.add(const Duration(minutes: 20)),
        ),
        'status': 'booked',
        'barbershop_id': 'shop1',
      });

      final chosen = await svc.pickDefaultBarber(
        'shop1',
        bookingTime,
        lookaheadMinutes: 60,
      );

      expect(chosen, isNotNull);
      expect(chosen!.id, 'b1');
    });

    test('returns null when none free', () async {
      final now = DateTime.now();
      final bookingTime = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute + 10,
      );

      // create conflicting bookings for both barbers
      await fs.collection('queues').add({
        'barberman_id': 'b1',
        'booking_time': Timestamp.fromDate(
          bookingTime.add(const Duration(minutes: 5)),
        ),
        'status': 'booked',
        'barbershop_id': 'shop1',
      });

      await fs.collection('queues').add({
        'barberman_id': 'b2',
        'booking_time': Timestamp.fromDate(
          bookingTime.add(const Duration(minutes: 15)),
        ),
        'status': 'booked',
        'barbershop_id': 'shop1',
      });

      // Add an extra booking for b2 to make b1 the best choice
      await fs.collection('queues').add({
        'barberman_id': 'b2',
        'booking_time': Timestamp.fromDate(
          bookingTime.add(const Duration(hours: 2)),
        ),
        'status': 'booked',
        'barbershop_id': 'shop1',
      });

      final chosen = await svc.pickDefaultBarber(
        'shop1',
        bookingTime,
        lookaheadMinutes: 60,
      );

      expect(chosen, isNull);
    });
  });
}
