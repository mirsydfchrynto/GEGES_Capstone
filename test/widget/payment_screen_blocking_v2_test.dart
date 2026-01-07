import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import '../test_helpers.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFs;
  late QueueService queueSvc;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    fakeFs = FakeFirebaseFirestore();
    queueSvc = QueueService(firestore: fakeFs, auth: mockAuth);
  });

  testWidgets('Back button pops PaymentScreen in new implementation', (tester) async {
    await tester.pumpWidget(wrapWithLocalization(Scaffold(
        body: PaymentScreen(
          queueService: queueSvc,
          orderId: 'tenant-1',
          totalPrice: 100000,
          tenantId: 'tenant-1',
          tenantPaymentHandler: ({required String tenantId, required String base64, required String userId}) async {
          },
          submitProofHandler: () async {
          },
          cancelTenantHandler: ({required String tenantId, required String userId, String? reason}) async {},
          disableTimer: true,
          testUserId: 'user-1',
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Verify Initial UI
    expect(find.text('Kirim Bukti Pembayaran'), findsOneWidget);

    // Tap Close Button
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Dialog appears because tenantId is not null
    expect(find.text('Pendaftaran Belum Selesai'), findsOneWidget);
    
    // Tap 'Keluar (Simpan Draft)'
    await tester.tap(find.text('Keluar (Simpan Draft)'));
    await tester.pumpAndSettle();

    // Verify Popped (Text should be gone)
    expect(find.text('Kirim Bukti Pembayaran'), findsNothing);
  });

  testWidgets('Cancel button pops and calls handler', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(wrapWithLocalization(Scaffold(
        body: PaymentScreen(
          queueService: queueSvc,
          orderId: 'tenant-2',
          totalPrice: 120000,
          tenantId: 'tenant-2',
          tenantPaymentHandler: ({required String tenantId, required String base64, required String userId}) async {},
          cancelTenantHandler: ({required String tenantId, required String userId, String? reason}) async {
            cancelled = true;
          },
          disableTimer: true,
          testUserId: 'user-2',
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Tap Cancel
    final cancelFinder = find.text('Batalkan Pendaftaran');
    await tester.ensureVisible(cancelFinder);
    await tester.tap(cancelFinder);
    await tester.pumpAndSettle();

    // Verify Handler Called
    expect(cancelled, isTrue);
    // Verify Popped
    expect(find.text('Batalkan Pendaftaran'), findsNothing);
  });
}
