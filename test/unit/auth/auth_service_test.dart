import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/services/auth_service.dart';

// Generate Mocks untuk Firebase
@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  UserCredential,
  User,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
])
import '../../mocks/auth_service_test.mocks.dart';

void main() {
  late AuthService authService;
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;
  late MockCollectionReference<Map<String, dynamic>> mockCollection;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;
  late MockCollectionReference<Map<String, dynamic>> mockAuditCollection;

  setUp(() {
    // 1. Inisialisasi Mock
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();
    mockCollection = MockCollectionReference<Map<String, dynamic>>();
    mockDocRef = MockDocumentReference<Map<String, dynamic>>();
    mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
    mockAuditCollection = MockCollectionReference<Map<String, dynamic>>();

    // 2. Setup Chain Firestore (collection -> doc -> get)
    // Agar saat kode memanggil .collection('users').doc(...), mock kita yang merespons
    when(mockFirestore.collection('users')).thenReturn(mockCollection);
    when(mockCollection.doc(any)).thenReturn(mockDocRef);

    // stub doc update future
    when(mockDocRef.update(any)).thenAnswer((_) async {});

    // stub audit collection add (best-effort)
    when(
      mockFirestore.collection('login_audit'),
    ).thenReturn(mockAuditCollection);
    when(
      mockAuditCollection.add(any),
    ).thenAnswer((_) async => MockDocumentReference<Map<String, dynamic>>());

    // 3. Inject Mock ke dalam AuthService
    authService = AuthService(auth: mockAuth, firestore: mockFirestore);
  });

  group('AuthService - White Box Testing Login', () {
    const email = 'esa@gmail.com';
    const password = '123456789';
    const uid = 'q9fd1LOvlNVKDJyv0DGVk95FDxf1';

    // ==========================================
    // TC-02: Autentikasi Gagal (Password Salah / User Tidak Ada)
    // ==========================================
    test('TC-02: Harus return success false jika FirebaseAuth gagal', () async {
      // ARRANGE: Simulasikan Firebase melempar error
      when(
        mockAuth.signInWithEmailAndPassword(email: email, password: password),
      ).thenThrow(
        FirebaseAuthException(
          code: 'user-not-found',
          message: 'User tidak ditemukan',
        ),
      );

      // ACT: Jalankan fungsi
      final result = await authService.signIn(email: email, password: password);

      // ASSERT: Verifikasi hasil
      expect(result['success'], false);
      expect(result['message'], 'Email tidak ditemukan.');
    });

    // ==========================================
    // TC-02b: Wrong password mapping
    // ==========================================
    test(
      'TC-02b: Harus return message Password salah saat wrong-password',
      () async {
        when(
          mockAuth.signInWithEmailAndPassword(email: email, password: password),
        ).thenThrow(
          FirebaseAuthException(
            code: 'wrong-password',
            message: 'Wrong password',
          ),
        );

        final result = await authService.signIn(
          email: email,
          password: password,
        );

        expect(result['success'], false);
        expect(result['message'], 'Password salah.');
      },
    );

    // ==========================================
    // TC-02c: Invalid email mapping
    // ==========================================
    test(
      'TC-02c: Harus return message Format email salah saat invalid-email',
      () async {
        when(
          mockAuth.signInWithEmailAndPassword(email: email, password: password),
        ).thenThrow(
          FirebaseAuthException(
            code: 'invalid-email',
            message: 'Invalid email',
          ),
        );

        final result = await authService.signIn(
          email: email,
          password: password,
        );

        expect(result['success'], false);
        expect(result['message'], 'Format email salah.');
      },
    );

    // ==========================================
    // TC-03: Login Sukses - Customer
    // ==========================================
    test('TC-03: Harus return role customer jika data valid', () async {
      // ARRANGE:
      // 1. Auth Berhasil
      when(
        mockAuth.signInWithEmailAndPassword(email: email, password: password),
      ).thenAnswer((_) async => mockUserCredential);
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn(uid);

      // 2. Firestore Document Ada & Role Customer
      // Accept any argument (e.g. GetOptions) for .get()
      when(mockDocRef.get(any)).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(true);
      when(mockDocSnapshot.data()).thenReturn({'role': 'customer'});

      // ACT
      final result = await authService.signIn(email: email, password: password);

      // ASSERT
      expect(result['success'], true);
      expect(result['role'], 'customer');

      // Should have updated last_login on user doc (audit write is best-effort)
      verify(mockDocRef.update(any)).called(1);

      // Audit write should have been attempted (best-effort)
      final capturedAudit = verify(
        mockAuditCollection.add(captureAny),
      ).captured;
      expect(capturedAudit, isNotEmpty);
      final auditArg = capturedAudit.first as Map<String, dynamic>;
      expect(auditArg['uid'], uid);
      expect(auditArg['event'], 'login');
    });

    // ==========================================
    // TC-04: Login Sukses - Admin Owner
    // ==========================================
    test('TC-04: Harus return role admin_owner jika data valid', () async {
      // ARRANGE
      when(
        mockAuth.signInWithEmailAndPassword(email: email, password: password),
      ).thenAnswer((_) async => mockUserCredential);
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn(uid);

      // Firestore Role Admin
      when(mockDocRef.get(any)).thenAnswer((_) async => mockDocSnapshot);
      when(mockDocSnapshot.exists).thenReturn(true);
      when(mockDocSnapshot.data()).thenReturn({'role': 'admin_owner'});

      // ACT
      final result = await authService.signIn(email: email, password: password);

      // ASSERT
      expect(result['success'], true);
      expect(result['role'], 'admin_owner');

      // Should have updated last_login on user doc (audit write is best-effort)
      verify(mockDocRef.update(any)).called(1);
    });

    // ==========================================
    // TC-05: Data Inkonsisten (Auth OK, Firestore Hilang)
    // ==========================================
    test(
      'TC-05: Harus return gagal jika dokumen user tidak ada di Firestore',
      () async {
        // ARRANGE
        // 1. Auth Berhasil
        when(
          mockAuth.signInWithEmailAndPassword(email: email, password: password),
        ).thenAnswer((_) async => mockUserCredential);
        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockUser.uid).thenReturn(uid);

        // 2. Firestore Document TIDAK ADA (!exists)
        when(mockDocRef.get(any)).thenAnswer((_) async => mockDocSnapshot);
        when(
          mockDocSnapshot.exists,
        ).thenReturn(false); // <--- Kunci pengujian ini
        when(mockDocSnapshot.data()).thenReturn(null);

        // ACT
        final result = await authService.signIn(
          email: email,
          password: password,
        );

        // ASSERT
        expect(result['success'], false);
        expect(result['message'], 'Data pengguna tidak ditemukan.');
      },
    );

    test(
      'TC-06: Menangani reCAPTCHA / recaptcha token kosong dengan pesan yang informatif',
      () async {
        when(
          mockAuth.signInWithEmailAndPassword(email: email, password: password),
        ).thenThrow(
          FirebaseAuthException(
            code: 'auth-error',
            message: 'Logging in with empty reCAPTCHA token',
          ),
        );

        final result = await authService.signIn(
          email: email,
          password: password,
        );

        expect(result['success'], false);
        expect(
          result['message'].toString().toLowerCase(),
          contains('recaptcha'),
        );
      },
    );
  });
}
