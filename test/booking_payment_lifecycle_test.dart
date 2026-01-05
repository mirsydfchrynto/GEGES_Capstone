import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

// Generate Mocks for Firestore classes
@GenerateNiceMocks([
  MockSpec<FirebaseFirestore>(),
  MockSpec<CollectionReference<Map<String, dynamic>>>(as: #MockCollectionRef),
  MockSpec<DocumentReference<Map<String, dynamic>>>(as: #MockDocRef),
  MockSpec<DocumentSnapshot<Map<String, dynamic>>>(as: #MockDocSnap),
  MockSpec<Query<Map<String, dynamic>>>(as: #MockQuery),
  MockSpec<QuerySnapshot<Map<String, dynamic>>>(as: #MockQuerySnapshot),
  MockSpec<QueryDocumentSnapshot<Map<String, dynamic>>>(as: #MockQueryDocSnap),
])
import 'booking_payment_lifecycle_test.mocks.dart';

// Fake Transaction implementation
class FakeTx implements Transaction {
  final MockDocSnap shopSnap;
  final MockDocSnap queueSnap;
  final MockDocRef ref;
  FakeTx({required this.shopSnap, required this.queueSnap, required this.ref});

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(DocumentReference<T> ref) async {
    if (ref.path.contains('barbershops')) return shopSnap as DocumentSnapshot<T>;
    return queueSnap as DocumentSnapshot<T>;
  }

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    this.ref.update(data);
    return this;
  }

  @override
  Transaction set<T extends Object?>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    return this;
  }
}

void main() {
  late MockFirebaseFirestore mockFs;
  late MockFirebaseAuth mockAuth;
  late MockCollectionRef mockQueuesColl;
  late MockDocRef mockQueueRef;
  late MockDocSnap mockQueueSnap;
  late MockCollectionRef mockBsColl;
  late MockDocRef mockBsRef;
  late MockDocSnap mockBsSnap;
  late MockCollectionRef mockBarbermenColl;

  setUp(() {
    mockFs = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockQueuesColl = MockCollectionRef();
    mockQueueRef = MockDocRef();
    mockQueueSnap = MockDocSnap();
    mockBarbermenColl = MockCollectionRef();

    when(mockFs.collection('queues')).thenReturn(mockQueuesColl);
    when(mockFs.collection('barbermen')).thenReturn(mockBarbermenColl);
    when(mockQueuesColl.add(any)).thenAnswer((_) async => mockQueueRef);
    when(mockQueuesColl.doc(any)).thenReturn(mockQueueRef);
    
    // Barbermen query mocks
    final mockBarberQuery = MockQuery();
    final mockBarberSnap = MockQuerySnapshot();
    when(mockBarbermenColl.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockBarberQuery);
    when(mockBarberQuery.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockBarberQuery);
    when(mockBarberQuery.get()).thenAnswer((_) async => mockBarberSnap);
    when(mockBarberSnap.docs).thenReturn([]);

    // Queue query mocks
    final mockQuery = MockQuery();
    final mockQueryTime = MockQuery();
    final mockQueryFinal = MockQuery();
    final mockQuerySnap = MockQuerySnapshot();
    
    // Loose matching for where
    when(mockQueuesColl.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQuery);
    when(mockQuery.where(any, whereIn: anyNamed('whereIn'))).thenReturn(mockQuery);
    when(mockQuery.where(any, isEqualTo: anyNamed('isEqualTo'))).thenReturn(mockQuery);
    when(mockQuery.where(any, isGreaterThanOrEqualTo: anyNamed('isGreaterThanOrEqualTo'))).thenReturn(mockQueryTime);
    when(mockQueryTime.where(any, isLessThanOrEqualTo: anyNamed('isLessThanOrEqualTo'))).thenReturn(mockQueryFinal);
    
    when(mockQueryFinal.get()).thenAnswer((_) async => mockQuerySnap);
    when(mockQuerySnap.docs).thenReturn([]);

    // Barbershop mocks
    mockBsColl = MockCollectionRef();
    mockBsRef = MockDocRef();
    mockBsSnap = MockDocSnap();
    
    when(mockFs.collection('barbershops')).thenReturn(mockBsColl);
    when(mockBsColl.doc(any)).thenReturn(mockBsRef);
    when(mockBsRef.get()).thenAnswer((_) async => mockBsSnap);
    when(mockBsSnap.exists).thenReturn(true);
    when(mockBsSnap.data()).thenReturn({'payment_window_minutes': 15});
  });

  test('full lifecycle: create awaiting_payment then admin confirms to booked', () async {
    when(mockQueueRef.get()).thenAnswer((_) async => mockQueueSnap);
    when(mockQueueSnap.exists).thenReturn(true);

    // Mock runTransaction for createQueue
    // Using simple dynamic return to allow void callbacks
    when(mockFs.runTransaction(any, timeout: anyNamed('timeout'), maxAttempts: anyNamed('maxAttempts')))
      .thenAnswer((inv) async {
        final cb = inv.positionalArguments[0] as Function(Transaction);
        // Execute the callback with our FakeTx
        await cb(FakeTx(shopSnap: mockBsSnap, queueSnap: mockQueueSnap, ref: mockQueueRef));
        return null; // runTransaction returns what the callback returns (void/null here)
      });

    final svc = QueueService(firestore: mockFs, auth: mockAuth);

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final payload = {
      'barbershop_id': 'shop_a',
      'customer_id': 'user_test',
      'barberman_id': 'barb_1',
      'service_ids': [],
      'estimated_duration': 30,
      'booking_time': DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0),
      'status': 'awaiting_payment',
    };

    final ref = await svc.createQueue(payload);
    expect(ref, isNotNull);

    // Simulate proof uploaded
    when(mockQueueSnap.data()).thenReturn({
      'barbershop_id': 'shop_a',
      'status': 'awaiting_payment',
      'payment_proof_base64': 'proof123',
    });

    await svc.adminConfirmPayment('q_auto', adminUid: 'admin_1');

    verify(mockQueueRef.update(any)).called(1);
  });
}
