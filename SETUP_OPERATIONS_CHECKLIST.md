# GEGES SmartBarber: Setup Operasional Checklist

**Tanggal Dibuat:** November 28, 2025

---

## Phase 1: Persiapan Awal (Development)

### 1.1 Firestore & Firebase Setup
- [ ] Login Firebase Console → pilih project GEGES
- [ ] Download service account JSON (Project Settings → Service Accounts tab → "Generate New Private Key")
- [ ] Simpan ke lokasi aman: `~/secure/firebase-service-account.json`
- [ ] Set permission: `chmod 600 ~/secure/firebase-service-account.json`
- [ ] Verify tidak di-commit ke git: add ke `.gitignore` jika belum

### 1.2 Flutter App Setup
```bash
# Di folder project root
flutter pub get
flutter pub upgrade

# Test compile
flutter build apk --debug  # Android
# atau
flutter build ios --debug  # iOS
```
- [ ] Build sukses, tidak ada error

### 1.3 Firestore Collections & Indexes
Buat collections (auto-create doc = not needed):
- [ ] `users/{uid}` — user data (name, email, fcm_token, dll)
- [ ] `notifications/{doc_id}` — notification documents
- [ ] `push_requests/{doc_id}` — pending push requests
- [ ] `queues/{queue_id}` — booking data

Firestore Rules (Temporary untuk dev):
```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```
- [ ] Update rules di Firebase Console

### 1.4 FCM Setup (Android)

**Android:**
- [ ] `google-services.json` sudah ada di `android/app/`
- [ ] Check `android/app/build.gradle`:
  ```gradle
  plugins {
    id 'com.google.gms.google-services'
  }
  ```

**iOS (opsional, untuk push):**
- [ ] Download `GoogleService-Info.plist` dari Firebase
- [ ] Add ke `ios/Runner` folder
- [ ] Enable Push Notifications di Xcode (Signing & Capabilities)

---

## Phase 2: Testing di Device/Emulator

### 2.1 Run App
```bash
# Terminal 1: Flutter app
flutter run -d [device_id]

# Atau jika multiple devices:
flutter devices  # list device_id
flutter run -d emulator-5554  # contoh Android emulator
```
- [ ] App berjalan tanpa error
- [ ] Can login dengan email/password dan Google Sign-In

### 2.2 Verify FCM Token Saving
```bash
# Di console, setelah login
adb logcat | grep "FCM\|token"  # Android

# atau lihat di Firestore:
# users/{uid} → field "fcm_token" should not be empty
```
- [ ] Token tersimpan di Firestore `users/{uid}.fcm_token`

### 2.3 Test In-App Notifications

**Manual test:**
1. Login sebagai **admin**
2. Go to Dashboard → "Kirim Notifikasi"
3. Pilih customer dari list (via autocomplete)
4. Title: "Test Notifikasi", Body: "Ini adalah test"
5. Leave "Queue ID" kosong, uncheck "Broadcast", uncheck "Kirim push"
6. Click "Kirim"

**Verify:**
```
Firestore → notifications collection
Lihat doc baru dengan:
  - user_id: [customer_uid]
  - title: "Test Notifikasi"
  - delivered: false
```

**Expected:** Notification muncul di customer phone/emulator

- [ ] Notification doc created di Firestore
- [ ] Customer menerima local notification

### 2.4 Test Notification Tap Navigation
1. Notification muncul di customer device
2. Tap notification
3. **Expected:** Buka BookingDetailScreen (atau page terkait)

- [ ] Tap navigation works

---

## Phase 3: Server Helper Setup

### 3.1 Install Node Helper
```bash
cd scripts/fcm_sender
npm install
npm list  # verify dependencies
```
- [ ] npm install successful, no critical vulnerabilities
- [ ] Dependencies: firebase-admin, dotenv, minimist, express, cors

### 3.2 Test CLI Script (Send Manual Push)
```bash
# Setup env
export GOOGLE_APPLICATION_CREDENTIALS="~/secure/firebase-service-account.json"

# Test broadcast push (send to all users)
node send_push.js --type=broadcast --title="Hello" --body="Test broadcast"
```
- [ ] Script runs without "Set GOOGLE_APPLICATION_CREDENTIALS" error
- [ ] Check Firestore `users` — verify tokens exist
- [ ] Expected: "Multicast result: X success, 0 failure"

### 3.3 Test Process Pending Push Requests
```bash
# Setup (if not already)
export GOOGLE_APPLICATION_CREDENTIALS="~/secure/firebase-service-account.json"

# Create a test push_request manually (via admin app or Firestore)
# Then process
node send_push.js --processPending
```
- [ ] Script processes pending requests
- [ ] Firestore: `push_requests/{doc_id}` → `processed: true`

