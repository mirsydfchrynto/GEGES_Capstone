import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:geges_smartbarber/screens/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/models/tenant.dart';

class StubTenantServiceCancel implements TenantServiceContract {
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
    await tester.pumpWidget(MaterialApp(home: TenantRegistrationScreen(tenantService: svc)));
    await tester.pumpAndSettle();

    expect(find.text('Batalkan'), findsOneWidget);

    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();

    // banner should be removed
    expect(find.textContaining('Anda memiliki pendaftaran'), findsNothing);
    expect(svc.cancelled, isTrue);
  });
}
