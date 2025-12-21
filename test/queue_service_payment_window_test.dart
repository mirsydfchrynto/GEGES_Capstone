import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

@GenerateMocks([FirebaseFirestore, CollectionReference, DocumentReference, DocumentSnapshot])
import 'queue_service_payment_window_test.mocks.dart';

void main() {
  late MockFirebaseFirestore mockFs;
  late MockCollectionReference<Map<String, dynamic>> mockColl;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnap;

  setUp(() {
    mockFs = MockFirebaseFirestore();
    mockColl = MockCollectionReference<Map<String, dynamic>>();
    mockDocRef = MockDocumentReference<Map<String, dynamic>>();
    mockDocSnap = MockDocumentSnapshot<Map<String, dynamic>>();

    when(mockFs.collection('barbershops')).thenReturn(mockColl);
    when(mockColl.doc(any)).thenReturn(mockDocRef);
  });

  test('returns default when barbershop doc missing or has no value', () async {
    when(mockDocRef.get()).thenAnswer((_) async => mockDocSnap);
    when(mockDocSnap.data()).thenReturn(null);

    final svc = QueueService(firestore: mockFs);
    final window = await svc.getPaymentWindowForBarbershop('shop_1');
    expect(window, QueueService.defaultPaymentWindowMinutes);
  });

  test('returns override when document has payment_window_minutes as int', () async {
    when(mockDocRef.get()).thenAnswer((_) async => mockDocSnap);
    when(mockDocSnap.data()).thenReturn({'payment_window_minutes': 15});

    final svc = QueueService(firestore: mockFs);
    final window = await svc.getPaymentWindowForBarbershop('shop_2');
    expect(window, 15);
  });

  test('returns override when document has paymentWindowMinutes as string', () async {
    when(mockDocRef.get()).thenAnswer((_) async => mockDocSnap);
    when(mockDocSnap.data()).thenReturn({'paymentWindowMinutes': '20'});

    final svc = QueueService(firestore: mockFs);
    final window = await svc.getPaymentWindowForBarbershop('shop_3');
    expect(window, 20);
  });

  test('adminConfirmRequest uses per-shop window when setting payment_deadline', () async {
    // Prepare queues collection mock
    final mockQueuesColl = MockCollectionReference<Map<String, dynamic>>();
    final mockQueueRef = MockDocumentReference<Map<String, dynamic>>();
    final mockQueueSnap = MockDocumentSnapshot<Map<String, dynamic>>();

    when(mockFs.collection('queues')).thenReturn(mockQueuesColl);
    when(mockQueuesColl.doc('q_1')).thenReturn(mockQueueRef);
    when(mockQueueRef.get()).thenAnswer((_) async => mockQueueSnap);
    when(mockQueueSnap.data()).thenReturn({'barbershop_id': 'shop_override'});

    // Prepare barbershops collection mock (override = 7 minutes)
    final mockBsColl = MockCollectionReference<Map<String, dynamic>>();
    final mockBsRef = MockDocumentReference<Map<String, dynamic>>();
    final mockBsSnap = MockDocumentSnapshot<Map<String, dynamic>>();

    when(mockFs.collection('barbershops')).thenReturn(mockBsColl);
    when(mockBsColl.doc('shop_override')).thenReturn(mockBsRef);
    when(mockBsRef.get()).thenAnswer((_) async => mockBsSnap);
    when(mockBsSnap.data()).thenReturn({'payment_window_minutes': 7});

    final svc = QueueService(firestore: mockFs);

    await svc.adminConfirmRequest('q_1', adminUid: 'admin_1');

    final captured = verify(mockQueueRef.update(captureAny)).captured.single as Map;
    expect(captured['status'], 'awaiting_payment');
    expect(captured['request_status'], 'approved');
    expect(captured['verified_by'], 'admin_1');
    expect(captured['payment_deadline'], isA<Timestamp>());
    final due = (captured['payment_deadline'] as Timestamp).toDate();
    final diff = due.difference(DateTime.now()).inMinutes;
    expect(diff, inInclusiveRange(6, 8));
  });
}
