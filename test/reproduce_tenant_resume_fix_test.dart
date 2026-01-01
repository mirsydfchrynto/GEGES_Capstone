
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/services/tenant_service.dart';

void main() {
  test('Tenant Registration Resume Flow Reproduction', () async {
    // 1. Setup Fake Firestore & Service
    final firestore = FakeFirebaseFirestore();
    final service = TenantService(firestore: firestore);
    final userId = 'user_123';

    // 2. Simulate User submitting registration form
    // The screen sends 'status': 'awaiting_payment'
    final data = {
      'business_name': 'My Barbershop',
      'owner_uid': userId,
      'status': 'awaiting_payment', // This was previously overwritten by 'draft'
      'registration_fee': 300000,
    };

    final tenantId = await service.createTenantApplication(data);

    // 3. Verify the document status in Firestore
    final doc = await firestore.collection('tenants').doc(tenantId).get();
    final savedStatus = doc.data()?['status'];

    expect(savedStatus, 'awaiting_payment', 
      reason: 'Status should be awaiting_payment, NOT draft. If this fails, the Service is overwriting it.');

    // 4. Simulate the Check used in TenantRegistrationScreen
    // Query: owner_uid == userId AND status IN ['pending_payment', 'awaiting_payment', ...]
    final querySnapshot = await firestore
        .collection('tenants')
        .where('owner_uid', isEqualTo: userId)
        .where('status', whereIn: [
          'pending_payment',
          'awaiting_payment',
          'waiting_proof',
          'payment_submitted',
        ])
        .get();


    // 5. Assertions
    expect(querySnapshot.docs.isNotEmpty, true, 
      reason: 'Resume query should find the pending registration');
    
    final foundDoc = querySnapshot.docs.first;
    expect(foundDoc.id, tenantId);
    
  });
}
