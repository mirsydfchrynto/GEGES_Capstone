import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/booking_anti_duplicate_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Payment upload & verification integration', () {
    late FakeFirebaseFirestore fs;
    late BookingAntiDuplicateService antiDup;
    late QueueService queueSvc;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      antiDup = BookingAntiDuplicateService(firestore: fs);
      queueSvc = QueueService(firestore: fs);
    });

    test(
      'submitPaymentProof -> acceptPaymentVerification -> start/finish service',
      () async {
        // create booking
        final bookingRef = await fs.collection('bookings').add({
          'barbershop_id': 'shop1',
          'customer_id': 'c1',
          'barberman_id': 'b1',
          'service_ids': ['s1'],
          'total_price': 40000,
          'status': 'awaiting_payment',
          'request_status': 'approved',
          'createdAt': FieldValue.serverTimestamp(),
        });

        final bookingId = bookingRef.id;

        // submit payment proof
        await antiDup.submitPaymentProof(
          bookingId: bookingId,
          proofUrl: 'https://example.com/proof.png',
          userId: 'c1',
        );

        final afterProof = await fs.collection('bookings').doc(bookingId).get();
        final payment =
            (afterProof.data()?['payment'] ?? {}) as Map<String, dynamic>;

        expect(payment['proofUrl'], isNotNull);
        expect(payment['verificationStatus'], 'pending');

        // accept payment verification
        await antiDup.acceptPaymentVerification(
          bookingId: bookingId,
          adminUid: 'admin1',
          adminNotes: 'ok',
        );

        final afterAccept = await fs
            .collection('bookings')
            .doc(bookingId)
            .get();
        final data = afterAccept.data()!;

        expect(
          (data['payment'] as Map<String, dynamic>)['verificationStatus'],
          'accepted',
        );
        expect(data['status'], 'booked');

        // start service
        await queueSvc.startService(bookingId);
        final mid = await fs.collection('bookings').doc(bookingId).get();
        expect(mid.data()?['status'], 'ongoing');

        // finish service
        await queueSvc.finishService(bookingId);
        final finished = await fs.collection('bookings').doc(bookingId).get();
        expect(finished.data()?['status'], 'served');
      },
    );
  });
}
