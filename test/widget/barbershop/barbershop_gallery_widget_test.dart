import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/screens/admin/barbershop_gallery_screen.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

void main() {
  testWidgets('BarbershopGalleryScreen renders correctly', (WidgetTester tester) async {
    final fakeFs = FakeFirebaseFirestore();
    final svc = BarbershopService(firestore: fakeFs);

    final shop = Barbershop(
      id: 'shop1',
      name: 'Test Shop',
      addres: 'Address',
      imageUrl: '',
      services: [],
      openHour: 9,
      closeHour: 21,
      isOpen: true,
      galleryUrls: [],
    );

    await tester.pumpWidget(MaterialApp(
      home: BarbershopGalleryScreen(barbershop: shop, barbershopService: svc),
    ));

    expect(find.text('Barbershop Album'), findsOneWidget);
    expect(find.text('No photos in gallery.'), findsOneWidget);
  });
}