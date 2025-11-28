GEGES FCM Sender

Small helper tool to send FCM push notifications to users using saved tokens in Firestore.

Setup

1. Install dependencies

```bash
cd scripts/fcm_sender
npm install
```

2. Provide credentials

- Set `GOOGLE_APPLICATION_CREDENTIALS` to the path of your service-account JSON OR
- Set `FIREBASE_SERVICE_ACCOUNT_JSON` environment variable with the full JSON (not recommended).

You can copy `.env.example` to `.env` and edit it.

Usage

Send to a single user (by Firestore uid):

```bash
node send_push.js --type=personal --uid=<USER_UID> --title="Hi" --body="Your booking is ready" --queue=<QUEUE_ID>
```

Broadcast to all users with tokens:

```bash
node send_push.js --type=broadcast --title="Promo" --body="Diskon hari ini!"
```

Notes

- This script reads `users` collection and expects `fcm_token` field per user.
- For production, build a small authenticated admin endpoint instead of running scripts locally.

Server endpoint

You can run a small Express server that triggers processing of pending `push_requests`:

```bash
export PROCESS_API_KEY=your-secret
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
node server.js
```

Then call:

```bash
curl -X POST "http://localhost:4000/process-push" -H "x-api-key: your-secret"
```

The server exposes `POST /process-push` (requires header `x-api-key`) and will process up to 50 pending requests per call.
