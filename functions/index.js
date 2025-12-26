const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { sendEmailViaSendGrid } = require('./sendgrid_helper');

try { admin.initializeApp(); } catch (e) { /* already initialized in emulator */ }
const db = admin.firestore();

async function _processOutboxEmailHandler(snap, context) {
  const data = snap.data();
  if (!data) return null;

  const id = context.params.docId;
  const to = data.to;
  const subject = data.subject ?? '(no subject)';
  const body = data.body ?? '';

  // mark as processing
  await snap.ref.update({ status: 'processing', processed_at: admin.firestore.FieldValue.serverTimestamp() });

  // attempt to send
  const result = await sendEmailViaSendGrid({ to, subject, body });

  if (result.status === 'sent') {
    await snap.ref.update({ status: 'sent', sent_at: admin.firestore.FieldValue.serverTimestamp() });
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
