import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/models/tenant.dart';
import '../test_helpers.dart';

class StubTenantServiceCancel extends TenantService {
  StubTenantServiceCancel() : super(firestore: FakeFirebaseFirestore());
  bool cancelled = false;
  @override
  Future<void> attachInvoice(String tenantId, {required String invoiceId, required DateTime deadline}) async {}

  @override
  Future<void> cancelRegistrationByOwner({required String tenantId, required String userId, String? reason}) async {
    cancelled = true;
  }

  @override
  Future<int> cancelExpiredInvoices() async => 0;

  @override
  Future<Tenant> createTenant({required String businessName, required String documentBase64, required String packageId}) async {
    return Tenant(id: 't1', businessName: businessName, documentBase64: documentBase64, packageId: packageId);
  }

  @override
  Future<void> markPaid(String tenantId, String invoiceId) async {}

  @override
  Future<void> submitRegistrationPayment({required String tenantId, String? proofUrl, String? proofBase64, required String userId}) async {}

  @override
  Future<Tenant?> getActiveRegistrationForOwner(String ownerUid) async {
    return Tenant(id: 't1', businessName: 'Acme', documentBase64: '', packageId: 'basic', status: 'awaiting_payment');
  }
}

void main() {
  testWidgets('Cancel button triggers cancelRegistrationByOwner and hides banner', (tester) async {
    final svc = StubTenantServiceCancel();
    final fs = svc.firestore;

    // Seed Firestore
    await fs.collection('tenants').add({
      'owner_uid': 'test_owner',
      'business_name': 'Acme',
      'status': 'awaiting_payment',
      'created_at': Timestamp.now(),
    });

    await tester.pumpWidget(wrapWithLocalization(TenantRegistrationScreen(
      tenantService: svc,
      currentUserId: 'test_owner',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Buat Baru'), findsOneWidget);

    await tester.tap(find.text('Buat Baru'));
    await tester.pumpAndSettle();

    // dialog should be removed
    expect(find.textContaining('Anda memiliki pendaftaran'), findsNothing);
  });
}
