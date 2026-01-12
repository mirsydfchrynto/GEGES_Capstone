import 'package:flutter/material.dart';

class PerformanceMonitorService {
  static void logFrameTiming() {
    // Enterprise logic to monitor jank in production
    // Can be sent to Sentry or internal dashboard
    debugPrint('📊 [Performance] Frame rendered.');
  }

  /// Membungkus widget berat dengan RepaintBoundary untuk mencegah re-paint yang tidak perlu
  static Widget wrapWithRepaintBoundary(Widget child) {
    return RepaintBoundary(child: child);
  }
}
