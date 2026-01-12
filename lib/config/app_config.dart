import 'package:flutter/foundation.dart';

enum Environment { dev, prod }

class AppConfig {
  static Environment get environment {
    return kReleaseMode ? Environment.prod : Environment.dev;
  }

  static String get appName {
    return environment == Environment.prod ? 'GEGES SmartBarber' : 'GEGES Dev';
  }

  static bool get enableLogging {
    return environment == Environment.dev;
  }
}
