import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/admin/barber_management_screen.dart';
import 'package:geges_smartbarber/services/barberman_service.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('Bulk set off-day applies and undo works', (tester) async {
    final fs = FakeFirebaseFirestore();
    final shopId = 'shop-test-1';

    // create barber documents
    final b1 = await fs.collection('barbermen').add({
      'name': 'Andi',
      'barbershop_id': shopId,
      'isActive': true,
      'offDays': [],
      'onLeave': false,
      'annualLeaveDays': 12,
    });
    final b2 = await fs.collection('barbermen').add({
      'name': 'Budi',
      'barbershop_id': shopId,
      'isActive': true,
      'offDays': [],
      'onLeave': false,
      'annualLeaveDays': 10,
    });

    final svc = BarbermanService(firestore: fs);

    await tester.pumpWidget(
      MaterialApp(
        home: BarberManagementScreen(
          barbershopId: shopId,
          barbermanService: svc,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the set-off-day icon
    final icon = find.byIcon(Icons.event_busy_outlined);
    expect(icon, findsOneWidget);
    await tester.tap(icon);
    await tester.pumpAndSettle();

    // Dialog should appear - choose a day from the dropdown
    expect(find.text('Pilih hari'), findsOneWidget);

    // Open the dropdown
    await tester.tap(find.byType(DropdownButton<DayOfWeek>));
    await tester.pumpAndSettle();

    // Select 'monday' option (enum name)
    await tester.tap(find.text('monday').last);
    await tester.pumpAndSettle();

    // Confirm with Terapkan button
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();

    // Check that Firestore docs now contain 'monday' in offDays
    final after1 = await fs.collection('barbermen').doc(b1.id).get();
    final after2 = await fs.collection('barbermen').doc(b2.id).get();
    expect((after1.data()?['offDays'] as List).contains('monday'), true);
    expect((after2.data()?['offDays'] as List).contains('monday'), true);

    // SnackBar should be shown with 'Undo' action
    expect(find.text('Hari libur diterapkan ke semua barber'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // Verify revert
    final rev1 = await fs.collection('barbermen').doc(b1.id).get();
    final rev2 = await fs.collection('barbermen').doc(b2.id).get();
    expect(
      ((rev1.data()?['offDays'] as List?) ?? []).contains('monday'),
      false,
    );
    expect(
      ((rev2.data()?['offDays'] as List?) ?? []).contains('monday'),
      false,
    );
  });
}
