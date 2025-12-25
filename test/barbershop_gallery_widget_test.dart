import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/admin/barbershop_gallery_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  testWidgets('Photo card opens preview and contains CachedNetworkImage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoCard(
            imageUrl: 'https://example.invalid/url.jpg',
            onDelete: () {},
          ),
        ),
      ),
    );

    // Tap the image to open preview
    expect(find.byType(PhotoCard), findsOneWidget);
    await tester.tap(find.byType(PhotoCard));
    await tester.pump(const Duration(milliseconds: 100));

    // Preview dialog should be shown
    expect(find.byType(Dialog), findsOneWidget);
    // CachedNetworkImage should exist inside preview
    expect(find.byType(CachedNetworkImage), findsWidgets);
  });
}
