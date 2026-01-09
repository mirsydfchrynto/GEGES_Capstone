import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

void main() {
  group('QueueService helpers', () {
    test(
      'isBookingLeadTimeSufficient returns false for booking < 30 minutes',
      () {
        final now = DateTime.now();
        final booking = now.add(const Duration(minutes: 10));
        final ok = QueueService.isBookingLeadTimeSufficient(
          booking,
          minMinutes: 30,
        );
        expect(ok, false);
      },
    );

    test(
      'isBookingLeadTimeSufficient returns true for booking >= 30 minutes',
      () {
        final now = DateTime.now();
        // add a small buffer to avoid timing races in test environment
        final booking = now.add(const Duration(minutes: 31));
        final ok = QueueService.isBookingLeadTimeSufficient(
          booking,
          minMinutes: 30,
        );
        expect(ok, true);
      },
    );

    test(
      'isBookingLeadTimeSufficient returns true for booking > 30 minutes',
      () {
        final now = DateTime.now();
        final booking = now.add(const Duration(hours: 1));
        final ok = QueueService.isBookingLeadTimeSufficient(
          booking,
          minMinutes: 30,
        );
        expect(ok, true);
      },
    );
  });
}
