
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  group('Enterprise Performance & Stress Test', () {
    // 1. Setup Mocks
    final firestore = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth();
    
    // Inject fake dependencies to services
    final barbershopService = BarbershopService(firestore: firestore);
    final queueService = QueueService(firestore: firestore);

    test('STRESS TEST: Rapid Barbershop Data Mapping (100 docs)', () async {
      // 1. Setup 100 documents with large strings (simulating base64)
      for (int i = 0; i < 100; i++) {
        await firestore.collection('barbershops').doc('shop_$i').set({
          'name': 'Barbershop High Load $i',
          'address': 'Street Address Full Data $i',
          'imageUrl': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' * 100, // Simulated large string
          'isActive': true,
          'isOpen': true,
          'open_hour': 9,
          'close_hour': 21,
          'rating': 4.8,
        });
      }

      final stopwatch = Stopwatch()..start();
      
      // 2. Execute fetch
      final results = await barbershopService.getAllBarbershops(forceRefresh: true);
      
      stopwatch.stop();
      print('🚀 [PERF] Loaded and mapped 100 complex Barbershops in: ${stopwatch.elapsedMilliseconds}ms');
      
      expect(results.length, 100);
      expect(stopwatch.elapsedMilliseconds, lessThan(500), reason: 'Mapping 100 docs should be under 500ms');
    });

    test('STRESS TEST: Concurrent Booking Simulations (50 requests)', () async {
      // Setup a test shop and barber
      const shopId = 'test_shop';
      await firestore.collection('barbermen').add({
        'name': 'The Rock',
        'barbershop_id': shopId,
        'isActive': true,
        'monthlyHaircutCount': 0,
      });

      final stopwatch = Stopwatch()..start();

      // Simulate 50 people hitting the booking logic simultaneously
      final List<Future> bookings = [];
      for (int i = 0; i < 50; i++) {
        bookings.add(queueService.createQueue({
          'barbershop_id': shopId,
          'customer_id': 'user_$i',
          'booking_time': DateTime.now().add(const Duration(hours: 2)),
          'service_ids': ['cut'],
          'total_price': 50000,
        }));
      }

      await Future.wait(bookings);
      stopwatch.stop();

      print('🚀 [STRESS] Processed 50 concurrent booking requests in: ${stopwatch.elapsedMilliseconds}ms');
      
      final queueSnap = await firestore.collection('queues').get();
      expect(queueSnap.size, 50);
      expect(stopwatch.elapsedMilliseconds, lessThan(1000), reason: '50 concurrent logic ops should be under 1s');
    });
  });
}
