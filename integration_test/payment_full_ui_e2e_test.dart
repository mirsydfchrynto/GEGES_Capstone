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

import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


import 'package:mockito/mockito.dart';
import '../test/mocks/auth_service_mocks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Payment E2E with ImagePicker (full UI flow)', () {
    late FakeFirebaseFirestore fs;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    late BarbershopService svc;
    late QueueService queueSvc;
    late BookingAntiDuplicateService antiDup;
    late String barbershopId;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();

      // Stubbing Auth
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('cust-e2e-ui');

      svc = BarbershopService(firestore: fs);
      queueSvc = QueueService(firestore: fs, auth: mockAuth); // Inject Mock Auth
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
        'barber_selection_fee': 5000,
        'weeklyHolidays': [],
        'specificHolidays': [],
      });

      await fs.collection('services').doc('s1').set({
        'name': 'Signature Haircut',
        'price': 40000,
        'default_duration': 45,
      });

      await fs.collection('barbermen').doc('b1').set({
        'name': 'Andi',
        'barbershop_id': barbershopId,
        'monthly_haircut_count': 10,
        'avg_duration': 30,
        'rating': 4.5,
        'isActive': true,
        'onLeave': false,
        'offDays': [],
        'specificOffDays': [],
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
          barberSelectionFee: 5000,
          weeklyHolidays: [],
          specificHolidays: [],
        );

        // pump appointment screen with injected services & test user id
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'), // Force English for predictable text
            home: AppointmentScreen(
              barbershop: shop,
              barbershopService: svc,
              queueService: queueSvc,
              testUserId: 'cust-e2e-ui',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Select Service
        expect(find.text('Signature Haircut'), findsOneWidget);
        await tester.tap(find.text('Signature Haircut'));
        await tester.pumpAndSettle();

        // 2. Next to Barber
        await tester.tap(find.text('NEXT')); // l10n.btnNext
        await tester.pumpAndSettle();

        // 3. Select System Choice (Default)
        expect(find.text('System Choice (Fair & Fast)'), findsOneWidget); // l10n.barberChoiceSystem
        
        // 4. Next to Schedule
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();

        // 5. Select Time
        // Wait for busy slots to fetch
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Find a grid item (time slot)
        // The GridView is in Schedule Step. Tap the first valid slot.
        final timeSlot = find.descendant(of: find.byType(GridView), matching: find.byType(InkWell)).first;
        await tester.tap(timeSlot);
        await tester.pumpAndSettle();

        // 6. Book Now
        final bookBtn = find.text('BOOK NOW'); // l10n.btnBookNow
        expect(bookBtn, findsOneWidget);
        await tester.tap(bookBtn);
        await tester.pumpAndSettle();

        // 7. Confirm Dialog
        expect(find.text('Confirm Booking'), findsOneWidget); // Title
        await tester.tap(find.text('Book Now')); // l10n.btnConfirmBook (Dialog Action)
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
        final bookingId = qs.docs.first.id;
        final orderId = qs.docs.first.data()['order_id'] as String;

        // Verify we are on PaymentScreen with correct Order ID
        expect(find.text('#$orderId'), findsOneWidget);

        // Create a temporary file to act as an image
        final tmpDir = await Directory.systemTemp.createTemp('e2e_img_');
        final imgFile = File('${tmpDir.path}/proof.png');
        await imgFile.writeAsBytes(List<int>.generate(50, (i) => i % 256));

        // Re-Pump PaymentScreen with TestImagePicker because we can't inject it via Navigation easily.
        // This validates the specific PaymentScreen logic.
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: PaymentScreen(
              orderId: orderId,
              totalPrice: 40000,
              queueService: queueSvc,
              testUserId: 'cust-e2e-ui',
              imagePicker: TestImagePicker(imgFile.path),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 8. Tap Upload (Icon: add_a_photo_outlined)
        final uploadIcon = find.byIcon(Icons.add_a_photo_outlined);
        
        // Ensure visible
        await tester.scrollUntilVisible(
          uploadIcon,
          500.0,
          scrollable: find.byType(SingleChildScrollView),
        );
        await tester.pumpAndSettle();

        expect(uploadIcon, findsOneWidget);
        await tester.tap(uploadIcon);
        await tester.pumpAndSettle();

        // 9. Should see Checkmark (Icon: check_rounded) indicating selection
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        // 10. Submit Proof (ElevatedButton at bottom)
        final submitBtn = find.byType(ElevatedButton);
        expect(submitBtn, findsOneWidget);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // 11. Status should change to "Verification Pending"
        expect(find.text('Verification Pending'), findsOneWidget); // l10n.verificationPending

        // 12. Admin accepts the payment verification
        await antiDup.acceptPaymentVerification(
          bookingId: bookingId,
          adminUid: 'admin-e2e',
          adminNotes: 'Verified',
        );

        // Verify status updated in Firestore
        final after = await fs.collection('queues').doc(bookingId).get();
        expect(after.data()?['status'], 'booked');

        // 13. Start & finish Service
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
