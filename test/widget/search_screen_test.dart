import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/customer/search_screen.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

// Mock CachedNetworkImage to avoid 400 errors in widget tests
class MockCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  const MockCachedNetworkImage({super.key, required this.imageUrl});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  late FakeFirebaseFirestore fakeFs;
  late BarbershopService service;

  setUp(() async {
    fakeFs = FakeFirebaseFirestore();
    service = BarbershopService(firestore: fakeFs);

    // Seed data
    await fakeFs.collection('barbershops').doc('shop1').set({
      'name': 'Geges Barber',
      'addres': 'Jalan Mawar',
      'isOpen': true,
      'services': ['Haircut'],
      'rating': 4.5,
      'imageUrl': 'http://test.com/img.jpg',
    });
  });

  testWidgets('SearchScreen UI Flow', (tester) async {
    // Inject service
    await tester.pumpWidget(MaterialApp(
      home: SearchScreen(barbershopService: service),
    ));

    // 1. Initial State
    expect(find.text('Cari barbershop favoritmu'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // 2. Type Query
    await tester.enterText(find.byType(TextField), 'Geges');
    await tester.pump(); // Rebuild for typing

    // Wait for Debounce (500ms) + Async Search
    await tester.pump(const Duration(milliseconds: 600)); 
    await tester.pump(); // Rebuild for loading state
    await tester.pumpAndSettle(); // Finish loading

    // 3. Verify Results
    expect(find.text('Geges Barber'), findsOneWidget);
    expect(find.text('Jalan Mawar'), findsOneWidget);

    // 4. Test Clear Button
    final clearBtn = find.byIcon(Icons.clear);
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();

    // Verify Cleared
    expect(find.text(''), findsOneWidget); // Empty text field
    expect(find.text('Cari barbershop favoritmu'), findsOneWidget);

    // 5. Test Not Found
    await tester.enterText(find.byType(TextField), 'UnknownShop');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tidak ditemukan hasil'), findsOneWidget);
  });
}
