import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_utils.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() {
    disableNetworkCalls();
  });

  tearDownAll(() {
    enableNetworkCalls();
  });

  await testMain();
}
