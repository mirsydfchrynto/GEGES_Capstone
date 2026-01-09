import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/screens/admin/tenant_requests_screen.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

class FakeTenantService3 extends TenantService {

  FakeTenantService3(FakeFirebaseFirestore fs) : super(firestore: fs, storage: null);

  bool verifyCalled = false;
  bool? lastApprove;

  @override
  Future<void> verifyTenant({
    required String tenantId,
    required bool approve,
    String? verifiedBy,
    String? reason,
    String? adminEmail,
    String? tempPassword,
  }) async {
    verifyCalled = true;
    lastApprove = approve;
  }
}

void main() {
  testWidgets('TenantRequestsScreen lists pending tenants and allows approve', (
    WidgetTester tester,
  ) async {
    final fs = FakeFirebaseFirestore();
    await fs.collection('tenants').doc('t1').set({
      'business_name': 'Toko 1',
      'owner_email': 'a@b.com',
      'status': 'pending_payment',
      'invoice': {'status': 'waiting_proof'},
    });

    final fakeService = FakeTenantService3(fs);

    await tester.pumpWidget(
      MaterialApp(
        home: TenantRequestsScreen(
          firestore: fs,
          tenantService: fakeService,
          currentUserId: 'admin-ui-1',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Toko 1'), findsOneWidget);

    // tap approve (check icon)
    final approveBtn = find.byIcon(Icons.check);
    expect(approveBtn, findsWidgets);

    await tester.tap(approveBtn.first);
    await tester.pumpAndSettle();

    // Since we now have a credentials dialog, we must handle it in the test
    expect(find.text('Approve Partnership'), findsOneWidget);
    await tester.tap(find.text('Approve & Kirim Akun'));
    await tester.pumpAndSettle();

    expect(fakeService.verifyCalled, isTrue);
    expect(fakeService.lastApprove, isTrue);
  });
}