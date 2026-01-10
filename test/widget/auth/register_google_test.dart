// test/register_google_test.dart
// Widget tests for RegisterScreen Google sign-in behavior
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/auth/register_screen.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/models/user_data.dart';
import '../../helpers/test_helpers.dart';

class FakeAuthServiceSuccess implements AuthServiceBase {
  FakeAuthServiceSuccess();

  @override
  Future<Map<String, dynamic>> signInWithGoogle() async => {'success': true};

  // unused in these tests but required by the interface
  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String name,
  }) async => {'success': false, 'message': 'not implemented'};

  @override
  Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String email,
  }) async => {'success': false, 'message': 'not implemented'};

  @override
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async => {'success': false, 'message': 'not implemented'};

  @override
  Future<UserData?> getUserById(String uid) async => null;

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {}
}

class FakeAuthServiceFailure implements AuthServiceBase {
  final String message;
  FakeAuthServiceFailure(this.message);

  @override
  Future<Map<String, dynamic>> signInWithGoogle() async => {
    'success': false,
    'message': message,
  };

  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String name,
  }) async => {'success': false, 'message': 'not implemented'};

  @override
  Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String email,
  }) async => {'success': false, 'message': 'not implemented'};

  @override
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async => {'success': false, 'message': 'not implemented'};

  @override
  Future<UserData?> getUserById(String uid) async => null;

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {}
}

void main() {
  testWidgets('TC-GOOGLE-01: Google sign-up success navigates to Login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapWithLocalization(RegisterScreen(authService: FakeAuthServiceSuccess())),
    );

    expect(find.byKey(const Key('register_google_btn')), findsOneWidget);

    final googleBtn = find.byKey(const Key('register_google_btn'));
    await tester.ensureVisible(googleBtn);
    await tester.tap(googleBtn);
    await tester.pumpAndSettle();

    // After success, RegisterScreen navigates to LoginScreen which contains "Sign In"
    expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);
  });

  testWidgets(
    'TC-GOOGLE-02: Google sign-up failure shows error and Retry action',
    (WidgetTester tester) async {
      const failMessage = 'Recaptcha check failed';
      await tester.pumpWidget(
        wrapWithLocalization(RegisterScreen(
            authService: FakeAuthServiceFailure(failMessage),
          ),
        ),
      );

      final googleBtn = find.byKey(const Key('register_google_btn'));
      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle(); // show snackbar / error

      // Error message should be set in the UI (either as _errorMessage or in snackbar)
      expect(find.textContaining('Recaptcha'), findsWidgets);

      // Snackbar action 'Retry' should be present for this kind of error (localized)
      expect(find.text('Coba Lagi'), findsOneWidget);
    },
  );
}
