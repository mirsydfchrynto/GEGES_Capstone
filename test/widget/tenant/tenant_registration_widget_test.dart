import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../../helpers/test_helpers.dart';

void main() {
  testWidgets('TenantRegistrationScreen shows validation errors', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    // Inject dependencies to avoid FirebaseAuth/Firestore errors
    final fakeFs = FakeFirebaseFirestore();
    final mockService = TenantService(firestore: fakeFs);

    await tester.pumpWidget(
      wrapWithLocalization(
        SizedBox(
          width: 800,
          height: 1200,
          child: TenantRegistrationScreen(
            tenantService: mockService,
            currentUserId: 'test_user',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    if (find.text('LANJUT DAFTAR').evaluate().isNotEmpty) {
      await tester.tap(find.text('LANJUT DAFTAR'));
      await tester.pumpAndSettle();
    }

    // Tap submit without entering any data
    final submitButton = find.textContaining('Daftar & Bayar');
    expect(submitButton, findsOneWidget);

    await tester.tap(submitButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Expect validation message for business name
    expect(find.text('Nama Bisnis wajib diisi'), findsOneWidget);

    // Enter invalid email and owner name, then check email validation
    await tester.enterText(find.byType(TextFormField).at(2), 'Owner Name'); 
    await tester.enterText(find.byType(TextFormField).at(3), 'invalid-email'); 
    
    await tester.tap(submitButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Format email tidak valid'), findsOneWidget);
  });
}
