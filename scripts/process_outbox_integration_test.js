const admin = require('firebase-admin');

// This script expects to be run inside firebase emulators:exec which sets
// FIRESTORE_EMULATOR_HOST and starts the functions emulator so that the
// Firestore trigger runs.

async function main() {
  try {
    // Initialize with default project id; emulator will handle connection
    admin.initializeApp();
    const db = admin.firestore();

    console.log('Creating outbox_emails document (expect functions emulator to process it)...');
    const ref = await db.collection('outbox_emails').add({
      to: 'dev@example.com',
      subject: 'Integration test - outbox',
      body: 'This is an automated integration test.',
      created_at: admin.firestore.FieldValue.serverTimestamp()
    });

    const timeoutMs = 20000; // wait up to 20s
    const intervalMs = 500;
    const start = Date.now();

    while (Date.now() - start < timeoutMs) {
      const snap = await ref.get();
      const data = snap.data() || {};
      if (data.status && ['skipped', 'sent', 'error'].includes(data.status)) {
        console.log('Observed final status:', data.status, data.reason || '');
        if (data.status === 'skipped') {
          console.log('Integration test passed (skipped because SENDGRID_API_KEY not set).');
          process.exit(0);
        } else {
          console.error('Integration test failed: unexpected status:', data.status);
          process.exit(2);
        }
      }
      await new Promise((r) => setTimeout(r, intervalMs));
    }

    console.error('Integration test timed out waiting for function to process outbox document.');
    process.exit(3);
  } catch (e) {
    console.error('Integration test error:', e);
    process.exit(4);
  }
}

main();
