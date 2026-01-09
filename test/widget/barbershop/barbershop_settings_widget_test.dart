import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/admin/barbershop_settings_screen.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:mockito/mockito.dart';

class MockBarbershopService extends Mock implements BarbershopService {
  @override
  Future<void> updateBarbershopSettings(String id, Map<String, dynamic>? settings) async {
    return super.noSuchMethod(
      Invocation.method(#updateBarbershopSettings, [id, settings]),
      returnValue: Future.value(),
      returnValueForMissingStub: Future.value(),
    );
  }
}

void main() {
  late MockBarbershopService mockService;
  late Barbershop testShop;

  setUp(() {
    mockService = MockBarbershopService();
    testShop = Barbershop(
      id: 'shop1',
      name: 'Test Shop',
      addres: 'Test Address',
      imageUrl: '', // Empty to avoid network call and show placeholder icon
      services: [],
      facilities: ['WiFi'],
      openHour: 9,
      closeHour: 21,
      isActive: true,
      isOpen: true,
    );
  });

  testWidgets('BarbershopSettingsScreen renders fields and saves data', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BarbershopSettingsScreen(barbershop: testShop, barbershopService: mockService),
    ));

    // Verify initial values
    expect(find.text('Test Shop'), findsOneWidget);
    expect(find.text('Test Address'), findsOneWidget);
    expect(find.text('WiFi'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);

    // Verify Image Picker UI exists
    expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
    expect(find.text('Ubah Foto Profil'), findsOneWidget);

    // Modify name
    await tester.enterText(find.widgetWithText(TextFormField, 'Barbershop Name'), 'Updated Shop');
    await tester.pump();

    // Add Facility
    await tester.enterText(find.widgetWithText(TextFormField, 'Add Facility'), 'AC');
    await tester.ensureVisible(find.text('Add')); // Scroll to button
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('AC'), findsOneWidget);

    // Tap Save
    await tester.ensureVisible(find.text('SAVE ALL CHANGES')); // Scroll to button
    await tester.tap(find.text('SAVE ALL CHANGES'));
    await tester.pump(); // Start save
    await tester.pump(); // Finish save (and navigation pop)

    // Verify update call
    verify(mockService.updateBarbershopSettings('shop1', argThat(predicate((Map<String, dynamic> map) {
      return map['name'] == 'Updated Shop' && 
             map['facilities'].contains('AC') &&
             map['facilities'].contains('WiFi');
    })))).called(1);
  });
}