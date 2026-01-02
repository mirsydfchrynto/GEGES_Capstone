import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/screens/customer/tabs/barbershop_detail_screen.dart';
import 'package:geges_smartbarber/screens/customer/tabs/favorite_barbershops_screen.dart';

// Mock CachedNetworkImage to avoid network calls
class MockCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  const MockCachedNetworkImage({super.key, required this.imageUrl});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  late FakeFirebaseFirestore fakeFs;
  late Barbershop testShop;

  setUp(() async {
    fakeFs = FakeFirebaseFirestore();
    // mockAuth is implicitly used via injection or setup if needed, but here we inject userId string directly
    // so we don't strictly need the variable if we don't use it.
    
    testShop = Barbershop(
      id: 'shop123',
      name: 'Geges Test Shop',
      addres: 'Jalan Test No 1',
      imageUrl: 'http://test.com/img.jpg',
      rating: 4.5,
      openHour: 9,
      closeHour: 21,
      isOpen: true,
      services: ['cut'],
    );

    // Seed shop data
    await fakeFs.collection('barbershops').doc(testShop.id).set(testShop.toJson());
    // Seed user data (initially no favorites)
    await fakeFs.collection('users').doc('user1').set({
      'name': 'Test User',
      'favorite_barbershops': [],
    });
  });

  testWidgets('Favorite Flow: Toggle Favorite in Detail Screen', (tester) async {
    // 1. Pump Detail Screen
    await tester.pumpWidget(MaterialApp(
      home: BarbershopDetailScreen(
        barbershop: testShop,
        firestore: fakeFs,
        testUserId: 'user1',
      ),
    ));
    await tester.pumpAndSettle();

    // 2. Initial State: Not Favorite (Heart Outline)
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);

    // 3. Tap Favorite Button
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump(); // Start animation/logic
    await tester.pumpAndSettle(); // Wait for completion

    // 4. Verify UI Change (Heart Filled)
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    
    // 5. Verify Firestore Data
    final userDoc = await fakeFs.collection('users').doc('user1').get();
    final favs = List<String>.from(userDoc.data()?['favorite_barbershops']);
    expect(favs, contains('shop123'));
  });

  testWidgets('Favorite Flow: Show in Favorite List Screen', (tester) async {
    // 1. Seed user data with favorite
    await fakeFs.collection('users').doc('user1').update({
      'favorite_barbershops': ['shop123'],
    });

    // 2. Pump Favorite Screen
    await tester.pumpWidget(MaterialApp(
      home: FavoriteBarbershopsScreen(
        firestore: fakeFs,
        testUserId: 'user1',
      ),
    ));
    await tester.pumpAndSettle();

    // 3. Verify List Content
    expect(find.text('Geges Test Shop'), findsOneWidget);
    expect(find.text('Jalan Test No 1'), findsOneWidget);
    
    // 4. Verify Remove Button
    final removeBtn = find.byIcon(Icons.favorite);
    expect(removeBtn, findsOneWidget);

    // 5. Tap Remove
    await tester.tap(removeBtn);
    await tester.pumpAndSettle();

    // 6. Verify Removed from UI
    expect(find.text('Geges Test Shop'), findsNothing);
    expect(find.text('Belum ada barbershop favorit.'), findsOneWidget);

    // 7. Verify Removed from Firestore
    final userDoc = await fakeFs.collection('users').doc('user1').get();
    final favs = List<String>.from(userDoc.data()?['favorite_barbershops']);
    expect(favs, isEmpty);
  });
}
