import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper utilities for running integration tests against the Firestore emulator.
///
/// Usage:
/// - Start the emulator:
///   `firebase emulators:start --only firestore`
/// - Ensure FIRESTORE_EMULATOR_HOST is set in the environment when running the test
///   (usually the emulator sets this automatically).
/// - Call `seedAwaitingPaymentTenant(...)` from your E2E test before launching the app.

Future<void> seedAwaitingPaymentTenant({
  required String tenantId,
  required int amount,
  required DateTime deadline,
}) async {
  final fs = FirebaseFirestore.instance;

  final invoiceId = 'inv-$tenantId';
  await fs.collection('tenants').doc(tenantId).set({
    'status': 'awaiting_payment',
    'invoice_id': invoiceId,
    'invoice': {
      'id': invoiceId,
      'amount': amount,
      'payment_deadline': Timestamp.fromDate(deadline),
      'status': 'waiting_proof',
    },
    'owner_uid': 'test-owner',
    'owner_email': 'owner@example.test',
    'created_at': Timestamp.fromDate(DateTime.now()),
  });
}
