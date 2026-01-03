import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/models/queue.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth mockAuth;
  late QueueService queueService;
  late Barbershop testShop;
  late Barberman barber1;
  late Service service1;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    queueService = QueueService(firestore: firestore, auth: mockAuth);

    // 1. Setup Barbershop (9 AM - 9 PM)
    testShop = Barbershop(
      id: 'shop_1',
      name: 'Geges Test Shop',
      addres: 'Jl. Test No. 1',
      rating: 5.0,
      imageUrl: '',
      services: ['svc_1'],
      openHour: 9,
      closeHour: 21,
      isOpen: true,
      barberSelectionFee: 10000,
    );
    // Explicitly set open_hour and close_hour for QueueService validation
    await firestore.collection('barbershops').doc(testShop.id).set({
      ...testShop.toJson(),
      'open_hour': 9,
      'close_hour': 21,
    });

    // 2. Setup Barberman
    barber1 = Barberman(
      id: 'barber_1',
      name: 'Agus Professional',
      barbershopId: 'shop_1',
      isActive: true,
      onLeave: false,
      monthlyHaircutCount: 5,
      avgDuration: 30.0,
      rating: 5.0,
    );
    await firestore.collection('barbermen').doc(barber1.id).set(barber1.toJson());

    // 3. Setup Service
    service1 = Service(
      id: 'svc_1',
      name: 'Haircut',
      description: 'Standard',
      price: 50000,
      defaultDuration: 30,
      isActive: true,
    );
    await firestore.collection('services').doc(service1.id).set(service1.toJson());
  });

  group('Admin Manual Booking Logic (Same as Customer Rules)', () {
    
    test('Manual Booking with Specific Barber adds selection fee', () async {
      // Use tomorrow 10:00 AM (Within 9-21 range)
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final bookingTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);
      
      final payload = {
        'barbershop_id': testShop.id,
        'barberman_id': barber1.id,
        'service_ids': [service1.id],
        'booking_time': Timestamp.fromDate(bookingTime),
        'status': 'booked',
        'paid_barber_selection': true,
        'total_price': service1.price.toInt() + testShop.barberSelectionFee,
        'estimated_duration': 30,
        'customer_id': 'WALKIN_123',
      };

      await queueService.createQueue(payload);

      final snapshot = await firestore.collection('queues').get();
      final createdQueue = Queue.fromFirestore(snapshot.docs.first);

      expect(createdQueue.totalPrice, 60000);
      expect(createdQueue.status, QueueStatus.booked);
    });

    test('Prevents Manual Booking if slot overlaps with existing customer booking', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final bookingTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0);
      
      // 1. Create an existing booking
      await firestore.collection('queues').add({
        'barbershop_id': testShop.id,
        'barberman_id': barber1.id,
        'booking_time': Timestamp.fromDate(bookingTime),
        'status': 'booked',
        'estimated_duration': 30,
      });

      // 2. Try to create a manual booking at the same time
      final isAvailable = await queueService.isSlotAvailable(
        barbershopId: testShop.id,
        barbermanId: barber1.id,
        bookingTime: bookingTime,
        serviceIds: [service1.id],
      );

      expect(isAvailable, false);
    });

    test('Respects Barbershop Opening Hours for Manual Booking', () async {
      // 07:00 AM (Outside 9-21 range)
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final earlyTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 7, 0);
      
      final payload = {
        'barbershop_id': testShop.id,
        'barberman_id': barber1.id,
        'service_ids': [service1.id],
        'booking_time': Timestamp.fromDate(earlyTime),
        'status': 'booked',
        'estimated_duration': 30,
      };

      expect(() => queueService.createQueue(payload), throwsException);
    });

    test('Fairness Algorithm: Picks least busy barber count', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final bookingTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11, 0);

      // Add another barber who is LESS busy
      final barber2 = Barberman(
        id: 'barber_2',
        name: 'Budi Newbie',
        barbershopId: 'shop_1',
        isActive: true,
        onLeave: false,
        monthlyHaircutCount: 0, // Less than Agus (5)
        avgDuration: 30.0,
        rating: 5.0,
      );
      await firestore.collection('barbermen').doc(barber2.id).set(barber2.toJson());

      final fairBarberId = await queueService.getFairAvailableBarberman(
        barbershopId: testShop.id,
        bookingTime: bookingTime,
        serviceIds: [service1.id],
      );

      expect(fairBarberId, 'barber_2');
    });
  });
}