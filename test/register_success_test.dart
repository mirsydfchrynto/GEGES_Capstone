import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/register_screen.dart';
import 'utils/fakes.dart';

void main() {
  testWidgets('TC-REGISTER-01: Successful registration navigates to Login', (WidgetTester tester) async {
    final fakeSuccess = FakeAuthServiceSpy(registerResponseOverride: {'success': true, 'message': 'Registrasi berhasil. Silakan verifikasi email Anda.'});

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(authService: fakeSuccess),
      ),
    );

    // Fill form
    await tester.enterText(find.byKey(const Key('register_name')), 'Ivon'); // Username
    await tester.enterText(find.byKey(const Key('register_email')), 'ivon@example.com'); // Email
    await tester.enterText(find.byKey(const Key('register_password')), 'Password1!'); // Password
    await tester.enterText(find.byKey(const Key('register_confirm_password')), 'Password1!'); // Confirm Password

    final createBtn = find.byKey(const Key('register_create_btn'));
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // After success, RegisterScreen navigates to LoginScreen which contains "Sign In"
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('TC-REGISTER-02: Failed registration shows error message', (WidgetTester tester) async {
    final fakeFail = FakeAuthServiceSpy(registerResponseOverride: {'success': false, 'message': 'Email sudah terdaftar.'});

    await tester.pumpWidget(
      MaterialApp(
        home: RegisterScreen(authService: fakeFail),
      ),
    );

    // Fill form
    await tester.enterText(find.byType(TextField).at(0), 'Iv'); // invalid small name to trigger earlier validation
    await tester.enterText(find.byType(TextField).at(1), 'ivon@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'Password1!');
    await tester.enterText(find.byType(TextField).at(3), 'Password1!');

    final createBtn = find.text('Create Account');
    await tester.ensureVisible(createBtn);
    await tester.tap(createBtn);

    // Small name should show validation error 'Nama minimal 3 karakter.' without calling service
    await tester.pumpAndSettle();
    expect(find.text('Nama minimal 3 karakter.'), findsOneWidget);

    // Now enter valid name and re-attempt; service will return failure
    await tester.enterText(find.byType(TextField).at(0), 'Ivon');
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // The error message from service should be shown
    expect(find.text('Email sudah terdaftar.'), findsOneWidget);
  });
}
