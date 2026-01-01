const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { sendEmailViaSendGrid } = require('./sendgrid_helper');

try { admin.initializeApp(); } catch (e) { /* already initialized in emulator */ }
const db = admin.firestore();

// -----------------------------------------------------------------------------
// HELPER: EMAIL OUTBOX HANDLER
// -----------------------------------------------------------------------------
async function _processOutboxEmailHandler(snap, context) {
  const data = snap.data();
  if (!data) return null;

  const id = context.params.docId;
  const to = data.to;
  const subject = data.subject ?? '(no subject)';
  const body = data.body ?? '';

  // mark as processing
  await snap.ref.update({ status: 'processing', processed_at: new Date() });

  // attempt to send
  const result = await sendEmailViaSendGrid({ to, subject, body });

  if (result.status === 'sent') {
    await snap.ref.update({ status: 'sent', sent_at: new Date() });
  } else if (result.status === 'skipped') {
    await snap.ref.update({ status: 'skipped', reason: result.info });
  } else {
    await snap.ref.update({ status: 'error', reason: result.info });
  }

  return null;
}

// Export handler for unit tests
exports._processOutboxEmailHandler = _processOutboxEmailHandler;

exports.processOutboxEmail = functions.firestore
  .document('outbox_emails/{docId}')
  .onCreate(_processOutboxEmailHandler);

// -----------------------------------------------------------------------------
// CRON: AUTO-CANCEL EXPIRED BOOKINGS (ZOMBIE BOOKINGS KILLER)
// -----------------------------------------------------------------------------
// Runs every 1 minute to check for bookings that exceeded payment_deadline.
// Handles statuses: 'waiting' and 'awaiting_payment'.
// Requires Blaze plan (Pay-as-you-go) for Cloud Scheduler.
// If on Spark plan, use the HTTP version below with an external cron service.
exports.cleanupExpiredBookings = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  const now = admin.firestore.Timestamp.now();
  const batchLimit = 400; // Leave buffer for safety within 500 limit

  try {
    // 1. Find expired 'waiting' bookings
    const expiredWaiting = await db.collection('queues')
        .where('status', '==', 'waiting')
        .where('payment_deadline', '<', now)
        .limit(batchLimit / 2)
        .get();

    // 2. Find expired 'awaiting_payment' bookings
    const expiredAwaiting = await db.collection('queues')
        .where('status', '==', 'awaiting_payment')
        .where('payment_deadline', '<', now)
        .limit(batchLimit / 2)
        .get();

    if (expiredWaiting.empty && expiredAwaiting.empty) {
      console.log('No expired bookings found.');
      return null;
    }

    const batch = db.batch();
    let opCount = 0;
    const cancelData = {
      status: 'cancelled',
      cancellation_reason: 'System: Payment timeout (Auto-Cancel)',
      cancelled_by_uid: 'system',
      cancelled_at: now,
      updated_at: now
    };

    // Process Waiting
    expiredWaiting.docs.forEach(doc => {
      batch.update(doc.ref, cancelData);
      opCount++;
    });

    // Process Awaiting Payment
    // IMPORTANT: Only cancel if NO payment proof is uploaded.
    // If user uploaded proof, they are waiting for admin verification, so we extend indefinitely.
    expiredAwaiting.docs.forEach(doc => {
      const data = doc.data();
      const hasProof = (data.payment_proof_base64 && data.payment_proof_base64.length > 0) ||
                       (data.payment && (data.payment.proofUrl || data.payment.payment_proof_base64));
      
      if (!hasProof) {
        batch.update(doc.ref, cancelData);
        opCount++;
      }
    });

    if (opCount > 0) {
      await batch.commit();
      console.log(`Auto-cancelled ${opCount} expired bookings.`);
    } else {
      console.log('No eligible expired bookings to cancel.');
    }

  } catch (error) {
    console.error('Error in cleanupExpiredBookings:', error);
  }
  return null;
});

// HTTP Trigger version (Alternative for testing or manual trigger)
exports.cleanupExpiredBookingsHttp = functions.https.onRequest(async (req, res) => {
  // Simple security: check for a secret query param if deployed publicly
  // if (req.query.key !== 'YOUR_SECRET_KEY') return res.status(403).send('Forbidden');
  
  const now = admin.firestore.Timestamp.now();
  const batchLimit = 400;

  try {
    const expiredWaiting = await db.collection('queues')
        .where('status', '==', 'waiting')
        .where('payment_deadline', '<', now)
        .limit(batchLimit / 2)
        .get();

    const expiredAwaiting = await db.collection('queues')
        .where('status', '==', 'awaiting_payment')
        .where('payment_deadline', '<', now)
        .limit(batchLimit / 2)
        .get();

    const batch = db.batch();
    let opCount = 0;
    const cancelData = {
      status: 'cancelled',
      cancellation_reason: 'System: Payment timeout (Auto-Cancel)',
      cancelled_by_uid: 'system',
      cancelled_at: now,
      updated_at: now
    };

    expiredWaiting.docs.forEach(doc => {
      batch.update(doc.ref, cancelData);
      opCount++;
    });

    // Process Awaiting Payment with Check
    expiredAwaiting.docs.forEach(doc => {
      const data = doc.data();
      const hasProof = (data.payment_proof_base64 && data.payment_proof_base64.length > 0) ||
                       (data.payment && (data.payment.proofUrl || data.payment.payment_proof_base64));
      
      if (!hasProof) {
        batch.update(doc.ref, cancelData);
        opCount++;
      }
    });

    if (opCount > 0) await batch.commit();
    
    res.json({ success: true, cancelled: opCount });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: error.message });
  }
});
