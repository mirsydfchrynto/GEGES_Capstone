import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/screens/admin/barbershop_settings_screen.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

void main() {
  testWidgets('BarbershopSettingsScreen shows data', (WidgetTester tester) async {
    final fakeFs = FakeFirebaseFirestore();
    final svc = BarbershopService(firestore: fakeFs);

    final shop = Barbershop(
      id: 'shop1',
      name: 'Geges Shop',
      addres: 'Melati Street',
      rating: 4.5,
      imageUrl: '',
      services: [],
      openHour: 9,
      closeHour: 21,
      isOpen: true,
      facilities: ['AC', 'Wifi'],
    );

    await tester.pumpWidget(MaterialApp(
      home: BarbershopSettingsScreen(barbershop: shop, barbershopService: svc),
    ));

    expect(find.text('Geges Shop'), findsOneWidget);
    expect(find.text('Melati Street'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('Wifi'), findsOneWidget);
  });
}
