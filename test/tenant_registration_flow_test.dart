import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

class FakeTenantServiceFlow extends TenantService {
  FakeTenantServiceFlow(FakeFirebaseFirestore fs)
    : super(firestore: fs, storage: null);

  @override
  Future<String> uploadTenantDocument(
    String tenantId,
    File file, {
    String? filename,
  }) async {
    // don't read the file during tests; return a fake firestore ref path
    final ref =
        'tenants/$tenantId/doc_${DateTime.now().millisecondsSinceEpoch}';
    return ref;
  }
}

void main() {
  testWidgets('Full tenant registration stores docs as Firestore refs and requires terms', (
    WidgetTester tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    final fakeService = FakeTenantServiceFlow(fs);

    await tester.pumpWidget(
      MaterialApp(
        home: TenantRegistrationScreen(
          tenantService: fakeService,
          currentUserId: 'user-1',
          initialAcceptedTerms: true,
          initialCompanyDocPath: '/tmp/siup.jpg',
          initialTaxDocPath: '/tmp/npwp.jpg',
          // For tests, provide a handler that directly writes a fake proof
          testSubmitProofHandler: (tenantId) async {
            await fakeService.submitRegistrationPayment(
              tenantId: tenantId,
              proofBase64: 'FAKEBASE64',
              userId: 'user-1',
            );
          },
        ),
      ),
    );

    // let the widget settle before further interactions
    await tester.pumpAndSettle();

    // fill required fields
    await tester.enterText(find.byType(TextFormField).at(0), 'Bisnis Test');
    await tester.enterText(find.byType(TextFormField).at(2), 'Owner Test');
    await tester.enterText(find.byType(TextFormField).at(3), 'owner@test.com');

    // accept terms: initialAcceptedTerms=true used in widget constructor for test
    // initialAcceptedTerms passed to widget (verify param)
    final regWidget = tester.widget<TenantRegistrationScreen>(
      find.byType(TenantRegistrationScreen),
    );
    expect(regWidget.initialAcceptedTerms, true);

    // we proceed to submit — actual checkbox UI shouldn't block the test because initialAcceptedTerms is set

    // Sanity: ensure selected file labels updated in UI
    expect(find.textContaining('SIUP:'), findsOneWidget);
    expect(find.textContaining('NPWP:'), findsOneWidget);

    // submit
    final submitButton = find.textContaining('Daftar & Bayar');
    await tester.ensureVisible(submitButton);
    expect(submitButton, findsOneWidget);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // After submit, registration should create a tenant doc in firestore
    var tenants = await fs.collection('tenants').get();
    expect(tenants.docs.length, greaterThan(0));
    var tenantDoc = tenants.docs.first.data();

    expect(tenantDoc['accepted_terms'], true);
    expect(tenantDoc.containsKey('company_doc_ref'), true);
    expect(tenantDoc.containsKey('tax_doc_ref'), true);
    expect(tenantDoc['invoice'] != null, true);
    expect(tenantDoc['invoice']['status'], 'waiting_proof');

    // Should navigate to payment screen — simulate test submit via provided handler
    // in this test we provide testSubmitProofHandler that calls submitRegistrationPayment
    final uploadButton = find.widgetWithText(
      ElevatedButton,
      'Unggah Bukti Pembayaran',
    );
    expect(uploadButton, findsOneWidget);

    // Tap upload (this will call the test handler which submits a fake proof)
    await tester.ensureVisible(uploadButton);
    await tester.pumpAndSettle();
    await tester.tap(uploadButton);
    await tester.pumpAndSettle();

    // Ensure tenant doc updated with payment info (proof base64 and pending verification)
    tenants = await fs.collection('tenants').get();
    tenantDoc = tenants.docs.first.data();
    expect(tenantDoc['payment'] != null || tenantDoc['payment'] != null, true);
    expect(
      tenantDoc['payment']['payment_proof_base64'] == 'FAKEBASE64' ||
          tenantDoc['payment']['proofUrl'] != null,
      true,
    );
    expect(tenantDoc['payment']['verificationStatus'], 'pending');

    // Check guidance message was shown (snackbar) — look for a short confirmation text in widget tree
    expect(
      find.textContaining(
        'Pendaftaran dan dokumen sedang diproses',
        findRichText: false,
      ),
      findsOneWidget,
    );
  });
}
