

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  testWidgets('Auto-detects pending registration and offers resume', (
    WidgetTester tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    final tenantRef = fs.collection('tenants').doc('existing-id');
    await tenantRef.set({
      'owner_uid': 'user-1',
      'status': 'pending_payment',
      'invoice': {'amount': 300000, 'payment_deadline': Timestamp.now()},
      'created_at': Timestamp.now(),
    });

    final fakeService = TenantService(firestore: fs, storage: null);

    await tester.pumpWidget(
      wrapWithLocalization(TenantRegistrationScreen(
          tenantService: fakeService,
          currentUserId: 'user-1',
          initialAcceptedTerms: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Expect the Resume Dialog
    expect(find.text('Lanjutkan Pendaftaran?'), findsOneWidget);
    expect(find.text('Anda memiliki pendaftaran yang belum selesai (menunggu pembayaran). Ingin melanjutkannya?'), findsOneWidget);

    // Tap 'Lanjutkan Bayar'
    await tester.tap(find.text('Lanjutkan Bayar'));
    await tester.pumpAndSettle();

    // Should be navigated to PaymentScreen (upload button visible)
    final uploadButton = find.widgetWithText(
      ElevatedButton,
      'Kirim Konfirmasi',
    );
    expect(uploadButton, findsOneWidget);
  });
}
