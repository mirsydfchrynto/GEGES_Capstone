import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';

void main() {
  testWidgets('Back button is blocked while tenant payment locked', (tester) async {
    var submitCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PaymentScreen(
          orderId: 'tenant-1',
          totalPrice: 100000,
          tenantId: 'tenant-1',
          tenantPaymentHandler: ({required String tenantId, required String base64, required String userId}) async {
            submitCalled = true;
          },
          submitProofHandler: () async {
            submitCalled = true;
          },
          cancelTenantHandler: ({required String tenantId, required String userId, String? reason}) async {},
          disableTimer: true,
          testUserId: 'user-1',
        ),
      ),
    ));

    // ensure widget is settled
    await tester.pumpAndSettle();
    await tester.pump();

    // debug: print all Text widget data
    final allTexts = tester.widgetList(find.byType(Text)).map((w) => (w as Text).data).toList();
    debugPrint('DBG: all texts -> $allTexts');

    // initial screen shows the tenant upload text (there are two occurrences: section title + action button)
    final submitTextFinder = find.textContaining('Unggah Bukti Pembayaran', findRichText: true);
    expect(submitTextFinder, findsWidgets);

    // tap leading back button - should be blocked and we should still be on Payment screen
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // verify the upload text still exists (we didn't pop)
    expect(submitTextFinder, findsWidgets);

    // press submit (using injected handler) and verify it runs (handler sets flag)
    // Find the ElevatedButton that contains the text 'Unggah Bukti Pembayaran'
    final buttons = find.byType(ElevatedButton);
    final totalButtons = tester.widgetList(buttons).length;
    Finder? submitElevated;
    for (var i = 0; i < totalButtons; i++) {
      final candidate = buttons.at(i);
      final textFound = find.descendant(of: candidate, matching: find.textContaining('Unggah Bukti Pembayaran', findRichText: false));
      if (tester.any(textFound)) {
        submitElevated = candidate;
        break;
      }
    }
    expect(submitElevated, isNotNull);
    await tester.ensureVisible(submitElevated!);
    await tester.tap(submitElevated);
    await tester.pumpAndSettle();

    // since no actual image picker, the button will attempt to run submit which in our case will not perform navigation
    // but we can ensure handler runs by checking flag
    expect(submitCalled, isTrue);
  });

  testWidgets('Cancel flow: confirm dialog, call cancel handler and pop', (tester) async {
    var cancelled = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PaymentScreen(
          orderId: 'tenant-2',
          totalPrice: 120000,
          tenantId: 'tenant-2',
          tenantPaymentHandler: ({required String tenantId, required String base64, required String userId}) async {},
          cancelTenantHandler: ({required String tenantId, required String userId, String? reason}) async {
            cancelled = true;
          },
          disableTimer: true,
          testUserId: 'user-2',
        ),
      ),
    ));

    // ensure widget is settled
    await tester.pumpAndSettle();
    await tester.pump();

    // tap the cancel button
    final cancelFinder = find.byKey(const Key('cancel_registration_button'));
    expect(cancelFinder, findsOneWidget);
    // make sure button is visible (scroll if necessary) then tap
    await tester.ensureVisible(cancelFinder);
    await tester.tap(cancelFinder);
    await tester.pumpAndSettle();

    // Confirm dialog should appear
    expect(find.text('Batalkan Pendaftaran'), findsOneWidget);

    // Ensure the confirm button is visible then tap
    final confirmBtn = find.text('Ya, Batalkan');
    await tester.ensureVisible(confirmBtn);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Cancel handler should have been called
    expect(cancelled, isTrue);

    // Confirm dialog should be dismissed
    expect(find.text('Batalkan Pendaftaran'), findsNothing);
  });
}
