import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';
import 'package:geges_smartbarber/models/tenant.dart';
import '../test_helpers.dart';

// Small in-memory tenant service for tests
class InMemoryTenantService extends TenantService {
  InMemoryTenantService() : super(firestore: FakeFirebaseFirestore());
  final Map<String, Map<String, dynamic>> _m = {};

  @override
  Future<int> cancelExpiredInvoices() async => 0;

  @override
  Future<Tenant> createTenant({required String businessName, required String documentBase64, required String packageId}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _m[id] = {
      'business_name': businessName,
      'document_base64': documentBase64,
      'package_id': packageId,
      'status': 'pending',
      'created_at': DateTime.now(),
    };
    return Tenant(id: id, businessName: businessName, documentBase64: documentBase64, packageId: packageId);
  }

  @override
  Future<void> markPaid(String tenantId, String invoiceId) async {
    final t = _m[tenantId];
    if (t != null) {
      t['status'] = 'awaiting_confirmation';
      t['invoice_id'] = invoiceId;
      t['paid_at'] = DateTime.now();
    }
  }

  @override
  Future<void> attachInvoice(String tenantId, {required String invoiceId, required DateTime deadline}) async {
    final t = _m[tenantId];
    if (t != null) {
      t['invoice_id'] = invoiceId;
      t['payment_deadline'] = deadline;
      t['status'] = 'awaiting_payment';
    }
  }

  @override
  Future<void> submitRegistrationPayment({required String tenantId, String? proofUrl, String? proofBase64, required String userId}) async {
    final t = _m[tenantId];
    if (t != null) {
      t['payment'] = {
        'method': 'manual',
        'proofUrl': proofUrl,
        'payment_proof_base64': proofBase64,
        'paidBy': userId,
        'verificationStatus': 'pending',
        'paidAt': DateTime.now(),
      };
      t['history'] = (t['history'] ?? [])..add({'type': 'registration_payment', 'status': 'pending', 'created_at': DateTime.now()});
    }
  }

  @override
  Future<void> cancelRegistrationByOwner({required String tenantId, required String userId, String? reason}) async {
    final t = _m[tenantId];
    if (t != null) {
      t['invoice'] = t['invoice'] ?? {};
      t['invoice']['status'] = 'cancelled_by_owner';
      t['invoice']['cancelled_by'] = userId;
      t['invoice']['cancel_reason'] = reason ?? 'Dibatalkan oleh pemilik';
      t['history'] = (t['history'] ?? [])..add({'type': 'registration_cancelled_by_owner', 'note': reason ?? 'Dibatalkan oleh pemilik', 'created_at': DateTime.now()});
    }
  }

  @override
  Future<Tenant?> getActiveRegistrationForOwner(String ownerUid) async {
    for (final entry in _m.entries) {
      final id = entry.key;
      final data = entry.value;
      final status = (data['status'] ?? '').toString();
      final owner = (data['owner_uid'] ?? '').toString();
      final inProgress = ['draft', 'awaiting_payment', 'awaiting_confirmation', 'payment_submitted', 'waiting_proof'];
      if (owner == ownerUid && inProgress.contains(status)) {
        return Tenant(id: id, businessName: data['business_name'] as String? ?? '', documentBase64: data['document_base64'] as String? ?? '', packageId: data['package_id'] as String? ?? '', status: status);
      }
    }
    return null;
  }
}


void main() {
  testWidgets('submit and pay flow shows waiting message', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(wrapWithLocalization(TenantRegistrationScreen(
      tenantService: InMemoryTenantService(),
      currentUserId: 'owner123',
    )));

    // Fill form
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Barber Keren');
    await tester.enterText(fields.at(2), 'Owner Name');
    await tester.enterText(fields.at(3), 'owner@example.com');
    
    // Accept terms
    final checkbox = find.byType(Checkbox);
    await tester.scrollUntilVisible(checkbox, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(checkbox);
    await tester.pump();

    // Submit
    // Price is 300000 by default (monthly)
    final submitBtn = find.widgetWithText(ElevatedButton, 'Daftar & Bayar 300000');
    await tester.ensureVisible(submitBtn);
    await tester.pumpAndSettle();
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Payment screen appears (localized: Pembayaran)
    expect(find.text('Pembayaran'), findsOneWidget);
  });
}
