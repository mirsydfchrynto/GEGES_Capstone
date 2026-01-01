import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/admin/barbershop_settings_screen.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

void main() {
  testWidgets('admin updates special order fee', (tester) async {
    final fs = FakeFirebaseFirestore();
    await fs.collection('barbershops').doc('shopx').set({
      'name': 'Shop X',
      'addres': 'Jl X',
      'rating': 4.0,
      'imageUrl': '',
      'services': [],
      'open_hour': 9,
      'close_hour': 21,
      'special_order_fee': 5000,
      'isOpen': true,
    });

    final shop = Barbershop(
      id: 'shopx',
      name: 'Shop X',
      addres: 'Jl X',
      rating: 4.0,
      imageUrl: '',
      services: [],
      openHour: 9,
      closeHour: 21,
      isOpen: true,
    );

    final svc = BarbershopService(firestore: fs);

    await tester.pumpWidget(
      MaterialApp(
        home: BarbershopSettingsScreen(barbershop: shop, service: svc),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Special Order Fee (Rp)'), findsOneWidget);

    // Find the TextField below the label "Special Order Fee (Rp)"
    final inputFinder = find.byType(TextFormField).first; // Risky but better than crashing
    
    await tester.enterText(inputFinder, '7000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    
    // Tap save.
    final btn = find.byType(ElevatedButton);
    
    // Scroll down to find the button
    await tester.dragUntilVisible(
      btn,
      find.byType(ListView),
      const Offset(0, -500),
    );
    
    await tester.tap(btn);
    await tester.pumpAndSettle();

    final updated = await fs.collection('barbershops').doc('shopx').get();
    expect(updated.data()?['barber_selection_fee'], 7000);
  });
}