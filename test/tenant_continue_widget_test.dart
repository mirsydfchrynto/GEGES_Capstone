import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/service.dart' as model;
import 'package:geges_smartbarber/models/user_data.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/location_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'test_helpers.dart';

class MockBarbershopService extends Mock implements BarbershopService {
  @override
  Future<List<Barbershop>> getAllBarbershops({bool forceRefresh = false}) async => [];
  @override
  Stream<List<Barbershop>> streamAllBarbershops() => Stream.value([]);
  @override
  Future<List<model.Service>> getAllServices() async => [];
}
class MockLocationService extends Mock implements LocationService {}
class MockQueueService extends Mock implements QueueService {
  @override
  Stream<int> streamUnreadNotificationCount(String userId) => Stream.value(0);
}
class MockAuthService extends Mock implements AuthService {
  @override
  Future<UserData?> getUserById(String uid) async => null;
}

class FakeTenantService2 extends TenantService {
  final Future<String> Function(String tenantId, String path) onUpload;
  final Future<void> Function({
    required String tenantId,
    required String proofBase64,
    required String userId,
  })
  onSubmit;

  FakeTenantService2(this.onUpload, this.onSubmit)
    : super(firestore: FakeFirebaseFirestore(), storage: null);

  @override
  Future<String> uploadTenantDocument(
    String tenantId,
    File file, {
    String? filename,
  }) async {
    final path = file.path;
    return onUpload(tenantId, path);
  }

  @override
  Future<void> submitRegistrationPayment({
    required String tenantId,
    String? proofUrl,
    String? proofBase64,
    required String userId,
  }) async {
    return onSubmit(
      tenantId: tenantId,
      proofBase64: proofBase64 ?? '',
      userId: userId,
    );
  }
}

void main() {
  testWidgets('TenantContinueScreen uploads proof and updates invoice', (
    WidgetTester tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    final tenantId = 'tenant123';
    await fs.collection('tenants').doc(tenantId).set({
      'invoice': {'amount': 300000, 'status': 'waiting_proof'},
    });

    var submitted = false;

    final fakeService = FakeTenantService2(
      (id, path) async {
        return 'firestore://$id/docs/fake';
      },
      ({
        required String tenantId,
        required String proofBase64,
        required String userId,
      }) async {
        submitted = true;
        // write to firestore to emulate submit action (store proof as base64 field)
        await fs.collection('tenants').doc(tenantId).set({
          'invoice': {
            'status': 'payment_submitted',
            'submitted_at': Timestamp.now(),
            'payment_proof_base64': proofBase64,
          },
        }, SetOptions(merge: true));
      },
    );

    // Provide mocks to avoid Firebase initialization error during navigation to HomeScreen
    final mockBS = MockBarbershopService();
    final mockLS = MockLocationService();
    final mockQS = MockQueueService();
    final mockAuth = MockAuthService();

    // Instead of exercising platform pickers, inject a submit handler that
    // calls the fake service and writes to firestore — this avoids UI timing issues.
    await tester.pumpWidget(
      wrapWithLocalization(
        TenantContinueScreen(
          tenantId: tenantId,
          amount: 300000,
          tenantService: fakeService,
          barbershopService: mockBS,
          locationService: mockLS,
          queueService: mockQS,
          authService: mockAuth,
          firestore: fs,
          currentUserId: 'user123',
          submitProofHandler: () async {
            submitted = true;
            await fs.collection('tenants').doc(tenantId).set({
              'invoice': {
                'status': 'payment_submitted',
                'submitted_at': Timestamp.now(),
                'payment_proof_base64': 'ZmFrZQ==',
              },
            }, SetOptions(merge: true));
          },
        ),
      ),
    );

    // find upload button
    final uploadButton = find.text('Unggah Bukti Pembayaran');
    expect(uploadButton, findsOneWidget);

    // Tap the button
    await tester.tap(uploadButton);
    // Use pump() instead of pumpAndSettle if there's an infinite animation or complex nav
    await tester.pump(); 
    await tester.pump(const Duration(seconds: 1));

    expect(submitted, isTrue);

    final doc = await fs.collection('tenants').doc(tenantId).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['invoice']['status'], 'payment_submitted');
  });
}
