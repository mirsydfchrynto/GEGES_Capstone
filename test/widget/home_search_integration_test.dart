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
      'name': 'Febrian Barbershop',
      'addres': 'Mejasem Barat',
      'isOpen': true,
      'services': ['Haircut'],
      'rating': 4.8,
      'imageUrl': 'http://test.com/img.jpg',
    });

    await fakeFs.collection('barbershops').doc('shop2').set({
      'name': 'Doels Barbershop',
      'addres': 'Slawi',
      'isOpen': true,
      'services': ['Shave'],
      'rating': 4.5,
      'imageUrl': 'http://test.com/img2.jpg',
    });
  });

  testWidgets('HomeScreen Search Real Simulation', (tester) async {
    mockNetworkImagesFor(() async {
      // Inject real service with fake firestore to test logic flow
      final service = BarbershopService(firestore: fakeFs);
      
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(barbershopService: service),
      ));
      
      // Initial wait
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(); 

      // 1. Verify Initial Data
      expect(find.text('Febrian Barbershop'), findsOneWidget);
      expect(find.text('Doels Barbershop'), findsOneWidget);

      // 2. Search "febrian" (lowercase)
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'febrian');
      await tester.pump(); // Trigger setState(_isSearching = true)

      // Verify loading state logic (in test mode debounce is 0, so likely too fast to catch, but we verify result) 
      
      // Wait for async search
      await tester.pump(); 
      await tester.pump(const Duration(milliseconds: 100)); // Allow microtasks

      // 3. Verify Result
      expect(find.text('Found 1 result'), findsOneWidget);
      expect(find.text('Febrian Barbershop'), findsOneWidget);
      expect(find.text('Doels Barbershop'), findsNothing);

      // 4. Search "slawi" (address)
      await tester.enterText(searchField, 'slawi');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Verify Result
      expect(find.text('Found 1 result'), findsOneWidget);
      expect(find.text('Doels Barbershop'), findsOneWidget);
      expect(find.text('Febrian Barbershop'), findsNothing);

      // 6. Clear Search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      await tester.pump();

      // Verify Back to Home
      expect(find.text('Barbershops\nnear you'), findsOneWidget);
      expect(find.text('Febrian Barbershop'), findsOneWidget);
    });
  });
}
