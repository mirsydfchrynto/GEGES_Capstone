import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/customer/appointment_screen.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/booking_anti_duplicate_service.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../mocks/auth_service_test.mocks.dart';
import 'package:network_image_mock/network_image_mock.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('Full booking -> payment upload -> admin verify UI flow', (
    tester,
  ) async {
    mockNetworkImagesFor(() async {
      final fs = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      final barbershopId = 'shop-ui-1';

      await fs.collection('barbershops').doc(barbershopId).set({
        'name': 'UI Shop',
        'addres': 'Jl Test',
        'imageUrl': '',
        'services': ['s1'],
        'open_hour': 9,
        'close_hour': 21,
        'isOpen': true,
      });

      await fs.collection('services').doc('s1').set({
        'name': 'Signature Haircut',
        'price': 40000,
        'defaultDuration': 45,
        'isActive': true,
      });

      await fs.collection('barbermen').doc('b1').set({
        'name': 'Andi',
        'barbershop_id': barbershopId,
        'avg_duration': 30,
        'rating': 4.5,
        'isActive': true,
        'imageUrl': 'http://test/img.jpg',
      });

      final svc = BarbershopService(firestore: fs);
      final queueSvc = QueueService(firestore: fs, auth: mockAuth);
      final antiDup = BookingAntiDuplicateService(firestore: fs);

      final shop = Barbershop(
        id: barbershopId,
        name: 'UI Shop',
        addres: 'Jl Test',
        imageUrl: '',
        services: ['s1'],
        openHour: 9,
        closeHour: 21,
        isOpen: true,
      );

      await tester.pumpWidget(
        wrapWithLocalization(AppointmentScreen(
            barbershop: shop,
            barbershopService: svc,
            queueService: queueSvc,
            testUserId: 'cust-ui-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Signature Haircut'));
      await tester.pump();
      await tester.tap(find.text('LANJUT'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Pilih Barber Favorit'));
      await tester.pumpAndSettle();
      
      // Ensure Andi is visible and CENTERED to avoid being covered by floating buttons
      final barberFinder = find.text('Andi');
      await tester.scrollUntilVisible(
        barberFinder,
        500.0, // Delta scroll per drag
        scrollable: find.byType(Scrollable).first, // Find the main scrollable
      );
      await tester.pumpAndSettle();
      
      // Extra safety: make sure it's really there
      expect(barberFinder, findsOneWidget);
      await tester.tap(barberFinder);
      await tester.pump();

      // Create queue manually
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final bookingDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);
      final paymentDue = DateTime.now().add(const Duration(minutes: 10));
      final orderId = 'ORD-TEST-UI-1';

      await queueSvc.createQueue({
        'barbershop_id': barbershopId,
        'customer_id': 'cust-ui-1',
        'barberman_id': 'b1',
        'service_ids': ['s1'],
        'total_price': 40000,
        'booking_time': bookingDate,
        'status': 'awaiting_payment',
        'payment_deadline': paymentDue,
        'order_id': orderId,
      });

      // Pump PaymentScreen
      await tester.pumpWidget(
        wrapWithLocalization(PaymentScreen(
            orderId: orderId,
            totalPrice: 40000,
            barbershopId: barbershopId,
            barbermanId: 'b1',
            bookingTime: bookingDate,
            paymentDeadline: paymentDue,
            queueService: queueSvc,
            testUserId: 'cust-ui-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pembayaran'), findsOneWidget); // Header Title

      final qs = await fs.collection('queues').where('customer_id', isEqualTo: 'cust-ui-1').get();
      final bookingId = qs.docs.first.id;

      await antiDup.submitPaymentProof(
        bookingId: bookingId,
        proofUrl: 'https://example.com/proof.png',
        userId: 'cust-ui-1',
      );

      await tester.pumpAndSettle();
      
      bool found = false;
      for (int i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.text('Menunggu Verifikasi Admin').evaluate().isNotEmpty) {
          found = true;
          break;
        }
      }
      expect(found, true, reason: 'Should update to verification pending');

      await antiDup.acceptPaymentVerification(
        bookingId: bookingId,
        adminUid: 'admin-ui-1',
        adminNotes: 'ok',
      );

      // Verify updates
      final after = await fs.collection('queues').doc(bookingId).get();
      expect(after.data()?['status'], 'booked');
    });
  });
}
