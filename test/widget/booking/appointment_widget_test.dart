import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/customer/appointment_screen.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../mocks/auth_service_test.mocks.dart';
import 'package:network_image_mock/network_image_mock.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('select paid barber updates total price', (tester) async {
    mockNetworkImagesFor(() async {
      final fs = FakeFirebaseFirestore();
      final mockAuth = MockFirebaseAuth();
      
      // 1. Setup Data
      await fs.collection('services').doc('s1').set({
        'name': 'Cukur Rambut',
        'price': 20000,
        'defaultDuration': 30,
        'isActive': true,
      });

      await fs.collection('barbermen').doc('b1').set({
        'name': 'Andi',
        'barbershop_id': 'shop123',
        'avg_duration': 30,
        'rating': 4.5,
        'isActive': true,
        'imageUrl': 'http://test/img.jpg',
      });

      final shop = Barbershop(
        id: 'shop123',
        name: 'Toko',
        addres: 'Jl Test',
        imageUrl: '',
        services: ['s1'],
        openHour: 9,
        closeHour: 21,
        isOpen: true,
        barberSelectionFee: 5000,
      );

      final svc = BarbershopService(firestore: fs);
      final queueSvc = QueueService(firestore: fs, auth: mockAuth);

      // 2. Pump Widget
      await tester.pumpWidget(
        wrapWithLocalization(AppointmentScreen(
            barbershop: shop,
            barbershopService: svc,
            queueService: queueSvc,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 3. Step 0: Select Service
      final serviceItem = find.text('Cukur Rambut');
      await tester.ensureVisible(serviceItem);
      await tester.tap(serviceItem);
      await tester.pump();

      final btnLanjut = find.text('LANJUT');
      await tester.ensureVisible(btnLanjut);
      await tester.tap(btnLanjut);
      await tester.pumpAndSettle();

      // 4. Step 1: Select Barber
      final premiumOption = find.textContaining('Pilih Barber Favorit');
      await tester.ensureVisible(premiumOption);
      await tester.tap(premiumOption);
      await tester.pumpAndSettle();

      final barberItem = find.text('Andi');
      await tester.scrollUntilVisible(
        barberItem,
        500.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(barberItem);
      await tester.pump();

      // 5. Verify Total Price (Service 20k + Fee 5k = 25k)
      // The UI shows "Total Estimasi ... Rp 25.000"
      expect(find.textContaining(RegExp(r'25[.,]000')), findsOneWidget);
    });
  });
}
