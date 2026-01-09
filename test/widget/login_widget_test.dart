import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/auth/login_screen.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/models/user_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/test_helpers.dart';

// Simple fake AuthService for widget tests
class FakeAuthService implements AuthService {
  bool signInCalled = false;
  String? lastEmail;
  String? lastPassword;
  final Map<String, dynamic> response;

  FakeAuthService({
    this.response = const {'success': true, 'role': 'customer'},
  });

  @override
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    signInCalled = true;
    lastEmail = email;
    lastPassword = password;
    return response;
  }

  @override
  Future<Map<String, dynamic>> signInWithGoogle() async {
    return response;
  }

  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String name,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> sendPasswordResetEmail({required String email}) {
    throw UnimplementedError();
  }

  // The rest of the methods are not used in these widget tests.
  @override
  Future<UserData?> getUserById(String uid) {
    throw UnimplementedError();
  }

  @override
  Future<void> reauthWithGoogle() {
    throw UnimplementedError();
  }

  @override
  Future<void> reauthWithPassword(String email, String currentPassword) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String uid,
    required String newName,
    String? newEmail,
    String? newPhoneNumber,
    String? newPhotoBase64,
    String? currentPasswordForReauth,
    bool trySendVerification = true,
  }) async {
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> reauthAndUpdateProfile({
    required String uid,
    required String newName,
    String? newEmail,
    String? currentPassword,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }

  @override
  User? get currentUser => null;

  @override
  FirebaseAuth get auth => throw UnimplementedError();

  @override
  Future<bool> isAdmin(String uid) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('TC-BB-01: Show validation when fields empty', (
    WidgetTester tester,
  ) async {
    final fake = FakeAuthService();
    await tester.pumpWidget(wrapWithLocalization(LoginScreen(authService: fake)));

    // Tap Sign In without entering credentials
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('wajib diisi', findRichText: false),
      findsOneWidget,
    );
    expect(fake.signInCalled, false);
  });

  testWidgets('TC-BB-02: Show validation for invalid email format', (
    WidgetTester tester,
  ) async {
    final fake = FakeAuthService();
    await tester.pumpWidget(wrapWithLocalization(LoginScreen(authService: fake)));

    await tester.enterText(find.byType(TextField).first, 'invalid-email');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Format email salah.'), findsOneWidget);
    expect(fake.signInCalled, false);
  });

  testWidgets('TC-BB-06: Successful login navigates to HomeScreen', (
    WidgetTester tester,
  ) async {
    final fake = FakeAuthService(
      response: {'success': true, 'role': 'customer'},
    );
    await tester.pumpWidget(
      wrapWithLocalization(LoginScreen(
        authService: fake,
        homeBuilder: (_) => const Text('HOME-TEST'),
        adminBuilder: (_) => const Text('ADMIN-TEST'),
      )),
    );

    await tester.enterText(find.byType(TextField).first, 'esa@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), '123456789');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();

    // Placeholder builder was used
    expect(find.text('HOME-TEST'), findsOneWidget);
  });

  testWidgets('TC-BB-07: Successful login navigates to AdminDashboard', (
    WidgetTester tester,
  ) async {
    final fake = FakeAuthService(
      response: {'success': true, 'role': 'admin_owner'},
    );
    await tester.pumpWidget(
      wrapWithLocalization(LoginScreen(
        authService: fake,
        homeBuilder: (_) => const Text('HOME-TEST'),
        adminBuilder: (_) => const Text('ADMIN-TEST'),
      )),
    );

    await tester.enterText(find.byType(TextField).first, 'admin@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'adminpass');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();

    // Placeholder builder was used
    expect(find.text('ADMIN-TEST'), findsOneWidget);
  });
}
