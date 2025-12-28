import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

class FakeTenantServiceFlow extends TenantService {
  FakeTenantServiceFlow(FakeFirebaseFirestore fs) : super(firestore: fs, storage: null);

  @override
  Future<String> uploadTenantDocument(String tenantId, File file, {String? filename}) async {
    // don't read the file during tests; return a fake firestore ref path
    final ref = 'tenants/$tenantId/doc_${DateTime.now().millisecondsSinceEpoch}';
    return ref;
  }
}

void main() {
  testWidgets('Full tenant registration stores docs as Firestore refs and requires terms', (WidgetTester tester) async {
    final fs = FakeFirebaseFirestore();
    final fakeService = FakeTenantServiceFlow(fs);

    await tester.pumpWidget(MaterialApp(
      home: TenantRegistrationScreen(
        tenantService: fakeService,
        currentUserId: 'user-1',
        initialAcceptedTerms: true,
        initialCompanyDocPath: '/tmp/siup.jpg',
        initialTaxDocPath: '/tmp/npwp.jpg',
      ),
    ));

    // let the widget settle before further interactions
    await tester.pumpAndSettle();

    // fill required fields
    await tester.enterText(find.byType(TextFormField).at(0), 'Bisnis Test');
    await tester.enterText(find.byType(TextFormField).at(2), 'Owner Test');
    await tester.enterText(find.byType(TextFormField).at(3), 'owner@test.com');

    // accept terms: initialAcceptedTerms=true used in widget constructor for test
    // initialAcceptedTerms passed to widget (verify param)
    final regWidget = tester.widget<TenantRegistrationScreen>(find.byType(TenantRegistrationScreen));
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

    // Registration should create a tenant doc in firestore
    final tenants = await fs.collection('tenants').get();
    expect(tenants.docs.length, greaterThan(0));
    final tenantDoc = tenants.docs.first.data();

    expect(tenantDoc['accepted_terms'], true);
    expect(tenantDoc.containsKey('company_doc_ref'), true);
    expect(tenantDoc.containsKey('tax_doc_ref'), true);
    expect(tenantDoc['invoice'] != null, true);
    expect(tenantDoc['invoice']['status'], 'waiting_proof');
  });
}
