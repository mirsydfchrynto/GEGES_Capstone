import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/models/user_data.dart';
import 'package:geges_smartbarber/screens/customer/edit_profile_screen.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../test_helpers.dart';

class MockAuthService extends Mock implements AuthService {
  @override
  auth.User? get currentUser => MockUser(
    uid: 'test_uid',
    email: 'test@example.com',
    displayName: 'Test User',
  );
}

void main() {
  testWidgets('EditProfileScreen shows user data correctly', (WidgetTester tester) async {
    final mockAuth = MockAuthService();
    
    final userData = UserData(
      uid: 'test_uid',
      name: 'Test User',
      role: 'customer',
      phoneNumber: '08123456789',
    );

    await tester.pumpWidget(wrapWithLocalization(EditProfileScreen(
        currentUser: userData,
        authService: mockAuth,
      ),
    ));

    expect(find.text('Nama Lengkap'), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('08123456789'), findsOneWidget);
  });
}