### 3.4 Test Express Server
```bash
# Setup env
export GOOGLE_APPLICATION_CREDENTIALS="~/secure/firebase-service-account.json"
export PROCESS_API_KEY="test-key-123"

# Start server
node server.js
# Expected output: "FCM helper server listening on 4000"
```

**Test health:**
```bash
curl http://localhost:4000/health
# {"ok":true,"ts":1701169200000}
```

**Test process endpoint:**
```bash
curl -X POST http://localhost:4000/process-push \
  -H "x-api-key: test-key-123"
# {"ok":true,"result":{"processed":0}} or more if pending exists
```

- [ ] Server starts without error
- [ ] Health endpoint works
- [ ] Process endpoint requires correct API key
- [ ] Process endpoint processes pending requests

---

## Phase 4: End-to-End Integration Test

### 4.1 Full Booking → Payment → Confirm Flow

**Setup:** 2 devices atau 2 browser (admin + customer)

**Steps:**

1. **Customer:** Login, create booking request
2. **Admin:** See request → tap "Approve"
   - Expected: Firestore queue status = `awaiting_payment`, notification doc created
3. **Customer:** See notification → see countdown timer (10 menit)
4. **Customer:** Tap "Upload Bukti Pembayaran" → select photo
   - Expected: payment_proof_base64 saved in Firestore queue
5. **Admin:** Open "Payment Verification" → see queue with status `awaiting_payment`
6. **Admin:** See payment proof → tap "Confirm"
   - Expected: queue status = `booked`, notification doc created
7. **Customer:** See notification "Booking confirmed"

- [ ] End-to-end flow works
- [ ] All notifications created automatically
- [ ] Customer receives notification at each step

### 4.2 Admin Send Notification + Push

**Setup:** Server helper running
```bash
export GOOGLE_APPLICATION_CREDENTIALS="~/secure/firebase-service-account.json"
export PROCESS_API_KEY="test-key-123"
node server.js  # in terminal, keep running
```

**Steps:**

1. **Admin:** Dashboard → "Kirim Notifikasi"
2. Select customer, fill Title + Body
3. **Check:** "Kirim push melalui server (jika tersedia)"
4. Click "Kirim"
5. **Verify Firestore:**
   - `notifications/{doc_id}` created
   - `push_requests/{doc_id}` created (with `processed: false`)
6. **Trigger processing:**
   ```bash
   curl -X POST http://localhost:4000/process-push \
     -H "x-api-key: test-key-123"
   ```
7. **Verify Firestore:**
   - `push_requests/{doc_id}` → `processed: true`
8. **Verify customer device:**
   - Should receive push notification

- [ ] Notification doc created
- [ ] Push request doc created
- [ ] Push request processed via server
- [ ] Customer receives push notification

---

## Phase 5: Pre-Production Setup

### 5.1 Environment Variables Setup

**Create `.env` file:**
```bash
cat > ~/.geges_env << 'EOF'
# Firebase Service Account (path to secure location)
GOOGLE_APPLICATION_CREDENTIALS=/home/irsyad/secure/firebase-service-account.json

# Push API Key (generate random)
PROCESS_API_KEY=your-very-secure-random-key-here-min-32-chars-abc123def456ghi789jkl

# Port (optional, default 4000)
PORT=4000

# Node environment
NODE_ENV=production
EOF
```

- [ ] `.env` created and secured
- [ ] Not committed to git
- [ ] API key is random and strong

### 5.2 Firestore Security Rules (Production)

Replace temporary rules with stricter ones:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    
    // Notifications: can read own notifications
    match /notifications/{doc} {
      allow read: if request.auth.uid == resource.data.user_id 
                     || (resource.data.broadcast == true && request.auth != null);
      allow write: if false;  // Only server/admin can write
    }
    
    // Queues: customers can read their own, read all public
    match /queues/{doc} {
      allow read: if request.auth.uid == resource.data.customerId 
                     || request.auth.custom.role == "admin_owner";
      allow write: if request.auth.custom.role == "admin_owner";
    }
    
    // Default deny
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] Rules updated in Firebase Console
- [ ] Test rules work with test users
- [ ] No unauthorized access possible

### 5.3 Hosting Server Helper

**Option A: Docker (Recommended)**

Create `scripts/fcm_sender/Dockerfile`:
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 4000

CMD ["node", "server.js"]
```

Build & run:
```bash
docker build -t geges-fcm-helper:1.0 scripts/fcm_sender/
docker run -d \
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/sa.json \
  -e PROCESS_API_KEY=your-api-key \
  -e PORT=4000 \
  -p 4000:4000 \
  -v ~/secure/firebase-service-account.json:/app/sa.json \
  geges-fcm-helper:1.0
```

- [ ] Dockerfile created
- [ ] Image builds successfully
- [ ] Container runs and processes requests

**Option B: Systemd Service (Linux)**

Create `/etc/systemd/system/geges-fcm-helper.service`:
```ini
[Unit]
Description=GEGES FCM Push Helper
After=network.target

