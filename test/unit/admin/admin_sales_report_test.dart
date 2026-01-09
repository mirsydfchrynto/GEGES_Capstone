import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../mocks/auth_service_test.mocks.dart';
import 'package:geges_smartbarber/screens/admin/sales_report_screen.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late QueueService queueService;

  setUp(() async {
    await initializeDateFormatting('id_ID', null);
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    queueService = QueueService(firestore: fakeFirestore, auth: mockAuth);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: SalesReportScreen(
        barbershopId: 'shop123',
        queueService: queueService,
      ),
    );
  }

  testWidgets('Should display revenue summary correctly', (WidgetTester tester) async {
    final now = DateTime.now();
    
    // 1. Prepare served queues
    await fakeFirestore.collection('queues').add({
      'barbershop_id': 'shop123',
      'status': 'served',
      'total_price': 50000,
      'booking_time': Timestamp.fromDate(now),
      'customer_name': 'Customer A',
    });
    await fakeFirestore.collection('queues').add({
      'barbershop_id': 'shop123',
      'status': 'served',
      'total_price': 75000,
      'booking_time': Timestamp.fromDate(now),
      'customer_name': 'Customer B',
    });
    // Another shop - should not be counted
    await fakeFirestore.collection('queues').add({
      'barbershop_id': 'other_shop',
      'status': 'served',
      'total_price': 100000,
      'booking_time': Timestamp.fromDate(now),
    });

    // 2. Build widget
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // 3. Verify Revenue (50k + 75k = 125k)
    expect(find.textContaining('125,000'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // Count of transactions
    
    // 4. Verify transaction list
    expect(find.text('Customer A'), findsOneWidget);
    expect(find.text('Customer B'), findsOneWidget);
  });

  testWidgets('Should filter by date correctly (Monthly)', (WidgetTester tester) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);

    await fakeFirestore.collection('queues').add({
      'barbershop_id': 'shop123',
      'status': 'served',
      'total_price': 100000,
      'booking_time': Timestamp.fromDate(now),
      'customer_name': 'Today Customer',
    });
    await fakeFirestore.collection('queues').add({
      'barbershop_id': 'shop123',
      'status': 'served',
      'total_price': 50000,
      'booking_time': Timestamp.fromDate(lastMonth),
      'customer_name': 'Old Customer',
    });

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Initial filter is Daily -> should show 100k (card + item)
    expect(find.textContaining('100,000'), findsNWidgets(2));
    expect(find.text('1'), findsOneWidget);

    // Switch to Monthly (Assumes today is in current month)
    // Old Customer is in last month, so Monthly view should still only show 100k if looking at current month.
    // Wait, the logic in SalesReportScreen uses _selectedDate (now) for Month.
    
    await tester.tap(find.text('Bulanan'));
    await tester.pumpAndSettle();
    
    // Revenue card AND transaction item
    expect(find.textContaining('100,000'), findsNWidgets(2));
    expect(find.text('Today Customer'), findsOneWidget);
    expect(find.text('Old Customer'), findsNothing);
  });
}
