import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'test_helpers.dart';

class FakeTenantServiceFlow extends TenantService {
  FakeTenantServiceFlow(FakeFirebaseFirestore fs)
    : super(firestore: fs, storage: null);

  @override
  Future<String> uploadTenantDocument(
    String tenantId,
    File file, {
    String? filename,
  }) async {
    return 'tenants/$tenantId/doc_${DateTime.now().millisecondsSinceEpoch}';
  }
}

void main() {
  testWidgets('Full tenant registration stores docs as Firestore refs and requires terms', (
    WidgetTester tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    final fakeService = FakeTenantServiceFlow(fs);

    await tester.pumpWidget(
      wrapWithLocalization(TenantRegistrationScreen(
          tenantService: fakeService,
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
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Bisnis Test');
    await tester.enterText(find.byType(TextFormField).at(2), 'Owner Test');
    await tester.enterText(find.byType(TextFormField).at(3), 'owner@test.com');

    final submitButton = find.textContaining('Daftar & Bayar');
    await tester.ensureVisible(submitButton); // Ensure visible before tap
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    
    // Give time for async navigation and build
    await tester.pump(const Duration(seconds: 1));

    // Verify Payment Screen
    final uploadButton = find.widgetWithText(ElevatedButton, 'Kirim Konfirmasi');
    expect(uploadButton, findsOneWidget);

    await tester.tap(uploadButton);
    await tester.pump(); // Start animation
    // Wait for async handler
    await tester.pump(const Duration(milliseconds: 500)); 
    // Wait for SnackBar animation
    await tester.pump(const Duration(seconds: 3)); 

    var tenants = await fs.collection('tenants').get();
    var tenantDoc = tenants.docs.first.data();
    expect(tenantDoc['payment']['verificationStatus'], 'pending');

    // History should contain a registration_payment event
    expect(tenantDoc['history'] != null, true);
    final historyData = tenantDoc['history'] as List<dynamic>;
    expect(historyData.any((h) => h['type'] == 'registration_payment'), isTrue);
  });
}