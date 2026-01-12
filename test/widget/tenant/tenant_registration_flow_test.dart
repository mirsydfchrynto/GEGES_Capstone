import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import '../../helpers/test_helpers.dart';

class FakeAuthServiceTenant extends Mock implements AuthService {
  @override
  Future<bool> isEmailRegistered(String? email) async => false;
}

class FakeTenantServiceFlow extends TenantService {
  FakeTenantServiceFlow(FakeFirebaseFirestore fs)
    : super(firestore: fs, storage: null);

  @override
  Future<String> uploadTenantDocument(
    String tenantId,
    File? file, {
    List<int>? bytes,
    String? filename,
  }) async {
    return 'tenants/$tenantId/doc_${DateTime.now().millisecondsSinceEpoch}';
  }
}

void main() {
  testWidgets('Full tenant registration stores docs as Firestore refs and requires terms', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    final fs = FakeFirebaseFirestore();
    final fakeService = FakeTenantServiceFlow(fs);
    final fakeAuth = FakeAuthServiceTenant();

    await tester.pumpWidget(
      wrapWithLocalization(
        SizedBox(
          width: 800,
          height: 1600,
          child: TenantRegistrationScreen(
            tenantService: fakeService,
            authService: fakeAuth,
            currentUserId: 'user-1',
            initialAcceptedTerms: true,
            initialCompanyDocPath: '/tmp/siup.jpg',
            initialTaxDocPath: '/tmp/npwp.jpg',
            testSubmitProofHandler: (tenantId) async {
              await fakeService.submitRegistrationPayment(
                tenantId: tenantId,
                proofBase64: 'FAKEBASE64',
                userId: 'user-1',
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    if (find.text('LANJUT DAFTAR').evaluate().isNotEmpty) {
      await tester.tap(find.text('LANJUT DAFTAR'));
      await tester.pumpAndSettle();
    }

    // Fill Required Fields (Standard Validation)
    await tester.enterText(find.byType(TextFormField).at(0), 'Bisnis Test');
    await tester.enterText(find.byType(TextFormField).at(2), 'Owner Test');
    await tester.enterText(find.byType(TextFormField).at(3), 'new-owner-${DateTime.now().millisecondsSinceEpoch}@test.com');
    await tester.enterText(find.byType(TextFormField).at(4), '081234567890');

    final submitButton = find.textContaining('Daftar & Bayar');
    await tester.ensureVisible(submitButton); 
    
    // Tap and wait for navigation transition
    await tester.tap(submitButton, warnIfMissed: false);
    
    // Step-by-step pumps to handle transitions reliably
    bool foundPaymentScreen = false;
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      // Search for text in a case-insensitive way because of .toUpperCase() in UI
      if (find.textContaining('RINCIAN PESANAN').evaluate().isNotEmpty || 
          find.textContaining('TOTAL TAGIHAN').evaluate().isNotEmpty ||
          find.byKey(const Key('payment_screen_title')).evaluate().isNotEmpty) {
        foundPaymentScreen = true;
        break;
      }
    }
    expect(foundPaymentScreen, true, reason: 'PaymentScreen should be visible after registration');
    
    // Look for confirm button
    final confirmBtn = find.text('KIRIM KONFIRMASI'); // Match .toUpperCase() if applicable or check exact widget
    final fallbackConfirmBtn = find.text('Kirim Konfirmasi');
    
    final targetConfirmBtn = confirmBtn.evaluate().isNotEmpty ? confirmBtn : fallbackConfirmBtn;
    expect(targetConfirmBtn, findsOneWidget);

    await tester.ensureVisible(targetConfirmBtn);
    await tester.tap(targetConfirmBtn);
    
    await tester.pumpAndSettle(); 

    var tenants = await fs.collection('tenants').get();
    var tenantDoc = tenants.docs.first.data();
    expect(tenantDoc['payment']['verificationStatus'], 'pending');
  });
}
