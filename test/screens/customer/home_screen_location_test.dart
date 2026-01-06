import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/customer/home_screen.dart';
import 'package:geges_smartbarber/services/location_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/models/promo_banner.dart';
import 'package:mockito/mockito.dart';

// Mock Services
class MockLocationService extends Mock implements LocationService {
  @override
  Future<String?> getCurrentLocationAddress() async {
    return super.noSuchMethod(
      Invocation.method(#getCurrentLocationAddress, []),
      returnValue: Future.value('Mock City'),
      returnValueForMissingStub: Future.value('Mock City'),
    );
  }
}

class MockBarbershopService extends Mock implements BarbershopService {
  @override
  Future<List<Barbershop>> getAllBarbershops({bool forceRefresh = false}) async {
    return super.noSuchMethod(
      Invocation.method(#getAllBarbershops, [], {#forceRefresh: forceRefresh}),
      returnValue: Future.value(<Barbershop>[]),
      returnValueForMissingStub: Future.value(<Barbershop>[]),
    );
  }
  
  @override
  Future<List<Service>> getAllServices() async {
    return Future.value(<Service>[]);
  }
  
  @override
  Stream<List<PromoBanner>> getPromoBanners() {
    return Stream.value([
      PromoBanner(id: '1', title: 'Test', subtitle: 'Test', imageUrl: 'path/to/image', isActive: true)
    ]);
  }

  @override
  Future<List<Barbershop>> searchBarbershops(String query) async {
    return Future.value(<Barbershop>[]);
  }
}

void main() {
  late MockLocationService mockLocationService;
  late MockBarbershopService mockBarbershopService;

  setUp(() {
    mockLocationService = MockLocationService();
    mockBarbershopService = MockBarbershopService();
  });

  Widget createHomeScreen() {
    return MaterialApp(
      home: HomeScreen(
        locationService: mockLocationService,
        barbershopService: mockBarbershopService,
      ),
    );
  }

  testWidgets('Initial state shows "Menentukan lokasi..." then updates', (WidgetTester tester) async {
    // Arrange
    when(mockLocationService.getCurrentLocationAddress())
        .thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100)); 
          return 'Jakarta Selatan';
        });
    when(mockBarbershopService.getAllBarbershops(forceRefresh: false))
        .thenAnswer((_) async => <Barbershop>[]);

    // Act
    await tester.pumpWidget(createHomeScreen());
    
    // Assert Initial State
    expect(find.text('Menentukan lokasi...'), findsOneWidget);
    
    // Wait for Future and Animation (manual pump to avoid indeterminate animation timeouts)
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(); // Final build frame

    // Assert Updated State
    expect(find.text('Jakarta Selatan'), findsOneWidget);
  });

  testWidgets('Tap on "Lokasi Saya" refreshes location', (WidgetTester tester) async {
    // Arrange
    // First call returns "Jakarta"
    when(mockLocationService.getCurrentLocationAddress())
        .thenAnswer((_) async => 'Jakarta');
    when(mockBarbershopService.getAllBarbershops(forceRefresh: false))
        .thenAnswer((_) async => <Barbershop>[]);

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Jakarta'), findsOneWidget);

    // Prepare second call
    when(mockLocationService.getCurrentLocationAddress())
        .thenAnswer((_) async {
           await Future.delayed(const Duration(milliseconds: 100));
           return 'Bandung';
        });

    // Act - Tap the gesture detector
    // "Lokasi Saya" is in a Row -> Column -> GestureDetector
    await tester.tap(find.text('Lokasi Saya'));
    await tester.pump(); // Start animation

    // Verify Loading State
    expect(find.text('Menentukan lokasi...'), findsOneWidget);

    // Finish
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Bandung'), findsOneWidget);
  });
  
  testWidgets('Handles error from service gracefully', (WidgetTester tester) async {
    // Arrange
    when(mockLocationService.getCurrentLocationAddress())
        .thenAnswer((_) async => 'Error System');
    when(mockBarbershopService.getAllBarbershops(forceRefresh: false))
        .thenAnswer((_) async => <Barbershop>[]);

    await tester.pumpWidget(createHomeScreen());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    // Assert
    expect(find.text('Error System'), findsOneWidget);
  });
}
