import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/customer/appointment_screen.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('select paid barber updates total price', (tester) async {
    final fs = FakeFirebaseFirestore();
    // create barber docs
    await fs.collection('barbermen').doc('b1').set({
      'name': 'Andi',
      'barbershop_id': 'shop123',
      'avg_duration': 30,
      'rating': 4.5,
      'isActive': true,
    });

    final shop = Barbershop(
      id: 'shop123',
      name: 'Toko',
      addres: 'Jl Test',
      rating: 5.0,
      imageUrl: '',
      services: [],
      openHour: 9,
      closeHour: 21,
      isOpen: true,
    );

    final svc = BarbershopService(firestore: fs);
    final queueSvc = QueueService(firestore: fs);

    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentScreen(
          barbershop: shop,
          barbershopService: svc,
          queueService: queueSvc,
        ),
      ),
    );

    // wait for futures to resolve
    await tester.pumpAndSettle();

    // find barber name
    expect(find.text('Andi'), findsOneWidget);

    // ensure visible then tap barber tile
    await tester.ensureVisible(find.text('Andi'));
    await tester.tap(find.text('Andi'));
    await tester.pumpAndSettle();

    // dialog should appear; tap 'Pilih Barber (Rp 5.000)'
    expect(find.text('Pilih Barber (Rp 5.000)'), findsOneWidget);
    await tester.tap(find.text('Pilih Barber (Rp 5.000)'));
    await tester.pumpAndSettle();

    // bottom shows total, which should include 5.000
    expect(find.textContaining('5.000'), findsWidgets);
  });
}
