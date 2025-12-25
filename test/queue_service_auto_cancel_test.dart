import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
  DocumentReference,
])
import 'queue_service_auto_cancel_test.mocks.dart';

void main() {
  late MockFirebaseFirestore mockFs;
  late MockCollectionReference<Map<String, dynamic>> mockQueuesColl;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnap;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockDocSnap;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;

  setUp(() {
    mockFs = MockFirebaseFirestore();
    mockQueuesColl = MockCollectionReference<Map<String, dynamic>>();
    mockQuery = MockQuery<Map<String, dynamic>>();
    final mockQueryStatus = MockQuery<Map<String, dynamic>>();
    final mockQueryFinal = MockQuery<Map<String, dynamic>>();
    mockQuerySnap = MockQuerySnapshot<Map<String, dynamic>>();
    mockDocSnap = MockQueryDocumentSnapshot<Map<String, dynamic>>();
    mockDocRef = MockDocumentReference<Map<String, dynamic>>();

    when(mockFs.collection('queues')).thenReturn(mockQueuesColl);
    // When we start with where('customer_id', ...), return mockQuery — this is used for the fallback get().
    when(
      mockQueuesColl.where('customer_id', isEqualTo: anyNamed('isEqualTo')),
    ).thenReturn(mockQuery);

    // For the primary (more-specific) query, chain status and payment_deadline on top of that.
    when(
      mockQuery.where('status', isEqualTo: 'waiting'),
    ).thenReturn(mockQueryStatus);
    when(
      mockQuery.where('status', isEqualTo: 'awaiting_payment'),
    ).thenReturn(mockQueryStatus);
    when(
      mockQueryStatus.where(any, isLessThan: anyNamed('isLessThan')),
    ).thenReturn(mockQueryFinal);

    // By default, the primary final query returns a snapshot (this is overridden in tests when needed)
    when(mockQueryFinal.get()).thenAnswer((_) async => mockQuerySnap);

    // The fallback uses the base mockQuery.get()
    when(mockQuery.get()).thenAnswer((_) async => mockQuerySnap);

    when(mockQuerySnap.docs).thenReturn([mockDocSnap]);
    when(mockDocSnap.reference).thenReturn(mockDocRef);
  });

  test(
    'cancelExpiredWaitingQueuesForCustomer cancels expired waiting queues',
    () async {
      // make get return a doc with a payment_deadline in the past
      when(mockDocSnap.data()).thenReturn({
        'status': 'waiting',
        'payment_deadline': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      });

      final svc = QueueService(firestore: mockFs);

      final count = await svc.cancelExpiredWaitingQueuesForCustomer('user_x');

      expect(count, 1);
      verify(
        mockDocRef.update(argThat(containsPair('status', 'cancelled'))),
      ).called(1);
    },
  );

  test(
    'cancelExpiredAwaitingPaymentQueuesForCustomer cancels expired awaiting_payment queues',
    () async {
      when(mockDocSnap.data()).thenReturn({
        'status': 'awaiting_payment',
        'payment_deadline': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      });

      final svc = QueueService(firestore: mockFs);

      final count = await svc.cancelExpiredAwaitingPaymentQueuesForCustomer(
        'user_y',
      );

      expect(count, 1);
      verify(
        mockDocRef.update(argThat(containsPair('status', 'cancelled'))),
      ).called(1);
    },
  );

  test(
    'fallback cancels expired waiting queues when Firestore requires an index',
    () async {
      // make the primary (status + deadline) query throw a failed-precondition
      when(
        mockQuery.where('status', isEqualTo: 'waiting'),
      ).thenReturn(MockQuery<Map<String, dynamic>>());
      final mockQueryFinal = MockQuery<Map<String, dynamic>>();
      when(
        mockQuery.where('status', isEqualTo: 'waiting'),
      ).thenReturn(mockQueryFinal);
      when(
        mockQueryFinal.where(any, isLessThan: anyNamed('isLessThan')),
      ).thenReturn(mockQueryFinal);
      when(mockQueryFinal.get()).thenThrow(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Needs index',
        ),
      );

      // Fallback query returns a doc with an expired payment_deadline
      when(mockDocSnap.data()).thenReturn({
        'status': 'waiting',
        'payment_deadline': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      });

      final svc = QueueService(firestore: mockFs);

      final count = await svc.cancelExpiredWaitingQueuesForCustomer('user_x');

      expect(count, 1);
      verify(
        mockDocRef.update(argThat(containsPair('status', 'cancelled'))),
      ).called(1);
    },
  );

  test(
    'fallback cancels expired awaiting_payment when Firestore requires an index',
    () async {
      when(
        mockQuery.where('status', isEqualTo: 'awaiting_payment'),
      ).thenReturn(MockQuery<Map<String, dynamic>>());
      final mockQueryFinal = MockQuery<Map<String, dynamic>>();
      when(
        mockQuery.where('status', isEqualTo: 'awaiting_payment'),
      ).thenReturn(mockQueryFinal);
      when(
        mockQueryFinal.where(any, isLessThan: anyNamed('isLessThan')),
      ).thenReturn(mockQueryFinal);
      when(mockQueryFinal.get()).thenThrow(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Needs index',
        ),
      );

      when(mockDocSnap.data()).thenReturn({
        'status': 'awaiting_payment',
        'payment_deadline': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 20)),
        ),
      });

      final svc = QueueService(firestore: mockFs);

      final count = await svc.cancelExpiredAwaitingPaymentQueuesForCustomer(
        'user_y',
      );

      expect(count, 1);
      verify(
        mockDocRef.update(argThat(containsPair('status', 'cancelled'))),
      ).called(1);
    },
  );
}
