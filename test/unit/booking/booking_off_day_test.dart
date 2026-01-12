import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../../helpers/manual_mocks.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:intl/intl.dart';

void main() {
  late QueueService queueService;
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(signedIn: true);
    queueService = QueueService(firestore: firestore, auth: auth);
  });

  test('QueueService.createQueue should reject booking on weekly off day', () async {
    // 1. Setup Data
    final shopId = 'shop_1';
    final barberId = 'barber_1';
    final userId = 'user_1';

    // Barber libur setiap SENIN (Monday)
    await firestore.collection('barbermen').doc(barberId).set({
      'barbershop_id': shopId,
      'name': 'Barber Santuy',
      'isActive': true,
      'offDays': ['monday'], // Lowercase match logic
      'specificOffDays': [],
      'onLeave': false,
    });

    await firestore.collection('barbershops').doc(shopId).set({
      'name': 'Test Shop',
      'open_hour': 9,
      'close_hour': 21,
      'isActive': true,
    });

    // 2. Tentukan tanggal hari Senin depan (pastikan di masa depan)
    DateTime targetDate = DateTime.now().add(const Duration(days: 1));
    while (DateFormat('EEEE').format(targetDate) != 'Monday') {
      targetDate = targetDate.add(const Duration(days: 1));
    }
    // Set jam 10 pagi
    targetDate = DateTime(targetDate.year, targetDate.month, targetDate.day, 10, 0);

    // 3. Coba Booking
    final payload = {
      'barbershop_id': shopId,
      'barberman_id': barberId,
      'customer_id': userId,
      'service_ids': ['s1'],
      'booking_time': targetDate,
      'estimated_duration': 30,
    };

    // 4. Expect Exception
    expect(
      () => queueService.createQueue(payload),
      throwsA(predicate((e) => e.toString().contains('Tidak ada barberman yang tersedia pada hari ini'))),
    );
  });

  test('QueueService.createQueue should reject booking on specific off day', () async {
    // 1. Setup Barbershop (Open 09-21)
    await firestore.collection('barbershops').doc('shop_1').set({
      'open_hour': 9,
      'close_hour': 21,
      'isActive': true,
    });

    // 2. Setup Barberman with a specific off day
    final specificDate = '2026-01-15'; // Specific Thursday
    await firestore.collection('barbermen').doc('barber_1').set({
      'barbershop_id': 'shop_1',
      'isActive': true,
      'onLeave': false,
      'offDays': [],
      'specificOffDays': [specificDate],
    });

    final payload = {
      'barbershop_id': 'shop_1',
      'barberman_id': 'barber_1',
      'booking_time': DateTime(2026, 1, 15, 10, 0), // Same as specificDate
      'estimated_duration': 30,
    };

    expect(
      () => queueService.createQueue(payload),
      throwsA(predicate((e) => e.toString().contains('Tidak ada barberman yang tersedia pada hari ini'))),
    );
  });

  test('QueueService.isSlotAvailable should return false on off day', () async {
    final shopId = 'shop_1';
    final barberId = 'barber_1';
    
    await firestore.collection('barbermen').doc(barberId).set({
      'isActive': true,
      'offDays': ['sunday'],
      'onLeave': false,
    });

    // Cari hari Minggu
    DateTime sunday = DateTime.now();
    while (DateFormat('EEEE').format(sunday) != 'Sunday') {
      sunday = sunday.add(const Duration(days: 1));
    }
    sunday = DateTime(sunday.year, sunday.month, sunday.day, 10, 0);

    final isAvailable = await queueService.isSlotAvailable(
      barbershopId: shopId,
      barbermanId: barberId,
      bookingTime: sunday,
      serviceIds: [],
    );

    expect(isAvailable, false);
  });
}