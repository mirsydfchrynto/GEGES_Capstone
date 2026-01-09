import 'package:flutter_test/flutter_test.dart';
import 'test_utils.dart';

/// Global test setup: disable outgoing network calls by default to catch
/// accidental external requests during unit/widget tests. Integration tests
/// that need network can call `enableNetworkCalls()` in their own setup.
void main() {
  setUpAll(() async {
    disableNetworkCalls();
  });

  tearDownAll(() async {
    enableNetworkCalls();
  });
}
