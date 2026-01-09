import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import '../../mocks/queue_service_auto_cancel_test.mocks.dart';
import '../../mocks/auth_service_test.mocks.dart' as auth_mocks;

@GenerateNiceMocks([
  MockSpec<FirebaseFirestore>(),
  MockSpec<CollectionReference<Map<String, dynamic>>>(as: #MockCollectionRef),
  MockSpec<DocumentReference<Map<String, dynamic>>>(as: #MockDocRef),
  MockSpec<DocumentSnapshot<Map<String, dynamic>>>(as: #MockDocSnap),
  MockSpec<Query<Map<String, dynamic>>>(as: #MockQuery),
  MockSpec<QuerySnapshot<Map<String, dynamic>>>(as: #MockQuerySnapshot),
  MockSpec<QueryDocumentSnapshot<Map<String, dynamic>>>(as: #MockQueryDocSnap),
])

void main() {
  late MockFirebaseFirestore mockFs;
  late auth_mocks.MockFirebaseAuth mockAuth;
  late MockCollectionRef mockQueuesColl;
  late MockQuery mockQuery;
  late MockQuerySnapshot mockQuerySnap;
  late MockQueryDocSnap mockDocSnap;
  late MockDocRef mockDocRef;

  setUp(() {
    mockFs = MockFirebaseFirestore();
    mockAuth = auth_mocks.MockFirebaseAuth();
    mockQueuesColl = MockCollectionRef();
    mockQuery = MockQuery();
    final mockQueryStatus = MockQuery();
    final mockQueryFinal = MockQuery();
    mockQuerySnap = MockQuerySnapshot();
    mockDocSnap = MockQueryDocSnap();
    mockDocRef = MockDocRef();

    when(mockFs.collection('queues')).thenReturn(mockQueuesColl);
    
    // Loose matchers for where
    when(mockQueuesColl.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQuery);

    when(mockQuery.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQueryStatus);
    when(mockQueryStatus.where(any, isLessThan: anyNamed('isLessThan'))).thenReturn(mockQueryFinal);

    // Default responses
    when(mockQueryFinal.get(any)).thenAnswer((_) async => mockQuerySnap);
    when(mockQueryFinal.get()).thenAnswer((_) async => mockQuerySnap);
    
    // For fallback queries
    when(mockQuery.get(any)).thenAnswer((_) async => mockQuerySnap);
    when(mockQuery.get()).thenAnswer((_) async => mockQuerySnap);

    when(mockQuerySnap.docs).thenReturn([mockDocSnap]);
    when(mockQuerySnap.size).thenReturn(1);
    when(mockDocSnap.reference).thenReturn(mockDocRef);
  });

  test('cancelExpiredWaitingQueuesForCustomer cancels expired waiting queues', () async {
    when(mockDocSnap.data()).thenReturn({
      'status': 'waiting',
      'payment_deadline': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 5))),
    });

    final svc = QueueService(firestore: mockFs, auth: mockAuth);
    final count = await svc.cancelExpiredWaitingQueuesForCustomer('user_x');

    expect(count, 1);
    verify(mockDocRef.update(argThat(containsPair('status', 'cancelled')))).called(1);
  });

  test('cancelExpiredAwaitingPaymentQueuesForCustomer cancels expired awaiting_payment queues', () async {
    when(mockDocSnap.data()).thenReturn({
      'status': 'awaiting_payment',
      'payment_deadline': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 1))),
    });

    final svc = QueueService(firestore: mockFs, auth: mockAuth);
    final count = await svc.cancelExpiredAwaitingPaymentQueuesForCustomer('user_y');

    expect(count, 1);
    verify(mockDocRef.update(argThat(containsPair('status', 'cancelled')))).called(1);
  });

  test('fallback cancels expired waiting queues when Firestore requires an index', () async {
    // Force exception on primary query
    final mockQueryFinal = MockQuery();
    // Re-setup specific chain to fail
    when(mockQuery.where(any, isEqualTo: 'waiting')).thenReturn(mockQueryFinal);
    when(mockQueryFinal.where(any, isLessThan: anyNamed('isLessThan'))).thenReturn(mockQueryFinal);
    when(mockQueryFinal.get()).thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'failed-precondition'));

    // Fallback data (queried via simpler query in catch block)
    // The code queries collection.where('customer_id', ...).get() in fallback.
    // We already mocked where('customer_id', ...) -> mockQuery.
    // And mockQuery.get() -> mockQuerySnap.
    when(mockDocSnap.data()).thenReturn({
      'status': 'waiting',
      'payment_deadline': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 10))),
    });

    final svc = QueueService(firestore: mockFs, auth: mockAuth);
    final count = await svc.cancelExpiredWaitingQueuesForCustomer('user_x');

    expect(count, 1);
    verify(mockDocRef.update(argThat(containsPair('status', 'cancelled')))).called(1);
  });

  test('fallback cancels expired awaiting_payment when Firestore requires an index', () async {
    // Force exception
    final mockQueryFinal = MockQuery();
    when(mockQuery.where(any, isEqualTo: 'awaiting_payment')).thenReturn(mockQueryFinal);
    when(mockQueryFinal.where(any, isLessThan: anyNamed('isLessThan'))).thenReturn(mockQueryFinal);
    when(mockQueryFinal.get()).thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'failed-precondition'));

    when(mockDocSnap.data()).thenReturn({
      'status': 'awaiting_payment',
      'payment_deadline': Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 20))),
    });

    final svc = QueueService(firestore: mockFs, auth: mockAuth);
    final count = await svc.cancelExpiredAwaitingPaymentQueuesForCustomer('user_y');

    expect(count, 1);
    verify(mockDocRef.update(argThat(containsPair('status', 'cancelled')))).called(1);
  });
}