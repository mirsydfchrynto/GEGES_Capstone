# GEGES SmartBarber: Notifications & Payments Complete Setup Guide

**Tanggal**: November 28, 2025  
**Status**: Semua fitur sudah terintegrasi dan siap digunakan

---

## 📋 Daftar Isi

1. [Gambaran Umum (Overview)](#gambaran-umum)
2. [Alur Bisnis: Booking → Payment → Admin Confirm](#alur-bisnis)
3. [Sistem Notifikasi Client-Side](#sistem-notifikasi-client)
4. [Admin: Mengirim Notifikasi](#admin-kirim-notifikasi)
5. [Server Helper: Mengirim Push FCM](#server-helper)
6. [Setup & Instalasi](#setup-instalasi)
7. [Testing & Troubleshooting](#testing-troubleshooting)

---

## Gambaran Umum

Sistem yang telah dibangun mencakup:

### ✅ 1. **Two-Step Admin Booking Flow**
   - Admin terima request → approve (set status `awaiting_payment`, customer punya 10 menit untuk upload bukti bayar)
   - Customer upload bukti bayar (payment proof sebagai base64 di Firestore)
   - Admin verifikasi bukti → confirm (status berubah ke `booked`)

### ✅ 2. **In-App Notifications (Firestore-driven)**
   - Ketika admin approve request atau verifikasi payment, sistem otomatis buat dokumen di collection `notifications`
   - Client app (`NotificationService`) listen dokumen `notifications` dan tampilkan local OS notification
   - Customer bisa tap notifikasi untuk buka booking detail

### ✅ 3. **FCM Push Notifications (Optional)**
   - Device tokens disimpan di `users/{uid}.fcm_token`
   - Admin bisa pilih "Kirim push melalui server" saat buat notifikasi → create `push_requests` document
   - Server helper (Node.js) proses `push_requests` dan kirim push via Firebase Cloud Messaging

### ✅ 4. **Payment Proof Upload & Countdown**
   - Customer lihat countdown (10 menit) di booking detail screen
   - Upload foto bukti bayar → disimpan di Firestore sebagai base64 (image string)
   - Countdown berubah warna (hijau → kuning → merah) sesuai sisa waktu

---

## Alur Bisnis

### Skenario 1: Customer Request Booking

```
1. Customer buat booking request
2. Admin melihat di "Booking Requests" screen
3. Admin tap "Approve" → 
   - Status: waiting → awaiting_payment
   - Payment deadline: sekarang + 10 menit
   - Firestore: create notifications doc (customer diberitahu untuk upload bukti)
   - Customer menerima in-app notification
```

### Skenario 2: Customer Upload Payment Proof

```
1. Customer buka booking detail
2. Lihat countdown timer (9 menit 30 detik, misal)
3. Tap "Upload Bukti Pembayaran"
4. Pilih foto dari galeri
5. Foto ter-upload di field payment_proof_base64 (Firestore)
6. Tunggu admin verifikasi
```

### Skenario 3: Admin Verifikasi Payment

```
1. Admin buka "Payment Verification" screen (di Admin Dashboard)
2. Lihat daftar queue dengan status awaiting_payment
3. Lihat preview foto bukti pembayaran
4. Tap "Confirm" atau "Reject"
5. Jika Confirm:
   - Status: awaiting_payment → booked
   - Firestore: create notifications doc (customer diberitahu booking sudah confirmed)
   - Customer menerima in-app notification
6. Jika Reject:
   - Status: awaiting_payment → cancelled
   - Customer notifikasi bahwa pembayaran ditolak
```

---

## Sistem Notifikasi Client

### File Terkait

- **`lib/services/notification_service.dart`** — Service utama FCM & local notifications
- **`lib/services/app_navigator.dart`** — Global navigator key untuk navigasi dari notification tap
- **`lib/screens/customer/notifications_screen.dart`** — UI menampilkan daftar notifikasi

### Cara Kerja

#### 1. Initialization (`main.dart`)
```dart
import 'package:geges_smartbarber/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Init notification service (FCM token + local notifications)
  await NotificationService.instance.init();
  
  runApp(const MyApp());
}
```

#### 2. Automatic FCM Token Saving
Ketika user login:
- `NotificationService` save device token ke `users/{uid}.fcm_token`
- Token tetap tersimpan untuk push notifications di kemudian hari

#### 3. Listening to Firestore Notifications
`NotificationService` listen dua jenis notifikasi:

**a) Personal Notifications:**
```firestore
collection('notifications')
  .where('user_id', '==', currentUser.uid)
  .where('delivered', '==', false)
```

**b) Broadcast Notifications:**
```firestore
collection('notifications')
  .where('broadcast', '==', true)
  .where('delivered', '==', false)
```

#### 4. When Notification Arrives
- Show local OS notification (Android: notification bar, iOS: banner/alert)
- Mark `delivered: true` di Firestore
- Tunggu user tap

#### 5. Tap Navigation
Ketika user tap notification:
- Extract `queue_id` dari notification payload
- Navigate ke `BookingDetailScreen(queueId: queue_id)`
- User bisa lihat booking detail + continue payment/upload

### Firestore Collection: `notifications`

**Schema:**
```firestore
notifications/{doc_id}
  - title: String (misal: "Persetujuan Booking")
  - body: String (misal: "Booking Anda sudah disetujui. Mohon upload bukti bayar dalam 10 menit")
  - user_id: String (uid customer, atau kosong jika broadcast)
  - broadcast: Boolean (true = untuk semua user)
  - queue_id: String (opsional, ID booking yang ditujukan)
  - created_at: Timestamp
  - delivered: Boolean (default: false, berubah true setelah dinotifikasikan)
  - delivered_at: Timestamp
  - read: Boolean (opsional)
```

---

## Admin: Mengirim Notifikasi

### Location: Admin Dashboard → Kirim Notifikasi

**File:** `lib/screens/admin/send_notification_screen.dart`

### Fitur

1. **Pilih User (Autocomplete)**
   - Ketik nama customer atau UID
   - Debounced search 400ms (tidak perlu setiap keystroke)
   - Hasil: lihat nama + email customer
   - Tap untuk select

2. **Broadcast Mode**
   - Centang "Broadcast ke semua pengguna"
   - Otomatis kosongkan user field
   - Notifikasi akan dikirim ke SEMUA customer yang terdaftar

3. **Kirim Push (Opsional)**
   - Centang "Kirim push melalui server (jika tersedia)"
   - Selain buat dokumen `notifications` (Firestore), akan buat `push_requests` document
   - Server helper kemudian process & kirim push

4. **Queue ID (Opsional)**
   - Isi queue ID jika notifikasi terkait booking tertentu
   - Ketika user tap notifikasi, navigate ke booking itu

### Contoh Penggunaan

#### Skenario: Admin Approve Booking Request
```
1. Admin sudah lihat request di "Booking Requests"
2. Tap "Approve" → otomatis create notifications doc (dari queue_service.dart)
3. TAPI kalau mau send push juga (opsional):
   - Admin buka "Kirim Notifikasi"
   - Cari user (misal: "Ahmad")
   - Judul: "Booking Disetujui"
   - Isi: "Booking Anda jam 14:00 sudah disetujui, mohon upload bukti bayar dalam 10 menit"
   - Queue ID: [isi ID booking yang approved]
   - Centang "Kirim push melalui server"
   - Tap "Kirim"
4. Notifikasi terkirim:
   - Ke Firestore (`notifications` collection)
   - Ke `push_requests` (jika server helper running, akan diproses)
```

---

## Server Helper: Mengirim Push FCM

### Lokasi: `scripts/fcm_sender/`

### Dua Cara Menjalankan

#### Cara 1: CLI Script (Manual)

**File:** `send_push.js`

**Setup:**
```bash
cd scripts/fcm_sender
npm install
```

**Set Credentials:**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
# atau
export FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
```

**Jalankan:**
```bash
# Proses semua pending push_requests (dari admin app)
node send_push.js --processPending

# Atau kirim push manual ke user tertentu
node send_push.js --type=personal --uid=<USER_UID> --title="Hello" --body="Test" --queue=<QUEUE_ID>

# Atau broadcast manual ke semua user
node send_push.js --type=broadcast --title="Promo" --body="Diskon hari ini"
```

#### Cara 2: Express Server (HTTP Endpoint)

**File:** `server.js`

**Setup:**
```bash
cd scripts/fcm_sender
npm install
```

**Set Credentials & API Key:**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/home/irsyad/Downloads/artful-bonito-478605-p3-3a8da4a98d2d.json"
export PROCESS_API_KEY="AIzaSyAdCiHw1pxYa5UOgVDH59LVLps3-M5veSU"
export PORT=4000 
```

**Jalankan Server:**
```bash
node server.js
# Output: FCM helper server listening on 4000
```

**Trigger Processing (dari mana saja):**
```bash
# Via curl
curl -X POST "http://localhost:4000/process-push" \
  -H "x-api-key: your-secret-api-key"

# Response:
# {"ok": true, "result": {"processed": 2}}
```

**Health Check:**
```bash
curl "http://localhost:4000/health"
# {"ok": true, "ts": 1701169200000}
```

### Firebase Service Account Setup

#### Dapatkan Service Account JSON

1. Login ke **Firebase Console** → project Anda
2. Project Settings → Service Accounts tab
3. Click "Generate New Private Key"
4. File `service-account.json` downloaded

#### Simpan & Protect
```bash
# Simpan di lokasi aman (bukan di repo!)
mv ~/Downloads/service-account.json ~/secure/firebase-service-account.json

# Set permission (Linux/Mac)
chmod 600 ~/secure/firebase-service-account.json

# Jangan commit ke git!
# Pastikan `.gitignore` sudah exclude file ini
```

---

## Setup & Instalasi

### Prerequisites

- **Flutter** (untuk app development)
- **Node.js** 14+ (untuk server helper)
- **Firebase Project** yang sudah active
- **Service Account** dari Firebase

### Step-by-Step

#### 1. Flutter App Setup

Sudah done. Pastikan `pubspec.yaml` punya dependencies:
```yaml
dependencies:
  firebase_core: ^24.0.0
  firebase_auth: ^4.13.0
  cloud_firestore: ^4.14.0
  firebase_messaging: ^14.7.0
  flutter_local_notifications: ^17.1.0
  # ... lainnya
```

**Jalankan app:**
```bash
flutter pub get
flutter run -d <device_id>
```

#### 2. Firestore Setup

Pastikan rules allow authenticated read/write:
```firestore_rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

#### 3. FCM Setup (Optional untuk Push)

1. **Android:**
   - `google-services.json` sudah di project? ✓
   - Di `android/app/google-services.json`

2. **iOS:**
   - Setup APNs cert di Firebase Console
   - Download `GoogleService-Info.plist` → add ke `ios/Runner`

3. **Verify Token Saving:**
   - Login ke app
   - Check Firestore: `users/{uid}` → pastikan `fcm_token` terisi

#### 4. Server Helper Setup

```bash
# Masuk ke folder helper
cd scripts/fcm_sender

# Install dependencies
npm install

# Setup .env
cat > .env << EOF
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
PROCESS_API_KEY=your-secret-key-123
PORT=4000
EOF

# Test jalankan
node send_push.js --processPending
```

---

## Testing & Troubleshooting

### Test 1: Admin Membuat Notifikasi (In-App)

**Steps:**
1. Buka app → login sebagai admin
2. Dashboard → "Kirim Notifikasi"
3. Jangan centang broadcast, pilih customer
4. Judul: "Test Notifikasi", Isi: "Ini test"
5. Tap "Kirim"
6. **Expected:** Notifikasi doc tercipta di Firestore `notifications`

**Check di Firestore:**
```
notifications/[doc_id]
  - title: "Test Notifikasi"
  - body: "Ini test"
  - user_id: "[customer_uid]"
  - delivered: false
  - broadcast: false
```

### Test 2: Customer Menerima In-App Notification

**Steps:**
1. Login sebagai customer (bukan admin)
2. Tunggu NotificationService detect new doc
3. **Expected:** Local OS notification muncul (notification bar Android / banner iOS)

**If tidak muncul:**
- Check `logcat` (Android) atau `Console` (iOS)
- Verify `fcm_token` tersimpan di `users/{uid}`
- Verify app permission: notification enabled?

### Test 3: Tap Notification → Navigate to Booking

**Steps:**
1. Notifikasi muncul
2. Tap notification
3. **Expected:** Buka BookingDetailScreen untuk queue tersebut

**If tidak navigate:**
- Check `queue_id` ada di payload? `notification.queue_id`
- Check `app_navigator.dart` registered di `MaterialApp.navigatorKey`

### Test 4: Server Helper - Process Pending Push Requests

**Steps:**
1. Admin: Buat notifikasi + centang "Kirim push melalui server"
2. Check Firestore: `push_requests/{doc_id}` created dengan `processed: false`
3. Run script:
   ```bash
   cd scripts/fcm_sender
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
   node send_push.js --processPending
   ```
4. **Expected:** Script log "Processed push_request [doc_id]"
5. Check Firestore: `push_requests/{doc_id}` now `processed: true`

**If error:**
```
Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON in env
```
→ Pastikan service account path benar

```
Error: Invalid service account
```
→ Pastikan JSON file valid, atau credentials file corrupt

### Test 5: Express Server

**Steps:**
1. Start server:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
   export PROCESS_API_KEY="my-secret-123"
   node server.js
   ```
2. Health check:
   ```bash
   curl http://localhost:4000/health
   # {"ok":true,"ts":1701169200000}
   ```
3. Process pushes:
   ```bash
   curl -X POST http://localhost:4000/process-push \
     -H "x-api-key: my-secret-123"
   # {"ok":true,"result":{"processed":1}}
   ```
4. Wrong API key:
   ```bash
   curl -X POST http://localhost:4000/process-push \
     -H "x-api-key: wrong-key"
   # {"ok":false,"error":"invalid_api_key"}
   ```

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| Notifikasi tidak muncul | `fcm_token` kosong | Login dengan user lain, tunggu token save |
| Tap notification tidak navigate | `queue_id` null di payload | Pastikan admin isi Queue ID saat buat notifikasi |
| Server helper error "no_token" | Customer tidak punya token | Customer belum login/enable notification |
| Push tidak terkirim | Service account invalid | Download ulang dari Firebase Console |
| App crash saat login | NotificationService init error | Check imports, pastikan `app_navigator.dart` ada |

---

## Production Checklist

- [ ] Service account JSON disimpan di server internal (bukan repo)
- [ ] API key (`PROCESS_API_KEY`) di-generate random & aman
- [ ] Server helper di-host di internal network atau VPC (bukan public)
- [ ] Firestore rules di-update (default allow semua auth user ≠ aman)
- [ ] Enable APNs certificate (iOS push)
- [ ] Test di real device (notification permissions penting)
- [ ] Setup automated push processing (cron job / systemd timer)
- [ ] Monitor push delivery rates & errors

---

## File Referensi

### Client App
- `lib/services/notification_service.dart` — FCM + local notification logic
- `lib/services/app_navigator.dart` — Global navigator untuk tap handling
- `lib/services/queue_service.dart` — Auto-create notifications saat admin action
- `lib/screens/admin/send_notification_screen.dart` — Admin UI untuk buat notifikasi
- `lib/screens/admin/payment_verification_screen.dart` — Admin UI untuk verifikasi bayar
- `lib/screens/customer/booking_detail_screen.dart` — Customer lihat countdown & upload bukti

### Server Helper
- `scripts/fcm_sender/send_push.js` — CLI script untuk push
- `scripts/fcm_sender/server.js` — Express server untuk push processing
- `scripts/fcm_sender/package.json` — Dependencies
- `scripts/fcm_sender/.env.example` — Template env vars

---

## Next Steps (Opsional)

1. **Improve Push Analytics**
   - Track "push_delivered", "push_opened" metrics
   - Store di Firestore untuk admin dashboard

2. **Scheduled Push**
   - Admin bisa schedule notifikasi untuk waktu tertentu
   - Server process scheduled push di background

3. **Push Templates**
   - Buat template notifikasi yang reusable
   - Admin cukup pilih template + custom content

4. **Payment Proof Storage Optimization**
   - Migrasi base64 ke Firebase Storage
   - Compress image sebelum upload
   - CDN untuk fast retrieval

5. **Admin Dashboard Analytics**
   - Notifikasi sent/delivered/opened count
   - Booking success rate (approve → payment confirmed)
   - Revenue tracking

---

**Dibuat oleh:** GitHub Copilot  
**Last Updated:** November 28, 2025

Jika ada pertanyaan atau issue, lihat section [Testing & Troubleshooting](#testing-troubleshooting).
