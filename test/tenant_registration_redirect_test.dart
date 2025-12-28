import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

void main() {
  testWidgets('Register redirects to existing pending tenant payment', (
    WidgetTester tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    final tenantRef = fs.collection('tenants').doc();
    await tenantRef.set({
      'owner_uid': 'user-1',
      'status': 'pending_payment',
      'invoice': {'amount': 300000, 'payment_deadline': Timestamp.now()},
    });

    final fakeService = TenantService(firestore: fs, storage: null);

    await tester.pumpWidget(
      MaterialApp(
        home: TenantRegistrationScreen(
          tenantService: fakeService,
          currentUserId: 'user-1',
          initialAcceptedTerms: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Fill required fields so validator doesn't block
    await tester.enterText(find.byType(TextFormField).at(0), 'Bisnis Test');
    await tester.enterText(find.byType(TextFormField).at(2), 'Owner Test');
    await tester.enterText(find.byType(TextFormField).at(3), 'owner@test.com');

    final submitButton = find.textContaining('Daftar & Bayar');
    await tester.ensureVisible(submitButton);
    expect(submitButton, findsOneWidget);

    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Should be navigated to PaymentScreen (upload button visible)
    final uploadButton = find.widgetWithText(
      ElevatedButton,
      'Unggah Bukti Pembayaran',
    );
    expect(uploadButton, findsOneWidget);

    // Only one tenant doc should exist (no duplicate)
    final tenants = await fs.collection('tenants').get();
    expect(tenants.docs.length, 1);
  });
}
