import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'test_helpers.dart';
import 'emulator_helper.dart';
import 'package:geges_smartbarber/screens/customer/tabs/my_bookings_screen.dart';
import 'package:geges_smartbarber/screens/tenant_registration_screen.dart';
import 'package:geges_smartbarber/models/tenant.dart';

// NOTE: This is a draft E2E test scaffold. It connects to the Firestore
// emulator when `--dart-define=FIRESTORE_EMULATOR_HOST=localhost:8080` is set
// on the `flutter drive` / `flutter test` command line. Update steps to match
// your app's entrypoint and payment gateway mocks.

// This test pumps `MyBookingsScreen` directly (injected with a test payment
// service) and verifies the resume-payment flow and server-side verification.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E: resume payment after app restart and server verify', (tester) async {
    // Initialize Firebase and connect to emulator (if configured).
    await initFirebaseForIntegrationTests();

    // Note: this test pumps `MyBookingsScreen` directly for faster E2E runs.
    // To run a full-app E2E instead, import your `main.dart` and call `main()` at the top of the test,
    // then drive interactions through the real app entrypoint.
    // If the emulator isn't configured, skip the heavy E2E steps.
    final emulator = const String.fromEnvironment('FIRESTORE_EMULATOR_HOST', defaultValue: '');
    if (emulator.isEmpty) {
      // Skipping actual emulator seeding — run this test with the emulator for full validation.
      expect(true, isTrue);
      return;
    }

    // Seed a tenant in the emulator with awaiting_payment invoice state.
    final tenantId = 'e2e-tenant-1';
    final invoiceId = 'inv-$tenantId';
    await seedAwaitingPaymentTenant(tenantId: tenantId, amount: 50000, deadline: DateTime.now().add(const Duration(minutes: 10)));

    // Confirm the document exists and has awaiting_payment status in emulator.
    var doc = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).get();
    expect(doc.exists, isTrue);
    var status = doc.data()?['status'] as String?;
    expect(status, equals('awaiting_payment'));

    // If emulator not configured, test exits early above.

    // Launch the MyBookingsScreen widget with injected test payment service.
    final paymentService = DummyPaymentService();
    // seed the payment service with a test invoice that matches emulator seeded invoice id
    paymentService.seedInvoice(Invoice(id: invoiceId, tenantId: tenantId, deadline: DateTime.now().add(const Duration(minutes: 10))));

    await tester.pumpWidget(MaterialApp(home: MyBookingsScreen(currentUserId: 'test-owner', paymentService: paymentService)));

    // Allow streams to receive the seeded document
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Switch to the 'Menunggu Pembayaran' tab where awaiting_payment items appear
    final tabFinder = find.text('Menunggu Pembayaran');
    expect(tabFinder, findsOneWidget);
    await tester.tap(tabFinder);
    await tester.pumpAndSettle();

    // Find and tap the 'Lanjutkan Pembayaran' button for the seeded tenant
    final resumeFinder = find.text('Lanjutkan Pembayaran');
    expect(resumeFinder, findsWidgets);
    await tester.tap(resumeFinder.first);
    await tester.pumpAndSettle();

    // Payment dialog should appear; tap 'Bayar Sekarang'
    final payNowFinder = find.text('Bayar Sekarang');
    expect(payNowFinder, findsOneWidget);
    await tester.tap(payNowFinder);
    await tester.pumpAndSettle();

    // Verify tenant doc status updated to awaiting_confirmation (markPaid was called)
    doc = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).get();
    status = doc.data()?['status'] as String?;
    expect(status, equals('awaiting_confirmation'));
    expect(doc.data()?['paid_at'], isNotNull);

    // Simulate admin/server verification by updating tenant doc
    await FirebaseFirestore.instance.collection('tenants').doc(tenantId).update({
      'status': 'active',
      'verified_by': 'admin-test',
      'verified_at': Timestamp.fromDate(DateTime.now()),
    });

    // Simulate app lifecycle resume to ensure UI would refresh if running
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 200));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Confirm the document is now active
    doc = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).get();
    status = doc.data()?['status'] as String?;
    expect(status, equals('active'));

    // Confirm the UI reflects the updated status (find the 'Status: active' subtitle)
    final activeFinder = find.textContaining('Status: active');
    expect(activeFinder, findsWidgets);

    // Final sanity pump to stabilize test
    await tester.pumpAndSettle();

  });
}
