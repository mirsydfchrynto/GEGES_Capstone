import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Minimal test fakes
class _FakeGoogleSignInThrows extends GoogleSignIn {
  final Exception error;
  _FakeGoogleSignInThrows(this.error);

  @override
  Future<GoogleSignInAccount?> signIn() => Future.error(error);
}

class _FakeGoogleSignInReturnsNull extends GoogleSignIn {
  @override
  Future<GoogleSignInAccount?> signIn() async => null;
}

class _FakeFirebaseAuthThrowsInvalidCredential extends Fake implements FirebaseAuth {
  @override
  Future<UserCredential> signInWithEmailAndPassword({required String email, required String password}) {
    throw FirebaseAuthException(code: 'invalid-credential', message: 'invalid credential');
  }
}

class _NoOpFirebaseAuth extends Fake implements FirebaseAuth {}
class _NoOpFirestore extends Fake implements FirebaseFirestore {}

void main() {
  test('signInWithGoogle maps ApiException: 10 to friendly SHA-1 message', () async {
    final auth = AuthService(auth: _NoOpFirebaseAuth(), firestore: _NoOpFirestore(), googleSignIn: _FakeGoogleSignInThrows(Exception('ApiException: 10')));
    final res = await auth.signInWithGoogle();

    expect(res['success'], isFalse);
    expect((res['message'] as String).toLowerCase(), contains('sha-1'));
    expect((res['message'] as String).toLowerCase(), contains('apiexception'));
  });

  test('signInWithGoogle returns cancelled message when user aborts', () async {
    final auth = AuthService(auth: _NoOpFirebaseAuth(), firestore: _NoOpFirestore(), googleSignIn: _FakeGoogleSignInReturnsNull());
    final res = await auth.signInWithGoogle();

    expect(res['success'], isFalse);
    expect(res['message'], 'Google sign-in dibatalkan oleh pengguna.');
  });

  test('signIn maps invalid-credential to friendly message', () async {
    final fakeAuth = _FakeFirebaseAuthThrowsInvalidCredential();
    final auth = AuthService(auth: fakeAuth, firestore: _NoOpFirestore());

    final res = await auth.signIn(email: 'a@b.c', password: 'pw');
    expect(res['success'], isFalse);
    expect((res['message'] as String).toLowerCase(), contains('credential tidak valid'));
  });
}
