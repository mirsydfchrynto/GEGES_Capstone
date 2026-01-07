import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/customer/appointment_screen.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/booking_anti_duplicate_service.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Payment E2E with ImagePicker (full UI flow)', () {
    late FakeFirebaseFirestore fs;
    late BarbershopService svc;
    late QueueService queueSvc;
    late BookingAntiDuplicateService antiDup;
    late String barbershopId;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      svc = BarbershopService(firestore: fs);
      queueSvc = QueueService(firestore: fs);
      antiDup = BookingAntiDuplicateService(firestore: fs);
      barbershopId = 'shop-e2e-ui-img';

      // create shop, service and barber
      await fs.collection('barbershops').doc(barbershopId).set({
        'name': 'E2E Shop',
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
    });

    testWidgets(
      'Book -> upload image via ImagePicker -> admin verify -> finish',
      (tester) async {
        // Build the shop model used by the AppointmentScreen
        final shop = Barbershop(
          id: barbershopId,
          name: 'E2E Shop',
          addres: 'Jl Test',
          imageUrl: '',
          services: ['s1'],
          openHour: 9,
          closeHour: 21,
          isOpen: true,
        );

        // pump appointment screen with injected services & test user id
        await tester.pumpWidget(
          MaterialApp(
            home: AppointmentScreen(
              barbershop: shop,
              barbershopService: svc,
              queueService: queueSvc,
              testUserId: 'cust-e2e-ui',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // select service and barber
        expect(find.text('Signature Haircut'), findsOneWidget);
        await tester.tap(find.text('Signature Haircut'));
        await tester.pumpAndSettle();

        expect(find.text('Andi'), findsOneWidget);
        await tester.tap(find.text('Andi'));
        await tester.pumpAndSettle();
        expect(find.text('Pilih Default'), findsOneWidget);
        await tester.tap(find.text('Pilih Default'));
        await tester.pumpAndSettle();

        // short delay for availability check
        await tester.pump(const Duration(milliseconds: 500));

        // tap BOOK NOW
        final bookBtn = find.text('BOOK NOW');
        expect(bookBtn, findsOneWidget);
        await tester.tap(bookBtn);
        await tester.pumpAndSettle();

        // Should navigate to PaymentScreen
        expect(find.text('Payment'), findsOneWidget);

        // Resolve created queue for customer
        final qs = await fs
            .collection('queues')
            .where('customer_id', isEqualTo: 'cust-e2e-ui')
            .limit(1)
            .get();
        expect(qs.docs.isNotEmpty, true);
        final orderId = qs.docs.first.data()['order_id'] as String;
        final bookingId = qs.docs.first.id;

        // Create a temporary file to act as an image
        final tmpDir = await Directory.systemTemp.createTemp('e2e_img_');
        final imgFile = File('${tmpDir.path}/proof.png');
        await imgFile.writeAsBytes(List<int>.generate(50, (i) => i % 256));

        // Pump PaymentScreen directly but inject TestImagePicker
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentScreen(
              orderId: orderId,
              totalPrice: 45000,
              queueService: queueSvc,
              testUserId: 'cust-e2e-ui',
              imagePicker: TestImagePicker(imgFile.path),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // tap upload area (gesture area)
        expect(find.byIcon(Icons.upload_file_outlined), findsOneWidget);
        await tester.tap(find.byIcon(Icons.upload_file_outlined));
        await tester.pumpAndSettle();

        // bottom sheet should be visible with Photo Gallery option
        expect(find.text('Photo Gallery'), findsOneWidget);
        await tester.tap(find.text('Photo Gallery'));
        await tester.pumpAndSettle();

        // after pick, preview should be visible (Preview button enabled)
        expect(find.text('Preview'), findsOneWidget);

        // submit proof
        final submitBtn = find.text('Submit Proof & Create Queue');
        expect(submitBtn, findsOneWidget);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // The submit button should indicate proof uploaded
        expect(find.text('Bukti Terunggah'), findsOneWidget);

        // Admin accepts the payment verification
        await antiDup.acceptPaymentVerification(
          bookingId: bookingId,
          adminUid: 'admin-e2e',
          adminNotes: 'Verified',
        );

        // Verify status updated
        final after = await fs.collection('queues').doc(bookingId).get();
        expect(after.data()?['status'], 'booked');

        // Start & finish
        await queueSvc.startService(bookingId);
        final mid = await fs.collection('queues').doc(bookingId).get();
        expect(mid.data()?['status'], 'ongoing');

        await queueSvc.finishService(bookingId);
        final fin = await fs.collection('queues').doc(bookingId).get();
        expect(fin.data()?['status'], 'served');

        // cleanup
        await imgFile.delete();
        await tmpDir.delete();
      },
    );
  });
}

class TestImagePicker extends ImagePicker {
  final String path;
  TestImagePicker(this.path);

  @override
  Future<XFile?> pickImage({
    int? imageQuality,
    double? maxHeight,
    double? maxWidth,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = false,
    required ImageSource source,
  }) async {
    return XFile(path);
  }
}
