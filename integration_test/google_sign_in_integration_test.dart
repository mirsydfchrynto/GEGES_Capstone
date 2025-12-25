// integration_test/google_sign_in_integration_test.dart
// Skeleton integration test for Google Sign-In flow.
// NOTE: This test is intentionally interactive/manual and will be skipped unless
// you set the --dart-define=RUN_GOOGLE_INTEGRATION=true when invoking tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:geges_smartbarber/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final runIntegration = const bool.fromEnvironment(
    'RUN_GOOGLE_INTEGRATION',
    defaultValue: false,
  );

  testWidgets(
    'INT-GOOGLE-01: Google Sign-In interactive smoke test',
    (WidgetTester tester) async {
      if (!runIntegration) {
        // Skip unless explicitly enabled to avoid breaking CI and local fast test runs.
        return;
      }

      // Start the app (assumes debug/debuggable build with google-services configured)
      app.main();
      await tester.pumpAndSettle();

      // Navigate to Register screen if your app doesn't start there.
      // TODO: adapt navigation steps below to match your app's initial route.

      // Find the Google sign-up button keyed in UI
      final googleBtn = find.byKey(const Key('register_google_btn'));
      expect(googleBtn, findsOneWidget);

      // Tap the button to open the Google Sign-In flow.
      // Note: On Android/iOS this will launch the Google account picker / browser.
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      // This test is interactive: it expects the tester to complete the Google sign-in using
      // the device UI (select account, grant consent, etc.) and then return to the app.

      // Wait for manual completion: you can detect a successful outcome by looking for
      // app-specific UI such as the presence of "Sign In" on the Login screen or a
      // welcome/home screen element. Update the finder below to match your app.
      final successFinder = find.text('Sign In');

      // Give generous time for manual interaction (e.g., 2 minutes)
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 120));

      expect(successFinder, findsOneWidget);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
