import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/models/queue.dart';

void main() {
  group('Queue Model Service Notes', () {
    test('Should parse service_notes from Firestore correctly', () {
      // Placeholder test
    });

    test('toJson should include service_notes', () {
      final queue = Queue(
        id: '1',
        barbershopId: 's1',
        customerId: 'c1',
        barbermanId: 'b1',
        bookingTime: Timestamp.now(),
        status: QueueStatus.waiting,
        requestStatus: RequestStatus.pending,
        serviceNotes: {'s1': 'Note 1'}
      );

      final json = queue.toJson();
      expect(json['service_notes'], {'s1': 'Note 1'});
    });

    test('copyWith should update service_notes', () {
      final queue = Queue(
        id: '1',
        barbershopId: 's1',
        customerId: 'c1',
        barbermanId: 'b1',
        bookingTime: Timestamp.now(),
        status: QueueStatus.waiting,
        requestStatus: RequestStatus.pending,
      );

      final updated = queue.copyWith(serviceNotes: {'s2': 'Note 2'});
      expect(updated.serviceNotes, {'s2': 'Note 2'});
    });
  });
}
