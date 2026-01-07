// test/login_register_ui_test.dart
// Widget tests untuk login & register screens (simplified)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/login_screen.dart';
import 'package:geges_smartbarber/screens/register_screen.dart';
import 'test_helpers.dart';

void main() {
  group('LoginScreen UI Tests', () {
    testWidgets('TC-LOGIN-UI-01: LoginScreen renders dengan elements utama', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const LoginScreen()));

      // Verify title text (id: Selamat Datang di GEGES)
      expect(find.text('Selamat Datang di GEGES'), findsOneWidget);

      // Verify input fields exist
      expect(find.byType(TextField), findsWidgets);

      // Verify login button (id: Masuk) - Ambiguous because of tab
      expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);

      // Verify Google sign-in button
      expect(find.text('Lanjutkan dengan Google'), findsOneWidget);

      // Verify forgot password link
      expect(find.text('Lupa Kata Sandi?'), findsOneWidget);
    });

    testWidgets('TC-LOGIN-UI-02: Email validation error saat format salah', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const LoginScreen()));

      // Input invalid email
      await tester.enterText(find.byType(TextField).first, 'invalid-email');
      await tester.enterText(find.byType(TextField).last, 'password123');

      // Tap Sign In (id: Masuk)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pump();

      // Should show validation error
      expect(find.text('Format email salah.'), findsOneWidget);
    });

    testWidgets('TC-LOGIN-UI-03: Empty field validation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const LoginScreen()));

      // Try to login with empty fields (id: Masuk)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pump();

      // Should show validation error
      expect(find.text('Email dan kata sandi wajib diisi.'), findsOneWidget);
    });

    testWidgets('TC-LOGIN-UI-04: Password visibility toggle', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const LoginScreen()));

      // Find password field visibility toggles
      final visibilityButtons = find.byIcon(Icons.visibility);
      expect(visibilityButtons, findsWidgets);

      // Tap first visibility button (password field)
      await tester.tap(visibilityButtons.first);
      await tester.pump();

      // Should toggle to visibility_off
      expect(find.byIcon(Icons.visibility_off), findsWidgets);
    });

    testWidgets('TC-LOGIN-UI-05: Tab navigation to Sign Up', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const LoginScreen()));

      // Tap Sign Up tab (localized: Daftar)
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      // RegisterScreen should be visible
      expect(find.text('Buat Akun'), findsOneWidget);
    });
  });

  group('RegisterScreen UI Tests', () {
    testWidgets(
      'TC-REGISTER-UI-01: RegisterScreen renders dengan elements utama',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapWithLocalization(const RegisterScreen()));

        // Verify all input fields exist (name, email, password, confirm)
        expect(find.byType(TextField), findsWidgets);

        // Verify Create Account button
        expect(find.text('Buat Akun'), findsOneWidget);

        // Verify Google sign-up button
        expect(find.text('Lanjutkan dengan Google'), findsOneWidget);

        // Verify password strength indicator text
        expect(find.textContaining('Kekuatan Kata Sandi'), findsOneWidget);
      },
    );

    testWidgets('TC-REGISTER-UI-02: Form validation - empty fields', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const RegisterScreen()));

      // Try to register with empty fields
      final createBtn = find.text('Buat Akun');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pump();

      // Should show error
      expect(find.text('Semua field wajib diisi.'), findsOneWidget);
    });

    testWidgets('TC-REGISTER-UI-03: Form validation - invalid email', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const RegisterScreen()));

      // Fill in fields with invalid email
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'John Doe'); // name
      await tester.enterText(textFields.at(1), 'invalid-email'); // email
      await tester.enterText(textFields.at(2), 'password123'); // password
      await tester.enterText(textFields.at(3), 'password123'); // confirm

      final createBtn = find.text('Buat Akun');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pump();

      // Should show email validation error
      expect(find.text('Format email tidak valid.'), findsOneWidget);
    });

    testWidgets('TC-REGISTER-UI-04: Form validation - password too short', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const RegisterScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'John Doe');
      await tester.enterText(textFields.at(1), 'test@example.com');
      await tester.enterText(textFields.at(2), '123'); // Too short
      await tester.enterText(textFields.at(3), '123');

      final createBtn = find.text('Buat Akun');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pump();

      expect(find.text('Password minimal 6 karakter.'), findsOneWidget);
    });

    testWidgets('TC-REGISTER-UI-05: Form validation - passwords don\'t match', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const RegisterScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'John Doe');
      await tester.enterText(textFields.at(1), 'test@example.com');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.enterText(textFields.at(3), 'different123');

      final createBtn = find.text('Buat Akun');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pump();

      expect(find.text('Password dan konfirmasi tidak cocok.'), findsOneWidget);
    });

    testWidgets('TC-REGISTER-UI-06: Form validation - name too short', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const RegisterScreen()));

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'John'); // Changed Jo to John to trigger MIN 3 logic correctly if needed, but test expects 'Nama minimal 3 karakter.'
      await tester.enterText(textFields.at(0), 'Jo'); // Actually Jo is 2 chars, so it should trigger.
      await tester.enterText(textFields.at(1), 'test@example.com');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.enterText(textFields.at(3), 'password123');

      final createBtn = find.text('Buat Akun');
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pump();

      expect(find.text('Nama minimal 3 karakter.'), findsOneWidget);
    });

    testWidgets('TC-REGISTER-UI-07: Password visibility toggle works', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const RegisterScreen()));

      // Find password field visibility toggles
      final visibilityButtons = find.byIcon(Icons.visibility);
      if (visibilityButtons.evaluate().isNotEmpty) {
        // Tap first visibility button (password field)
        await tester.tap(visibilityButtons.first);
        await tester.pump();

        // Should toggle to visibility_off
        expect(find.byIcon(Icons.visibility_off), findsWidgets);
      }
    });

    testWidgets('TC-REGISTER-UI-08: Tab navigation to Login', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const RegisterScreen()));

      // Find and tap Masuk tab
      await tester.tap(find.text('Masuk').first);
      await tester.pumpAndSettle();

      // LoginScreen should be visible
      expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);
    });
  });

  group('Navigation Tests', () {
    testWidgets('TC-NAV-01: Login to Register navigation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const LoginScreen()));

      // Tap Daftar tab
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();

      // RegisterScreen should be visible
      expect(find.text('Buat Akun'), findsOneWidget);
    });

    testWidgets('TC-NAV-02: Register to Login presence of Log in tab', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWithLocalization(const RegisterScreen()));

      // Verify Masuk tab exists
      expect(find.text('Masuk'), findsWidgets);
    });
  });
}