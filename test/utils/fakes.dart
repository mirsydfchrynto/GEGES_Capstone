// test/utils/fakes.dart
// Reusable fake AuthService implementations for widget/unit tests
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geges_smartbarber/models/user_data.dart';
import 'package:geges_smartbarber/services/auth_service.dart';

class FakeAuthServiceSpy implements AuthServiceBase {
  bool sendResetCalled = false;
  String? lastResetEmail;

  Map<String, dynamic> signInResponse = {'success': false};
  Map<String, dynamic> googleResponse = {'success': false};
  Map<String, dynamic> registerResponse = {
    'success': false,
    'message': 'not implemented',
  };

  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async {}

  FakeAuthServiceSpy({
    Map<String, dynamic>? signInResponseOverride,
    Map<String, dynamic>? googleResponseOverride,
    Map<String, dynamic>? registerResponseOverride,
  }) {
    if (signInResponseOverride != null) {
      signInResponse = signInResponseOverride;
    }
    if (googleResponseOverride != null) {
      googleResponse = googleResponseOverride;
    }
    if (registerResponseOverride != null) {
      registerResponse = registerResponseOverride;
    }
  }

  @override
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async => signInResponse;

  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String name,
  }) async => registerResponse;

  @override
  Future<Map<String, dynamic>> signInWithGoogle() async => googleResponse;

  @override
  Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String email,
  }) async {
    sendResetCalled = true;
    lastResetEmail = email;
    return {
      'success': true,
      'message': 'Link reset password telah dikirim ke $email.',
    };
  }

  @override
  Future<UserData?> getUserById(String uid) async => null;

  @override
  Future<bool> isEmailRegistered(String email) async => false;

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {}
}
