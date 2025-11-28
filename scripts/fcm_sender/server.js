/*
Small Express server to trigger processing of pending push_requests.
Usage:
  export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
  export PROCESS_API_KEY=your-secret-key
  node server.js

Endpoint:
  POST /process-push  -> triggers processing of pending push_requests
    Headers: x-api-key: <PROCESS_API_KEY>

This is intentionally minimal. For production, host this behind your admin network or add stronger auth.
*/

const admin = require('firebase-admin');
const dotenv = require('dotenv');
const express = require('express');
const cors = require('cors');

dotenv.config();

const PORT = process.env.PORT || 4000;
const API_KEY = process.env.PROCESS_API_KEY || process.env.API_KEY || null;

if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  admin.initializeApp({ credential: admin.credential.applicationDefault() });
} else if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)) });
} else {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON in env');
  process.exit(2);
}

const firestore = admin.firestore();

async function broadcast(title, body, extra) {
  const q = await firestore.collection('users').where('fcm_token', '!=', null).get();
  const tokens = [];
  q.forEach(d => {
    const data = d.data();
    if (data && data.fcm_token) tokens.push(data.fcm_token);
  });
  if (tokens.length === 0) return { ok: false, reason: 'no_tokens' };
  const chunks = [];
  for (let i = 0; i < tokens.length; i += 500) chunks.push(tokens.slice(i, i + 500));
  let success = 0, failure = 0;
  for (const chunk of chunks) {
    const res = await admin.messaging().sendMulticast({ tokens: chunk, notification: { title, body }, data: extra || {} });
    success += res.successCount;
    failure += res.failureCount;
  }
  return { ok: true, success, failure };
}

async function sendToUser(uid, title, body, extra) {
  const userDoc = await firestore.collection('users').doc(uid).get();
  if (!userDoc.exists) throw new Error('user_not_found');
  const user = userDoc.data();
  const token = (user && user.fcm_token) || null;
  if (!token) throw new Error('no_token');
  await admin.messaging().send({ token, notification: { title, body }, data: extra || {} });
  return { ok: true };
}

async function processPendingRequestsOnce(limit = 50) {
  const q = await firestore.collection('push_requests').where('processed', '==', false).limit(limit).get();
  if (q.empty) return { processed: 0 };
  let processed = 0;
  for (const doc of q.docs) {
    const data = doc.data();
    try {
      if (data.broadcast) {
        await broadcast(data.title || 'GEGES', data.body || '', { queue_id: data.queue_id });
      } else {
        const uid = data.user_id;
        if (!uid) throw new Error('missing_user_id');
        await sendToUser(uid, data.title || 'GEGES', data.body || '', { queue_id: data.queue_id });
      }
      await doc.ref.update({ processed: true, processed_at: admin.firestore.FieldValue.serverTimestamp(), result: 'ok' });
      processed++;
    } catch (e) {
      await doc.ref.update({ processed: true, processed_at: admin.firestore.FieldValue.serverTimestamp(), result: `error: ${e.message || e}` });
    }
  }
  return { processed };
}

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => res.json({ ok: true, ts: Date.now() }));

app.post('/process-push', async (req, res) => {
  const key = req.headers['x-api-key'] || req.query.key;
  if (!API_KEY) {
    return res.status(500).json({ ok: false, error: 'server_not_configured' });
  }
  if (!key || key !== API_KEY) {
    return res.status(401).json({ ok: false, error: 'invalid_api_key' });
  }
  try {
    const result = await processPendingRequestsOnce();
    return res.json({ ok: true, result });
  } catch (e) {
    console.error('process error', e);
    return res.status(500).json({ ok: false, error: e.message || String(e) });
  }
});

app.listen(PORT, () => console.log(`FCM helper server listening on ${PORT}`));
