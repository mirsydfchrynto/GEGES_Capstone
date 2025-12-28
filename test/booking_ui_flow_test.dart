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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('Full booking -> payment upload -> admin verify UI flow', (
    tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    final barbershopId = 'shop-ui-1';

    // create shop, service and barber
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
      'default_duration': 45,
    });

    await fs.collection('barbermen').doc('b1').set({
      'name': 'Andi',
      'barbershop_id': barbershopId,
      'avg_duration': 30,
      'rating': 4.5,
      'isActive': true,
    });

    final svc = BarbershopService(firestore: fs);
    final queueSvc = QueueService(firestore: fs);
    final antiDup = BookingAntiDuplicateService(firestore: fs);

    final shop = Barbershop(
      id: barbershopId,
      name: 'UI Shop',
      addres: 'Jl Test',
      rating: 5.0,
      imageUrl: '',
      services: ['s1'],
      openHour: 9,
      closeHour: 21,
      isOpen: true,
    );

    // Pump AppointmentScreen with injected services and test user id
    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentScreen(
          barbershop: shop,
          barbershopService: svc,
          queueService: queueSvc,
          testUserId: 'cust-ui-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // select service
    expect(find.text('Signature Haircut'), findsOneWidget);
    await tester.ensureVisible(find.text('Signature Haircut'));
    await tester.tap(find.text('Signature Haircut'));
    await tester.pumpAndSettle();

    // ensure a barber is visible and select barber (default selection may set it automatically)
    expect(find.text('Andi'), findsOneWidget);
    // Ensure visible then tap barber tile to trigger selection dialog; choose default (not paid)
    await tester.ensureVisible(find.text('Andi'));
    await tester.tap(find.text('Andi'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Default'), findsOneWidget);
    await tester.tap(find.text('Pilih Default'));
    await tester.pumpAndSettle();

    // For deterministic testing, create the queue directly instead of going through the BOOK NOW UI flow.
    // Use a fixed booking time inside the shop's open hours (10:00 next day) to avoid time-dependent failures.
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
      'barber_selection_fee': 0,
      'paid_barber_selection': false,
      'estimated_duration': 45,
      'booking_time': bookingDate,
      'status': 'awaiting_payment',
      'payment_deadline': paymentDue,
      'order_id': orderId,
    });

    // Simulate navigation to PaymentScreen (customer would be navigated here)
    await tester.pumpWidget(
      MaterialApp(
        home: PaymentScreen(
          orderId: orderId,
          totalPrice: 40000,
          barbershopId: barbershopId,
          barbermanId: 'b1',
          bookingTime: bookingDate,
          paymentDeadline: paymentDue,
          queueService: queueSvc, // use fake firestore
          testUserId: 'cust-ui-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Payment screen should be shown
    expect(find.text('Payment'), findsOneWidget);

    // Resolve created queue for customer
    final qs = await fs
        .collection('queues')
        .where('customer_id', isEqualTo: 'cust-ui-1')
        .limit(1)
        .get();
    expect(qs.docs.isNotEmpty, true);
    final bookingId = qs.docs.first.id;

    // Simulate customer uploading proof via anti-dup service
    await antiDup.submitPaymentProof(
      bookingId: bookingId,
      proofUrl: 'https://example.com/proof.png',
      userId: 'cust-ui-1',
    );

    // Verify the queue doc was updated with payment.proofUrl
    final afterDoc = await fs.collection('queues').doc(bookingId).get();
    expect(
      (afterDoc.data()?['payment'] as Map<String, dynamic>?)?['proofUrl'],
      'https://example.com/proof.png',
    );

    // Wait for PaymentScreen's stream listener to observe the change and update UI
    // Poll the widget tree for a reasonable duration to avoid flakiness
    await tester.pumpAndSettle();
    bool found = false;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.text('Bukti Terunggah').evaluate().isNotEmpty) {
        found = true;
        break;
      }
    }
    expect(
      found,
      true,
      reason:
          'PaymentScreen should show uploaded proof label after external submission',
    );

    // Admin accepts verification
    await antiDup.acceptPaymentVerification(
      bookingId: bookingId,
      adminUid: 'admin-ui-1',
      adminNotes: 'ok',
    );

    final after = await fs.collection('queues').doc(bookingId).get();
    expect(after.data()?['status'], 'booked');

    // Start and finish service via queueSvc
    await queueSvc.startService(bookingId);
    final mid = await fs.collection('queues').doc(bookingId).get();
    expect(mid.data()?['status'], 'ongoing');

    await queueSvc.finishService(bookingId);
    final fin = await fs.collection('queues').doc(bookingId).get();
    expect(fin.data()?['status'], 'served');
  });
}
