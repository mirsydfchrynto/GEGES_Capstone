import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/admin/tenant_requests_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

class FakeTenantService3 extends TenantService {
  FakeTenantService3() : super(firestore: FakeFirebaseFirestore(), storage: null);

  bool approved = false;

  @override
  Future<void> verifyTenant({required String tenantId, required bool approve, String? verifiedBy, String? reason}) async {
    final fs = firestore ?? FakeFirebaseFirestore();
    await fs.collection('tenants').doc(tenantId).update({
      'status': approve ? 'active' : 'rejected',
      'verified_by': verifiedBy,
    });
    approved = approve;
  }
}

void main() {
  testWidgets('TenantRequestsScreen lists pending tenants and allows approve', (WidgetTester tester) async {
    final fs = FakeFirebaseFirestore();
    await fs.collection('tenants').doc('t1').set({
      'business_name': 'Toko 1',
      'owner_email': 'a@b.com',
      'status': 'pending_payment',
      'invoice': {'status': 'waiting_proof'},
    });

    final fakeService = FakeTenantService3();

    await tester.pumpWidget(MaterialApp(home: TenantRequestsScreen(firestore: fs, tenantService: fakeService)));

    await tester.pumpAndSettle();

    expect(find.textContaining('Toko 1'), findsOneWidget);

    // tap approve (check icon)
    final approveBtn = find.byIcon(Icons.check);
    expect(approveBtn, findsWidgets);

    await tester.tap(approveBtn.first);
    await tester.pumpAndSettle();

    final doc = await fs.collection('tenants').doc('t1').get();
    expect(doc.data()!['status'], 'active');
    expect(fakeService.approved, isTrue);
  });
}
