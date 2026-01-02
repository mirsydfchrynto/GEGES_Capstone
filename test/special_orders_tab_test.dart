import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/customer/tabs/my_bookings_screen.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

void main() {
  testWidgets('Navigates to SpecialOrdersScreen and shows orders', (tester) async {
    // 1. Setup Mock Firestore
    final fakeFs = FakeFirebaseFirestore();
    final mockAuth = MockFirebaseAuth();
    final queueSvc = QueueService(firestore: fakeFs, auth: mockAuth);
    final userId = 'user_special_test';

    // 2. Seed Data
    await fakeFs.collection('tenants').add({
      'owner_uid': userId,
      'business_name': 'Special Barber Shop',
      'status': 'active', // Should show 'SUKSES / AKTIF'
      'created_at': Timestamp.now(),
      'invoice': {'amount': 300000},
    });

    // 3. Pump MyBookingsScreen
    await tester.pumpWidget(MaterialApp(
      home: MyBookingsScreen(
        firestore: fakeFs,
        queueService: queueSvc,
        currentUserId: userId,
      ),
    ));
    await tester.pumpAndSettle();

    // 4. Find and Tap Special Orders Button (Star Icon)
    final specialOrderBtn = find.byIcon(Icons.stars);
    expect(specialOrderBtn, findsOneWidget);
    
    await tester.tap(specialOrderBtn);
    await tester.pumpAndSettle();

    // 5. Verify SpecialOrdersScreen content
    expect(find.text('Special Orders'), findsOneWidget); // AppBar title
    expect(find.text('Special Barber Shop'), findsOneWidget); // Business Name
    expect(find.text('SUKSES / AKTIF'), findsOneWidget); // Status
  });
}