[Service]
Type=simple
User=geges
WorkingDirectory=/opt/geges/scripts/fcm_sender
Environment="GOOGLE_APPLICATION_CREDENTIALS=/opt/geges/secure/firebase-service-account.json"
Environment="PROCESS_API_KEY=your-api-key"
Environment="PORT=4000"
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable & start:
```bash
sudo systemctl enable geges-fcm-helper
sudo systemctl start geges-fcm-helper
sudo systemctl status geges-fcm-helper
```

- [ ] Service file created
- [ ] Service enabled and running
- [ ] Survives system restart

### 5.4 Scheduled Processing (Cron)

Create cron job to process every 5 minutes:
```bash
*/5 * * * * cd /opt/geges/scripts/fcm_sender && export GOOGLE_APPLICATION_CREDENTIALS=/opt/geges/secure/firebase-service-account.json && node send_push.js --processPending >> /var/log/geges-fcm.log 2>&1
```

Add to crontab:
```bash
crontab -e
# paste above line
```

- [ ] Cron job created
- [ ] Verified with `crontab -l`
- [ ] Log file created and rotated

---

## Phase 6: Monitoring & Maintenance

### 6.1 Logs & Monitoring

**Track FCM processing:**
```bash
# Watch logs in real-time
tail -f /var/log/geges-fcm.log

# Or using systemd
journalctl -u geges-fcm-helper -f
```

**Firestore Monitoring:**
- Check `push_requests` collection for failed items
- Monitor `notifications` delivery rate
- Check `users` for empty fcm_token (indicates issues)

- [ ] Logging setup
- [ ] Monitoring dashboard configured
- [ ] Alert rules for failed pushes (optional)

### 6.2 Regular Checks

**Daily:**
- [ ] Check push processing is running
- [ ] Monitor Firestore usage
- [ ] Check for failed push requests

**Weekly:**
- [ ] Review error logs
- [ ] Update Firebase security
- [ ] Backup service account credentials (secure location)

**Monthly:**
- [ ] Rotate API keys
- [ ] Review notification metrics
- [ ] Update dependencies: `npm update`

---

## Quick Reference Commands

### Start Everything (Local Dev)
```bash
# Terminal 1: Flutter app
flutter run -d [device_id]

# Terminal 2: Express server
cd scripts/fcm_sender
export GOOGLE_APPLICATION_CREDENTIALS=~/secure/firebase-service-account.json
export PROCESS_API_KEY=test-key-123
node server.js

# Terminal 3: Test script (optional)
cd scripts/fcm_sender
node send_push.js --processPending
```

### Restart Server Helper
```bash
# If running as service
sudo systemctl restart geges-fcm-helper

# If running in Docker
docker restart geges-fcm-helper

# If running manually
# Kill: Ctrl+C, then restart
```

### Check Firestore
```bash
# Via Firebase Console UI (easiest)
# Or use gcloud CLI:
gcloud firestore documents list notifications
gcloud firestore documents list push_requests
```

### Debug Notification Issues
```bash
# Check FCM token exists
adb shell dumpsys package com.geges.smartbarber | grep fcm

# Or view directly in Firestore:
# users/{uid} → fcm_token field

# Check notification docs
firebase firestore:delete notifications --all  # careful!
```

---

## Emergency Procedures

### If Push Helper is Down

**Temporary:**
- Notifications still work (in-app via Firestore)
- Customers still receive notifications, just no push

**Recovery:**
1. Check logs: `journalctl -u geges-fcm-helper -n 100`
2. Restart: `sudo systemctl restart geges-fcm-helper`
3. Monitor: `journalctl -u geges-fcm-helper -f`

### If Service Account is Compromised

1. Revoke old key in Firebase Console (Service Accounts → delete key)
2. Generate new key
3. Update `.env` file
4. Restart server helper
5. Monitor for suspicious activity

### If Firestore Rules Block Valid Requests

1. Temporarily use dev rules: `allow read, write: if request.auth != null;`
2. Debug the issue
3. Update rules gradually
4. Test with real users

---

## Support & References

- **Firebase Console:** https://console.firebase.google.com/
- **Firebase Admin SDK:** https://firebase.google.com/docs/admin/setup
- **FCM Documentation:** https://firebase.google.com/docs/cloud-messaging
- **Firestore Documentation:** https://firebase.google.com/docs/firestore
- **Guide:** See `SETUP_NOTIFICATIONS_PAYMENTS_GUIDE.md`

---

**Created:** November 28, 2025  
**Last Updated:** November 28, 2025

---

## Tanda Tangan Verifikasi

Setelah semua checklist selesai:

- [ ] Developer lead sign-off
- [ ] QA testing passed
- [ ] Production deployment approved
- [ ] Monitoring setup verified

**Date:** _____________  
**Signature:** _____________
