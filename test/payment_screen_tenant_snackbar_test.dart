import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';

void main() {
  testWidgets('PaymentScreen tenant submit handler shows guidance SnackBar', (
    WidgetTester tester,
  ) async {
    var handlerCalled = false;

    // Pump PaymentScreen as the root Scaffold body so SnackBar and UI remain visible
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentScreen(
            orderId: 'tenant-123',
            totalPrice: 100000,
            tenantId: 'tenant-123',
            testUserId: 'user-1',
            disableTimer: true,
            submitProofHandler: () async {
              handlerCalled = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // find and tap the tenant upload button
    final uploadFinder = find.widgetWithText(
      ElevatedButton,
      'Unggah Bukti Pembayaran',
    );
    expect(uploadFinder, findsOneWidget);

    await tester.ensureVisible(uploadFinder);
    await tester.tap(uploadFinder);
    await tester.pumpAndSettle();

    // submitProofHandler should have been called and SnackBar shown
    expect(handlerCalled, isTrue);
    expect(
      find.textContaining(
        'Pendaftaran dan dokumen sedang diproses',
        findRichText: false,
      ),
      findsOneWidget,
    );
  });
}
