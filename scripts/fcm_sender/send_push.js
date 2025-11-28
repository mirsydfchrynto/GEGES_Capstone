/*
Simple CLI to send FCM pushes using Firebase Admin SDK.
Usage examples:
  NODE_ENV=production node send_push.js --type=personal --uid=<USER_ID> --title="Hi" --body="Hello"
  node send_push.js --type=broadcast --title="Promo" --body="Diskon hari ini"

Environment variables (via .env):
  GOOGLE_APPLICATION_CREDENTIALS - path to service account json OR set credentials via env var
*/

const admin = require('firebase-admin');
const dotenv = require('dotenv');
const argv = require('minimist')(process.argv.slice(2));

dotenv.config();

// Initialize admin SDK: prefer GOOGLE_APPLICATION_CREDENTIALS or explicit JSON in env
if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
} else if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  const json = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  admin.initializeApp({ credential: admin.credential.cert(json) });
} else {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON in env');
  process.exit(2);
}

const firestore = admin.firestore();

async function sendToToken(token, payload) {
  try {
    const res = await admin.messaging().send({ token, notification: payload, data: payload.data || {} });
    console.log('Sent to token:', res);
  } catch (e) {
    console.error('Error sending to token', e);
  }
}

async function sendToUser(uid, title, body, extra) {
  const userDoc = await firestore.collection('users').doc(uid).get();
  if (!userDoc.exists) throw new Error('User not found');
  const user = userDoc.data();
  const token = (user && user.fcm_token) || null;
  if (!token) throw new Error('No token for user');
  const payload = { title, body, data: extra || {} };
  await sendToToken(token, payload);
}

async function broadcast(title, body, extra) {
  const q = await firestore.collection('users').where('fcm_token', '!=', null).get();
  const tokens = [];
  q.forEach(d => {
    const data = d.data();
    if (data && data.fcm_token) tokens.push(data.fcm_token);
  });
  if (tokens.length === 0) {
    console.log('No tokens found');
    return;
  }
  const payload = { notification: { title, body }, data: extra || {} };
  // sendMulticast supports up to 500 tokens per call
  const chunks = [];
  for (let i = 0; i < tokens.length; i += 500) chunks.push(tokens.slice(i, i + 500));
  for (const chunk of chunks) {
    const res = await admin.messaging().sendMulticast({ tokens: chunk, notification: { title, body }, data: extra || {} });
    console.log('Multicast result:', res.successCount, 'success,', res.failureCount, 'failure');
  }
}

(async () => {
  const type = argv.type || 'personal';
  const title = argv.title || argv.t || 'GEGES Notification';
  const body = argv.body || argv.b || '';
  const uid = argv.uid || argv.u;
  const queueId = argv.queue || argv.q;
  const extra = {};
  if (queueId) extra.queue_id = queueId;
  const processPending = argv.processPending || argv.p;

  try {
    if (processPending) {
      await processPendingRequests();
    } else if (type === 'broadcast') {
      await broadcast(title, body, extra);
    } else if (type === 'personal') {
      if (!uid) throw new Error('uid is required for personal');
      await sendToUser(uid, title, body, extra);
    } else {
      console.error('Unknown type', type);
    }
  } catch (e) {
    console.error('Send failed', e);
  }

  process.exit(0);
})();

async function processPendingRequests() {
  console.log('Processing pending push_requests...');
  const q = await firestore.collection('push_requests').where('processed', '==', false).limit(50).get();
  if (q.empty) {
    console.log('No pending push_requests');
    return;
  }
  for (const doc of q.docs) {
    const data = doc.data();
    const title = data.title || 'GEGES Notification';
    const body = data.body || '';
    try {
      if (data.broadcast) {
        await broadcast(title, body, { queue_id: data.queue_id });
      } else {
        const uid = data.user_id;
        if (!uid) throw new Error('Missing user_id');
        await sendToUser(uid, title, body, { queue_id: data.queue_id });
      }
      await doc.ref.update({ processed: true, processed_at: admin.firestore.FieldValue.serverTimestamp(), result: 'ok' });
      console.log('Processed push_request', doc.id);
    } catch (e) {
      console.error('Failed processing', doc.id, e);
      try {
        await doc.ref.update({ processed: true, processed_at: admin.firestore.FieldValue.serverTimestamp(), result: `error: ${e.message || e}` });
      } catch (_) {}
    }
  }
}
