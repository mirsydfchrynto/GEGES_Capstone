import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/customer/home_screen.dart';
import 'package:geges_smartbarber/services/location_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/models/promo_banner.dart';
import 'package:mockito/mockito.dart';
import 'package:geolocator/geolocator.dart';
import '../../test_helpers.dart';

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

  @override
  Future<Position?> getCurrentPosition() async {
    return super.noSuchMethod(
      Invocation.method(#getCurrentPosition, []),
      returnValue: Future.value(null), 
      returnValueForMissingStub: Future.value(null),
    );
  }
}

class MockQueueService extends Mock implements QueueService {
  @override
  Stream<int> streamUnreadNotificationCount(String userId) {
    return Stream.value(0);
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
  late MockQueueService mockQueueService;

  setUp(() {
    mockLocationService = MockLocationService();
    mockBarbershopService = MockBarbershopService();
    mockQueueService = MockQueueService();
  });

  Widget createHomeScreen() {
    return wrapWithLocalization(
      HomeScreen(
        locationService: mockLocationService,
        barbershopService: mockBarbershopService,
        queueService: mockQueueService,
        currentUserId: 'test-user',
      ),
    );
  }

  testWidgets('Initial state shows "Menentukan lokasi..." then updates', (WidgetTester tester) async {
    // Ensure large enough screen
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    
    // Arrange
    when(mockLocationService.getCurrentPosition()).thenAnswer((_) async => null);
    when(mockLocationService.getCurrentLocationAddress())
        .thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100)); 
          return 'Jakarta Selatan';
        });
    when(mockBarbershopService.getAllBarbershops(forceRefresh: false))
        .thenAnswer((_) async => <Barbershop>[]);

    // Act
    await tester.pumpWidget(createHomeScreen());
    
    // Give it a frame to layout PageView
    await tester.pump();
    
    // DEBUG: Check all visible texts
    final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
    debugPrint("Visible texts: $texts");

    // Assert Header is visible
    expect(find.text('Lokasi Saya'), findsOneWidget);
    
    // Assert Initial State
    expect(find.text('Menentukan lokasi...'), findsOneWidget);
    
    // Wait for Future and Animation
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle(); // Settle any remaining animations

    // Assert Updated State
    expect(find.text('Jakarta Selatan'), findsOneWidget);
  });

  testWidgets('Tap on "Lokasi Saya" refreshes location', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));

    // Arrange
    when(mockLocationService.getCurrentPosition()).thenAnswer((_) async => null);
    when(mockLocationService.getCurrentLocationAddress())
        .thenAnswer((_) async => 'Jakarta');
    when(mockBarbershopService.getAllBarbershops(forceRefresh: false))
        .thenAnswer((_) async => <Barbershop>[]);

    await tester.pumpWidget(createHomeScreen());
    await tester.pumpAndSettle();
    expect(find.text('Jakarta'), findsOneWidget);

    // Prepare second call
    when(mockLocationService.getCurrentPosition()).thenAnswer((_) async => null);
    when(mockLocationService.getCurrentLocationAddress())
        .thenAnswer((_) async {
           await Future.delayed(const Duration(milliseconds: 100));
           return 'Bandung';
        });

    // Act - Tap the gesture detector
    await tester.tap(find.text('Lokasi Saya'));
    await tester.pump(); // Start animation

    // Verify Loading State
    expect(find.text('Menentukan lokasi...'), findsOneWidget);

    // Finish
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Bandung'), findsOneWidget);
  });
  
  testWidgets('Handles error from service gracefully', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));

    // Arrange
    when(mockLocationService.getCurrentPosition()).thenAnswer((_) async => null);
    when(mockLocationService.getCurrentLocationAddress())
        .thenAnswer((_) async => 'Error System');
    when(mockBarbershopService.getAllBarbershops(forceRefresh: false))
        .thenAnswer((_) async => <Barbershop>[]);

    await tester.pumpWidget(createHomeScreen());
    await tester.pumpAndSettle();

    // Assert
    expect(find.text('Error System'), findsOneWidget);
  });
}
