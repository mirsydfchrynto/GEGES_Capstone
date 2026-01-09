import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import '../../mocks/auth_service_test.mocks.dart';

void main() {
  group('QueueService Payment Window & Create (FakeFirestore)', () {
    late FakeFirebaseFirestore fs;
    late MockFirebaseAuth auth;
    late QueueService svc;
    const shopId = 'shop_test';

    setUp(() async {
      fs = FakeFirebaseFirestore();
      auth = MockFirebaseAuth();
      svc = QueueService(firestore: fs, auth: auth);

      // Setup Barbershop
      await fs.collection('barbershops').doc(shopId).set({
        'name': 'Test Shop',
        'open_hour': 9,
        'close_hour': 21,
        'payment_window_minutes': 15,
      });

      // Setup Barber
      await fs.collection('barbermen').add({
        'barbershop_id': shopId,
        'name': 'Barber 1',
        'isActive': true,
        'onLeave': false,
        'offDays': [],
      });
    });

    test('getPaymentWindowForBarbershop returns value from doc', () async {
      final window = await svc.getPaymentWindowForBarbershop(shopId);
      expect(window, 15);
    });

    test('getPaymentWindowForBarbershop returns default for missing doc', () async {
      final window = await svc.getPaymentWindowForBarbershop('non_existent');
      expect(window, QueueService.defaultPaymentWindowMinutes);
    });

    test('createQueue sets payment_deadline using shop window', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final bookingTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 12, 0);

      final payload = {
        'barbershop_id': shopId,
        'customer_id': 'user123',
        'booking_time': Timestamp.fromDate(bookingTime),
        'status': 'waiting',
      };

      final ref = await svc.createQueue(payload);
      final doc = await ref.get();
      final data = doc.data()!;

      expect(data['payment_deadline'], isNotNull);
      final deadline = (data['payment_deadline'] as Timestamp).toDate();
      final now = DateTime.now();
      
      // Should be roughly now + 15 minutes
      final diff = deadline.difference(now).inMinutes;
      expect(diff, inInclusiveRange(14, 16));
    });

    test('createQueue respects opening hours', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final lateTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 0); // 11 PM (Closed)

      final payload = {
        'barbershop_id': shopId,
        'customer_id': 'user123',
        'booking_time': Timestamp.fromDate(lateTime),
        'status': 'waiting',
      };

      expect(() => svc.createQueue(payload), throwsException);
    });

    test('adminConfirmRequest updates deadline based on shop window', () async {
      final bookingRef = await fs.collection('queues').add({
        'barbershop_id': shopId,
        'customer_id': 'c1',
        'status': 'waiting',
        'booking_time': Timestamp.now(),
      });

      await svc.adminConfirmRequest(bookingRef.id, adminUid: 'admin1');

      final updated = await bookingRef.get();
      final data = updated.data()!;

      expect(data['status'], 'awaiting_payment');
      expect(data['payment_deadline'], isNotNull);
      
      final deadline = (data['payment_deadline'] as Timestamp).toDate();
      final diff = deadline.difference(DateTime.now()).inMinutes;
      expect(diff, inInclusiveRange(14, 16));
    });
  });
}