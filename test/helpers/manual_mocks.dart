import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

class MockUser extends Mock implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;

  MockUser({required this.uid, this.email, this.displayName});

  @override
  Future<void> updateDisplayName(String? displayName) async {
    return;
  }
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  final MockUser? mockUser;
  final bool signedIn;
  MockFirebaseAuth({this.mockUser, this.signedIn = false});
  
  @override
  User? get currentUser => signedIn ? mockUser : null;
}

class MockClient extends Mock implements http.Client {}
