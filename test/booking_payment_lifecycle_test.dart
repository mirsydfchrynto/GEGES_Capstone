import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart'; // Import MockFirebaseAuth

// Reuse generated mocks from the admin payment test
import 'queue_service_admin_payment_test.mocks.dart';

void main() {
  late MockFirebaseFirestore mockFs;
  late MockFirebaseAuth mockAuth; // Declare MockFirebaseAuth
  late MockCollectionReference<Map<String, dynamic>> mockQueuesColl;
  late MockDocumentReference<Map<String, dynamic>> mockQueueRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockQueueSnap;
  late MockCollectionReference<Map<String, dynamic>> mockBsColl;
  late MockDocumentReference<Map<String, dynamic>> mockBsRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockBsSnap;

  setUp(() {
    mockFs = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth(); // Initialize MockFirebaseAuth
    mockQueuesColl = MockCollectionReference<Map<String, dynamic>>();
    mockQueueRef = MockDocumentReference<Map<String, dynamic>>();
    mockQueueSnap = MockDocumentSnapshot<Map<String, dynamic>>();

    when(mockFs.collection('queues')).thenReturn(mockQueuesColl);
    when(mockQueuesColl.add(any)).thenAnswer((inv) async => mockQueueRef);
    when(mockQueuesColl.doc(any)).thenReturn(mockQueueRef);
    // barbershops collection for payment window lookups
    mockBsColl = MockCollectionReference<Map<String, dynamic>>();
    mockBsRef = MockDocumentReference<Map<String, dynamic>>();
    mockBsSnap = MockDocumentSnapshot<Map<String, dynamic>>();
    when(mockFs.collection('barbershops')).thenReturn(mockBsColl);
    when(mockBsColl.doc('shop_a')).thenReturn(mockBsRef);
    when(mockBsRef.get()).thenAnswer((_) async => mockBsSnap);
    when(mockBsSnap.exists).thenReturn(false);
    when(mockBsSnap.data()).thenReturn(null);
  });

  test(
    'full lifecycle: create awaiting_payment then admin confirms to booked',
    () async {
      // createQueue should set payment_deadline when status awaiting_payment
      when(mockQueueRef.get()).thenAnswer((_) async => mockQueueSnap);
      when(mockQueueSnap.exists).thenReturn(true);

      // Simulate runTransaction to call the callback and return our mocked ref
      when(
        mockFs.runTransaction(
          any,
          timeout: anyNamed('timeout'),
          maxAttempts: anyNamed('maxAttempts'),
        ),
      ).thenAnswer((inv) async {
        final cb = inv.positionalArguments[0] as dynamic;
        await cb(MockTransaction());
        return mockQueueRef;
      });

      final svc = QueueService(firestore: mockFs, auth: mockAuth);

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final payload = {
        'barbershop_id': 'shop_a',
        'customer_id': 'user_test',
        'barberman_id': 'barb_1',
        'service_ids': [],
        'estimated_duration': 30,
        'booking_time': DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          10,
          0,
        ),
        'status': 'awaiting_payment',
      };

      final ref = await svc.createQueue(payload);
      expect(ref, mockQueueRef);

      // Now simulate that the queue doc contains payment proof and awaiting_payment status
      when(mockQueueSnap.data()).thenReturn({
        'status': 'awaiting_payment',
        'payment_proof_base64': 'proof123',
      });

      // Stub runTransaction for adminConfirmPayment to execute callback with a concrete fake tx
      when(
        mockFs.runTransaction(
          any,
          timeout: anyNamed('timeout'),
          maxAttempts: anyNamed('maxAttempts'),
        ),
      ).thenAnswer((inv) async {
        final cb = inv.positionalArguments[0] as dynamic;
        final tx = FakeTx(mockQueueSnap, mockQueueRef);
        await cb(tx);
        return Future<Null>.value(null);
      });

      await svc.adminConfirmPayment('q_auto', adminUid: 'admin_1');

      // Verify that update was called to set status booked and record confirm user
      verify(mockQueueRef.update(captureAny)).called(1);
    },
  );
}

/// Minimal mock Transaction implementation for runTransaction callbacks in tests.
class MockTransaction extends Mock implements Transaction {}

class FakeTx implements Transaction {
  final MockDocumentSnapshot<Map<String, dynamic>> snap;
  final MockDocumentReference<Map<String, dynamic>> ref;
  FakeTx(this.snap, this.ref);

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async => snap as DocumentSnapshot<T>;

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    this.ref.update(data);
    return this;
  }

  @override
  Transaction set<T extends Object?>(
    DocumentReference<T> ref,
    T data, [
    SetOptions? options,
  ]) {
    if (data is Map<String, dynamic>) this.ref.set(data);
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    this.ref.delete();
    return this;
  }
}
