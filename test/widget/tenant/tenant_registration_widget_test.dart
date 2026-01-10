import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  testWidgets('TenantRegistrationScreen shows validation errors', (
    WidgetTester tester,
  ) async {
    // Inject dependencies to avoid FirebaseAuth/Firestore errors
    final fakeFs = FakeFirebaseFirestore();
    final mockService = TenantService(firestore: fakeFs);

    await tester.pumpWidget(
      MaterialApp(
        home: TenantRegistrationScreen(
          tenantService: mockService,
          currentUserId: 'test_user',
        ),
      ),
    );

    // Tap submit without entering any data
    final submitButton = find.textContaining('Daftar & Bayar');
    expect(submitButton, findsOneWidget);

    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Expect validation message for business name
    expect(find.text('Nama Bisnis wajib diisi'), findsOneWidget);

    // Enter invalid email and owner name, then check email validation
    await tester.enterText(find.byType(TextFormField).at(2), 'Owner Name'); 
    await tester.enterText(find.byType(TextFormField).at(3), 'invalid-email'); 
    
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Format email tidak valid'), findsOneWidget);
  });
}
