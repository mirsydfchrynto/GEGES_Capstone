import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/screens/admin/barbershop_gallery_screen.dart';

void main() {
  testWidgets('BarbershopGalleryScreen renders correctly', (WidgetTester tester) async {
    final shop = Barbershop(
      id: 'shop1',
      name: 'Test Shop',
      addres: 'Address',
      rating: 4.5,
      imageUrl: '',
      services: [],
      openHour: 9,
      closeHour: 21,
      isOpen: true,
      galleryUrls: [],
    );

    await tester.pumpWidget(MaterialApp(
      home: BarbershopGalleryScreen(barbershop: shop),
    ));

    expect(find.text('Barbershop Album'), findsOneWidget);
    expect(find.text('No photos in gallery.'), findsOneWidget);
  });
}