import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

class FakeTenantService2 extends TenantService {
  final Future<String> Function(String tenantId, String path) onUpload;
  final Future<void> Function({required String tenantId, required String proofUrl, required String userId}) onSubmit;

  FakeTenantService2(this.onUpload, this.onSubmit) : super(firestore: FakeFirebaseFirestore(), storage: null);

  @override
  Future<String> uploadTenantDocument(String tenantId, File file, {String? filename}) async {
    final path = file.path;
    return onUpload(tenantId, path);
  }

  @override
  Future<void> submitRegistrationPayment({required String tenantId, required String proofUrl, required String userId}) async {
    return onSubmit(tenantId: tenantId, proofUrl: proofUrl, userId: userId);
  }
}

void main() {
  testWidgets('TenantContinueScreen uploads proof and updates invoice', (WidgetTester tester) async {
    final fs = FakeFirebaseFirestore();
    final tenantId = 'tenant123';
    await fs.collection('tenants').doc(tenantId).set({
      'invoice': {'amount': 300000, 'status': 'waiting_proof'}
    });

    var submitted = false;

    final fakeService = FakeTenantService2(
      (id, path) async {
        return 'https://example.com/$id/proof.jpg';
      },
      ({required String tenantId, required String proofUrl, required String userId}) async {
        submitted = true;
        // write to firestore to emulate submit action
        await fs.collection('tenants').doc(tenantId).set({
          'invoice': {'status': 'payment_submitted', 'submitted_at': Timestamp.now(), 'payment_proof_url': proofUrl}
        }, SetOptions(merge: true));
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: TenantContinueScreen(
        tenantId: tenantId,
        amount: 300000,
        tenantService: fakeService,
        firestore: fs,
        filePicker: () async => '/tmp/fake_proof.jpg',
      ),
    ));

    // find upload button
    final uploadButton = find.text('Unggah Bukti Pembayaran');
    expect(uploadButton, findsOneWidget);

    await tester.tap(uploadButton);
    await tester.pumpAndSettle();

    expect(submitted, isTrue);

    final doc = await fs.collection('tenants').doc(tenantId).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['invoice']['status'], 'payment_submitted');
    expect(doc.data()!['invoice']['payment_proof_url'], isNotNull);
  });
}
