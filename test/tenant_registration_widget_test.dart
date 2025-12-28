import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';

void main() {
  testWidgets('TenantRegistrationScreen shows validation errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TenantRegistrationScreen()),
    );

    // Tap submit without entering any data
    final submitButton = find.textContaining('Daftar & Bayar');
    expect(submitButton, findsOneWidget);

    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Expect validation message for business name
    expect(find.text('Nama bisnis wajib diisi'), findsOneWidget);

    // Enter invalid email and owner name, then check email validation
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'owner',
    ); // owner email field is the 3rd field (index 2)
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Email tidak valid'), findsOneWidget);
  });
}
