import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import '../../mocks/auth_service_test.mocks.dart'; // Import MockFirebaseAuth

@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
])

// A simple fake transaction object to drive runTransaction callbacks in tests.
class _FakeTx implements Transaction {
  final MockDocumentSnapshot<Map<String, dynamic>> snap;
  final MockDocumentReference<Map<String, dynamic>> ref;
  _FakeTx(this.snap, this.ref);

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async => snap as DocumentSnapshot<T>;

  @override
  Transaction update(DocumentReference ref, Map<String, dynamic> data) {
    // delegate to the mock reference to record the call
    this.ref.update(data);
    return this;
  }

  @override
  Transaction set<T extends Object?>(
    DocumentReference<T> ref,
    T data, [
    SetOptions? options,
  ]) {
    if (data is Map<String, dynamic>) {
      this.ref.set(data);
    }
    return this;
  }

  @override
  Transaction delete(DocumentReference ref) {
    this.ref.delete();
    return this;
  }
}

void main() {
  late MockFirebaseFirestore mockFs;
  late MockFirebaseAuth mockAuth; // Declare MockFirebaseAuth
  late MockCollectionReference<Map<String, dynamic>> mockQueuesColl;
  late MockDocumentReference<Map<String, dynamic>> mockQueueRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockQueueSnap;

  setUp(() {
    mockFs = MockFirebaseFirestore();
    mockAuth = MockFirebaseAuth(); // Initialize MockFirebaseAuth
    mockQueuesColl = MockCollectionReference<Map<String, dynamic>>();
    mockQueueRef = MockDocumentReference<Map<String, dynamic>>();
    mockQueueSnap = MockDocumentSnapshot<Map<String, dynamic>>();

    when(mockFs.collection('queues')).thenReturn(mockQueuesColl);
    when(mockQueuesColl.doc('q_pay')).thenReturn(mockQueueRef);
  });

  test(
    'adminConfirmPayment updates awaiting_payment to booked when proof exists',
    () async {
      when(mockQueueRef.get()).thenAnswer((_) async => mockQueueSnap);
      when(mockQueueSnap.data()).thenReturn({
        'status': 'awaiting_payment',
        'payment_proof_base64': 'abc',
      });
      when(mockQueueSnap.exists).thenReturn(true);

      // stub runTransaction to call our closure with a fake tx that delegates to the mocked doc ref
      when(
        mockFs.runTransaction(
          any,
          timeout: anyNamed('timeout'),
          maxAttempts: anyNamed('maxAttempts'),
        ),
      ).thenAnswer((inv) async {
        final cb = inv.positionalArguments[0] as dynamic;
        final tx = _FakeTx(mockQueueSnap, mockQueueRef);

        await cb(tx);
        return;
      });

      final svc = QueueService(firestore: mockFs, auth: mockAuth);

      await svc.adminConfirmPayment('q_pay', adminUid: 'admin_1');

      final captured =
          verify(mockQueueRef.update(captureAny)).captured.single as Map;
      expect(captured['status'], 'booked');
      expect(captured['payment_confirmed_by'], 'admin_1');
    },
  );
}
