import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:flutter/services.dart';
import 'auth_service_test.mocks.dart';

void main() {
  test('signOut should record logout audit', () async {
    // ensure platform bindings for secure storage/delete aren't required during this unit test
    TestWidgetsFlutterBinding.ensureInitialized();

    // Stub platform channel used by flutter_secure_storage so tests don't hit native plugin
    const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async => null);

    final mockAuth = MockFirebaseAuth();
    final mockFirestore = MockFirebaseFirestore();
    final mockUser = MockUser();
    final mockAuditCollection = MockCollectionReference<Map<String, dynamic>>();

    // arrange
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('u123');
    when(mockFirestore.collection('login_audit')).thenReturn(mockAuditCollection);
    when(mockAuditCollection.add(any)).thenAnswer((_) async => MockDocumentReference<Map<String, dynamic>>());
    when(mockAuth.signOut()).thenAnswer((_) async {});

    final authService = AuthService(auth: mockAuth, firestore: mockFirestore);

    // act
    await authService.signOut();

    // assert
    final captured = verify(mockAuditCollection.add(captureAny)).captured;
    expect(captured, isNotEmpty);
    final arg = captured.first as Map<String, dynamic>;
    expect(arg['uid'], 'u123');
    expect(arg['event'], 'logout');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
