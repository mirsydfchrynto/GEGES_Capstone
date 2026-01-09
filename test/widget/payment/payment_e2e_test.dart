import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';
import 'package:geges_smartbarber/services/booking_anti_duplicate_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import '../../mocks/auth_service_test.mocks.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('Payment UI + service interactions (integration-like)', () {
    late FakeFirebaseFirestore fs;
    late MockFirebaseAuth mockAuth;
    late BookingAntiDuplicateService antiDup;
    late QueueService queueSvc;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      antiDup = BookingAntiDuplicateService(firestore: fs);
      queueSvc = QueueService(firestore: fs, auth: mockAuth);

      // create a queue (awaiting_payment)
      final orderId = 'ORD-e2e-1';
      await fs.collection('queues').add({
        'barbershop_id': 'shop-e2e',
        'customer_id': 'cust-e2e',
        'barberman_id': 'bm-e2e',
        'service_ids': ['s-e2e'],
        'total_price': 45000,
        'status': 'awaiting_payment',
        'request_status': 'approved',
        'payment_deadline': DateTime.now().add(const Duration(minutes: 10)),
        'order_id': orderId,
      });
    });

    testWidgets(
      'Payment screen detects uploaded proof and admin verifies -> service lifecycle',
      (tester) async {
        final orderId = 'ORD-e2e-1';

        // Submit payment proof using anti-dup service (simulates customer upload)
        final qsnap = await fs
            .collection('queues')
            .where('order_id', isEqualTo: orderId)
            .limit(1)
            .get();
        final bookingId = qsnap.docs.first.id;

        await antiDup.submitPaymentProof(
          bookingId: bookingId,
          proofUrl: 'https://example.com/proof.png',
          userId: 'cust-e2e',
        );

        // Pump PaymentScreen which should detect the uploaded proof
        await tester.pumpWidget(
          wrapWithLocalization(PaymentScreen(
              orderId: orderId,
              totalPrice: 45000,
              queueService: queueSvc,
              testUserId: 'cust-e2e',
            ),
          ),
        );
        
        // Wait for stream
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500)); 

        // The submit button should indicate proof uploaded (disabled state shows 'Menunggu Verifikasi Admin')
        expect(find.text('Menunggu Verifikasi Admin'), findsOneWidget);

        // Admin accepts the payment verification
        await antiDup.acceptPaymentVerification(
          bookingId: bookingId,
          adminUid: 'admin-e2e',
          adminNotes: 'Verified',
        );

        // Verify the document updated to booked
        final after = await fs.collection('queues').doc(bookingId).get();
        expect(after.data()?['status'], 'booked');
        expect(
          (after.data()?['payment'] ?? {})['verificationStatus'],
          'accepted',
        );

        // Start service
        await queueSvc.startService(bookingId);
        final mid = await fs.collection('queues').doc(bookingId).get();
        expect(mid.data()?['status'], 'ongoing');

        // Finish service
        await queueSvc.finishService(bookingId);
        final finished = await fs.collection('queues').doc(bookingId).get();
        expect(finished.data()?['status'], 'served');
      },
    );
  });
}
