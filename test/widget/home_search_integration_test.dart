import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/customer/home_screen.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:network_image_mock/network_image_mock.dart';

void main() {
  late FakeFirebaseFirestore fakeFs;

  setUp(() async {
    fakeFs = FakeFirebaseFirestore();

    // Seed data
    await fakeFs.collection('barbershops').doc('shop1').set({
      'name': 'Geges Barber',
      'addres': 'Jalan Mawar',
      'isOpen': true,
      'services': ['Haircut'],
      'rating': 4.5,
      'imageUrl': 'http://test.com/img.jpg',
    });

    await fakeFs.collection('barbershops').doc('shop2').set({
      'name': 'Luxury Cuts',
      'addres': 'Jalan Melati',
      'isOpen': true,
      'services': ['Shave'],
      'rating': 5.0,
      'imageUrl': 'http://test.com/img2.jpg',
    });
  });

  testWidgets('HomeScreen Search Integration Flow', (tester) async {
    mockNetworkImagesFor(() async {
      final service = BarbershopService(firestore: fakeFs);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(barbershopService: service),
      ));
      // Initial wait for data
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(); // Rebuild with data

      // 1. Initial State: Show recommendation title
      expect(find.textContaining('Barbershops'), findsOneWidget);
      expect(find.text('Geges Barber'), findsOneWidget);
      expect(find.text('Luxury Cuts'), findsOneWidget);

      // 2. Type Query: "Luxury"
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Luxury');
      await tester.pump(); // Update UI to reflect non-empty controller text

      // Now "Barbershops" should already be gone because text is NOT empty
      expect(find.textContaining('Barbershops'), findsNothing);

      // Trigger search (now zero debounce in test mode)
      await tester.enterText(searchField, 'Luxury');
      await tester.pump(); // Start search
      await tester.pump(); // Process async fetch
      await tester.pump(); // Rebuild results

      // 3. Verify: Results view shown, recommendation hidden
      expect(find.textContaining('Barbershops'), findsNothing);
      expect(find.text('Found 1 result'), findsOneWidget);
      expect(find.text('Luxury Cuts'), findsOneWidget);
      expect(find.text('Geges Barber'), findsNothing);

      // 4. Test Clear Button
      final clearBtn = find.byIcon(Icons.clear);
      await tester.tap(clearBtn);
      await tester.pump(); // Rebuild state
      await tester.pump(); // Sync UI

      // Verify: Back to initial state
      expect(find.textContaining('Barbershops'), findsOneWidget);
    });
  });
}