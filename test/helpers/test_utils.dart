import 'dart:async';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Utility: pump until there are no scheduled frames or timeout.
Future<void> pumpAndSettleWithTimeout(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
    // no scheduled frame -> settled
    if (!tester.binding.hasScheduledFrame) return;
  }
  throw TimeoutException(
    'pumpAndSettleWithTimeout exceeded ${timeout.inSeconds}s',
  );
}

/// Create a lightweight temp file with given bytes; returns the [File] instance.
Future<File> createTempFile(
  List<int> bytes, {
  String prefix = 'tmp',
  String suffix = '.dat',
}) async {
  final dir = Directory.systemTemp.createTempSync(prefix);
  final f = File(
    '${dir.path}/file${DateTime.now().millisecondsSinceEpoch}$suffix',
  );
  await f.writeAsBytes(bytes);
  return f;
}

/// Returns a fresh [FakeFirebaseFirestore] instance for tests.
FakeFirebaseFirestore makeFakeFirestore() => FakeFirebaseFirestore();

// -----------------------
// Network safety helpers
// -----------------------

class _NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw UnsupportedError('Network calls are disabled during tests.');
  }
}

/// Prevent any outgoing network calls by setting a global [HttpOverrides].
/// Use `enableNetworkCalls()` to restore the default behavior.
void disableNetworkCalls() {
  HttpOverrides.global = _NoNetworkHttpOverrides();
}

/// Restore network capabilities for tests that require real HTTP access.
void enableNetworkCalls() {
  HttpOverrides.global = null;
}
