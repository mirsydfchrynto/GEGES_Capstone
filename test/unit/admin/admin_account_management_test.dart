import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import '../../helpers/manual_mocks.dart';
import 'package:geges_smartbarber/screens/admin/account_management_screen.dart';
import 'package:geges_smartbarber/services/auth_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late AuthService authService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    final mockUser = MockUser(
      uid: 'admin123',
      email: 'admin@test.com',
      displayName: 'Admin User',
    );
    mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    authService = AuthService(auth: mockAuth, firestore: fakeFirestore);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: AccountManagementScreen(
        userId: 'admin123',
        authService: authService,
      ),
    );
  }

  testWidgets('Should display user data correctly', (WidgetTester tester) async {
    // 1. Prepare data in fake firestore
    await fakeFirestore.collection('users').doc('admin123').set({
      'name': 'Admin User',
      'role': 'admin_owner',
      'phone_number': '0812345678',
    });

    // 2. Build widget
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 3. Verify fields
    expect(find.text('Admin User'), findsOneWidget);
    expect(find.text('0812345678'), findsOneWidget);
    expect(find.text('admin@test.com'), findsOneWidget);
  });

  testWidgets('Should update user profile successfully', (WidgetTester tester) async {
    await fakeFirestore.collection('users').doc('admin123').set({
      'name': 'Admin User',
      'role': 'admin_owner',
      'phone_number': '0812345678',
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Change name
    await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap'), 'New Admin Name');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nomor Telepon'), '08999999');
    
    // Tap Save
    await tester.tap(find.text('SIMPAN PERUBAHAN'));
    
    // Pump several times to trigger the async operation and the UI update
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify snackbar
    expect(find.text('Profil berhasil diperbarui'), findsOneWidget);
    
    // Verify data in firestore
    final doc = await fakeFirestore.collection('users').doc('admin123').get();
    expect(doc.data()?['name'], 'New Admin Name');
    expect(doc.data()?['phone_number'], '08999999');
  });
}
