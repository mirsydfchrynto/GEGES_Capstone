import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import '../../mocks/auth_service_test.mocks.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth mockAuth;
  late QueueService queueService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    queueService = QueueService(firestore: firestore, auth: mockAuth);
  });

  test('Fairness Algorithm picks barber with fewer monthly haircuts', () async {
    const String shopId = 'shop123';
    final DateTime bookingTime = DateTime(2025, 5, 20, 10, 0);

    // 1. Seed Barbers
    await firestore.collection('barbermen').doc('barber_A').set({
      'barbershop_id': shopId,
      'isActive': true,
      'onLeave': false,
      'monthly_haircut_count': 10,
      'name': 'Barber A',
    });

    await firestore.collection('barbermen').doc('barber_B').set({
      'barbershop_id': shopId,
      'isActive': true,
      'onLeave': false,
      'monthly_haircut_count': 2, // Fewer haircuts
      'name': 'Barber B',
    });

    // 2. Run Algorithm
    final selectedId = await queueService.getFairAvailableBarberman(
      barbershopId: shopId,
      bookingTime: bookingTime,
      serviceIds: ['service1'],
    );

    // 3. Verify
    expect(selectedId, equals('barber_B'), reason: 'Should pick Barber B who has less work this month');
  });

  test('Fairness Algorithm respects barber holidays', () async {
    const String shopId = 'shop123';
    final DateTime bookingTime = DateTime(2025, 5, 20, 10, 0); // This is a Tuesday

    // barber_A is free but Tuesday is his OFF day
    await firestore.collection('barbermen').doc('barber_A').set({
      'barbershop_id': shopId,
      'isActive': true,
      'onLeave': false,
      'monthly_haircut_count': 0,
      'offDays': ['tuesday'], 
      'name': 'Barber A',
    });

    // barber_B is free and has no holiday
    await firestore.collection('barbermen').doc('barber_B').set({
      'barbershop_id': shopId,
      'isActive': true,
      'onLeave': false,
      'monthly_haircut_count': 10,
      'name': 'Barber B',
    });

    final selectedId = await queueService.getFairAvailableBarberman(
      barbershopId: shopId,
      bookingTime: bookingTime,
      serviceIds: ['service1'],
    );

    expect(selectedId, equals('barber_B'), reason: 'Should pick Barber B because A is on holiday');
  });
}
