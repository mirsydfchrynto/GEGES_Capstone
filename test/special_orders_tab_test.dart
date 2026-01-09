import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/customer/special_orders_screen.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'test_helpers.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  testWidgets('Navigates to SpecialOrdersScreen and shows orders', (tester) async {
    // 1. Setup Data
    await fakeFirestore.collection('tenants').add({
      'owner_uid': 'user123',
      'business_name': 'My Barber',
      'status': 'pending_payment',
      'created_at': Timestamp.now(),
    });

    // 2. Pump Widget (SpecialOrdersScreen directly)
    await tester.pumpWidget(
      wrapWithLocalization(
        SpecialOrdersScreen(
          firestore: fakeFirestore,
          currentUserId: 'user123',
        ),
      ),
    );

    // 3. Verify Loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(); // Allow stream to emit

    // 4. Verify Content
    expect(find.text('My Barber'), findsOneWidget);
    expect(find.text('PARTNERSHIP'), findsOneWidget);
  });
}