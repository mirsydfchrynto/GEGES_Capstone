import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/customer/home_screen.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/location_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:mockito/mockito.dart';
import '../helpers/test_helpers.dart';

class MockLocationService extends LocationService {
  @override
  Future<String?> getCurrentLocationAddress() async {
    return 'Test Location, Indonesia';
  }
}

class MockQueueService extends Mock implements QueueService {
  @override
  Stream<int> streamUnreadNotificationCount(String userId) {
    return Stream.value(0);
  }
}

void main() {
  late FakeFirebaseFirestore fakeFs;

  setUp(() async {
    fakeFs = FakeFirebaseFirestore();

    // Seed data
    await fakeFs.collection('barbershops').doc('shop1').set({
      'name': 'Febrian Barbershop',
      'addres': 'Mejasem Barat',
      'isOpen': true,
      'isActive': true,
      'services': ['Haircut'],
      'imageUrl': 'http://test.com/img.jpg',
    });

    await fakeFs.collection('barbershops').doc('shop2').set({
      'name': 'Doels Barbershop',
      'addres': 'Slawi',
      'isOpen': true,
      'isActive': true,
      'services': ['Shave'],
      'imageUrl': 'http://test.com/img2.jpg',
    });
  });

  testWidgets('HomeScreen Search Real Simulation', (tester) async {
    mockNetworkImagesFor(() async {
      // Inject real service with fake firestore to test logic flow
      final service = BarbershopService(firestore: fakeFs);
      final mockLoc = MockLocationService();
      final mockQueue = MockQueueService();
      
      await tester.pumpWidget(wrapWithLocalization(HomeScreen(
          barbershopService: service,
          locationService: mockLoc,
          queueService: mockQueue,
          currentUserId: 'test-user',
        ),
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
      
      // Advance time for debounce and search result processing
      for(int i=0; i<5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // 3. Verify Result
      expect(find.text('Ditemukan 1 hasil'), findsOneWidget);
      expect(find.text('Febrian Barbershop'), findsOneWidget);
      expect(find.text('Doels Barbershop'), findsNothing);

      // 4. Search "slawi" (address)
      await tester.enterText(searchField, 'slawi');
      for(int i=0; i<5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // 5. Verify Result
      expect(find.text('Ditemukan 1 hasil'), findsOneWidget);
      expect(find.text('Doels Barbershop'), findsOneWidget);
      expect(find.text('Febrian Barbershop'), findsNothing);

      // 6. Clear Search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Verify Back to Home
      expect(find.text('Barbershop\ndi dekatmu'), findsOneWidget);
      expect(find.text('Febrian Barbershop'), findsOneWidget);
    });
  });
}
