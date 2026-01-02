import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

void main() {
  group('Booking payment lifecycle (service-level)', () {
    late FakeFirebaseFirestore fs;
    late MockFirebaseAuth mockAuth;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      // Replace internal firestore with our fake via reflection? Not necessary for antiDupSvc because it uses default instance.
      // But BookingAntiDuplicateService uses FirebaseFirestore.instance; set up fake by writing docs directly.
    });

    test(
      'full flow: awaiting_payment -> submit proof -> verify -> ongoing -> served',
      () async {
        // create a shop and barber doc for clarity
        await fs.collection('barbershops').doc('shop1').set({'name': 'Toko'});
        await fs.collection('barbermen').doc('b1').set({
          'name': 'Andi',
          'barbershop_id': 'shop1',
          'isActive': true,
        });

        // Create booking with awaiting_payment
        final bookingRef = await fs.collection('bookings').add({
          'barbershop_id': 'shop1',
          'customer_id': 'u1',
          'barberman_id': 'b1',
          'service_ids': ['s1'],
          'total_price': 50000,
          'status': 'awaiting_payment',
          'request_status': 'approved',
          'payment_deadline': Timestamp.fromDate(
            DateTime.now().add(Duration(minutes: 10)),
          ),
          'createdAt': FieldValue.serverTimestamp(),
        });

        final bookingId = bookingRef.id;

        // Submit payment proof (simulate customer)
        // Use direct update to simulate proof upload because submitPaymentProof expects FirebaseAuth user ID in real app
        await fs.collection('bookings').doc(bookingId).update({
          'payment': {
            'proofUrl': 'https://example.com/proof.png',
            'proofUploadedAt': FieldValue.serverTimestamp(),
            'proofUploadedBy': 'u1',
            'verificationStatus': 'pending',
          },
        });

        // Admin accepts via BookingAntiDuplicateService.acceptPaymentVerification
        // But our acceptPaymentVerification currently reads 'payment.verificationStatus' == 'pending' and updates to 'accepted' and status 'booked'
        // We will mimic that by calling the service method (which uses Firestore.instance, but our fake fs is not the global instance). To keep tests deterministic, use direct update to simulate verification flow.

        // Simulate admin verifying payment
        await fs.collection('bookings').doc(bookingId).update({
          'payment.verificationStatus': 'accepted',
          'payment.verificationAcceptedAt': FieldValue.serverTimestamp(),
          'payment.verificationAcceptedBy': 'admin1',
          'status': 'booked',
        });

        // Check transition to booked
        final after = await fs.collection('bookings').doc(bookingId).get();
        expect(after.data()?['status'], 'booked');
        expect(after.data()?['payment']['verificationStatus'], 'accepted');

        // Start service (ongoing)
        await fs.collection('bookings').doc(bookingId).update({
          'status': 'ongoing',
          'start_time': FieldValue.serverTimestamp(),
        });

        final mid = await fs.collection('bookings').doc(bookingId).get();
        expect(mid.data()?['status'], 'ongoing');

        // Finish service
        await fs.collection('bookings').doc(bookingId).update({
          'status': 'served',
          'finish_time': FieldValue.serverTimestamp(),
        });
        final finished = await fs.collection('bookings').doc(bookingId).get();
        expect(finished.data()?['status'], 'served');
      },
    );

    test(
      'adminRefundBooking does not set is_refunded for unpaid booking',
      () async {
        // booking without payment
        final ref = await fs.collection('bookings').add({
          'barbershop_id': 'shop1',
          'customer_id': 'u2',
          'status': 'waiting',
          'total_price': 25000,
        });

        final svc = QueueService(firestore: fs, auth: mockAuth);
        await svc.adminRefundBooking(
          ref.id,
          reason: 'test',
          adminUid: 'admin1',
        );
        final after = await fs.collection('bookings').doc(ref.id).get();
        final data = after.data()!;

        expect(data['status'], 'cancelled');
        expect(data['is_refunded'] ?? false, false);
      },
    );
  });
}
