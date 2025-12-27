import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/widgets/document_upload_widget.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
class FakeTenantService extends TenantService {
  final Future<String> Function(String tenantId, String path) onUpload;
  FakeTenantService(this.onUpload) : super(firestore: FakeFirebaseFirestore(), storage: null);

  @override
  Future<String> uploadTenantDocument(String tenantId, File file, {String? filename}) async {
    final path = file.path;
    return onUpload(tenantId, path);
  }
}

void main() {
  testWidgets('DocumentUploadWidget calls onUploaded after upload', (WidgetTester tester) async {
    String? uploadedUrl;

    final fakeService = FakeTenantService((tenantId, path) async {
      return 'https://example.com/$tenantId/doc.jpg';
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DocumentUploadWidget(
          tenantId: 't1',
          tenantService: fakeService,
          label: 'Test Doc',
          filePicker: () async => '/tmp/fake.jpg',
          onUploaded: (url) {
            uploadedUrl = url;
          },
        ),
      ),
    ));

    // Should show button
    expect(find.text('Unggah'), findsOneWidget);

    // Tap upload button
    await tester.tap(find.text('Unggah'));
    await tester.pumpAndSettle();

    // Expect success state
    expect(uploadedUrl, isNotNull);
    expect(find.text('Tersimpan'), findsOneWidget);
  });
}
