import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/screens/customer/appointment_screen.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';

@GenerateNiceMocks([
  MockSpec<BarbershopService>(), 
  MockSpec<QueueService>()
])
import 'appointment_notes_test.mocks.dart';

void main() {
  late MockBarbershopService mockBarbershopService;
  late MockQueueService mockQueueService;

  setUp(() {
    mockBarbershopService = MockBarbershopService();
    mockQueueService = MockQueueService();
  });

  Widget createScreen({String? initialNote}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppointmentScreen(
        barbershop: Barbershop(
          id: 'shop-1',
          name: 'Test Shop',
          addres: 'Address',
          openHour: 9,
          closeHour: 21,
          services: ['s1', 's2'],
          imageUrl: 'img',
          isActive: true,
          isOpen: true,
          barberSelectionFee: 5000,
          paymentWindowMinutes: 30,
        ),
        barbershopService: mockBarbershopService,
        queueService: mockQueueService,
        initialStyleNote: initialNote,
      ),
    );
  }

  final service1 = Service(id: 's1', name: 'Premium Haircut', price: 50000, defaultDuration: 45, description: 'Desc 1', isActive: true);
  final service2 = Service(id: 's2', name: 'Shaving', price: 30000, defaultDuration: 20, description: 'Desc 2', isActive: true);

  testWidgets('Auto-selects Haircut service and fills note when initialStyleNote provided', (WidgetTester tester) async {
    when(mockBarbershopService.getAllServices()).thenAnswer((_) async => [service1, service2]);

    await tester.pumpWidget(createScreen(initialNote: 'Fade Style'));
    await tester.pumpAndSettle(); // Wait for future builder

    // 1. Check if 'Premium Haircut' is selected (checkbox checked)
    // Find the row with 'Premium Haircut' then find the checkbox inside or near it
    final serviceFinder = find.text('Premium Haircut');
    expect(serviceFinder, findsOneWidget);
    
    // In our UI structure, checkbox is a sibling in a row. 
    // We can check if the internal list _selectedServices has it, but this is a widget test.
    // Instead we check if the TextField appeared (it only appears if selected).
    
    // 2. Check if Note TextField appeared
    final noteField = find.byType(TextFormField);
    expect(noteField, findsOneWidget);

    // 3. Check if text is pre-filled
    expect(find.text('Fade Style'), findsOneWidget);
  });

  testWidgets('Does not auto-select if no initial note', (WidgetTester tester) async {
    when(mockBarbershopService.getAllServices()).thenAnswer((_) async => [service1, service2]);

    await tester.pumpWidget(createScreen(initialNote: null));
    await tester.pumpAndSettle();

    // No text fields should be visible initially
    expect(find.byType(TextFormField), findsNothing);
  });
}
