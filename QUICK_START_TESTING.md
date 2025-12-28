# GEGES SmartBarber: Quick Start Guide (Testing)

**Durasi:** ~15 menit untuk testing end-to-end

---

## Prerequisites Cepat

```bash
# 1. Clone service account ke lokasi aman
cp ~/Downloads/firebase-service-account.json ~/secure/

# 2. Set env variables (untuk push helper)
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/secure/firebase-service-account.json"
export PROCESS_API_KEY="my-test-key-123"

# 3. Pastikan Flutter app sudah build
cd /home/irsyad/Documents/geges_smartbarber
flutter pub get
```

---

## Testing Scenario 1: In-App Notifications (5 menit)

### Terminal 1: Run Flutter App
```bash
flutter run -d 10.10.10.9:5555
# Tunggu app fully loaded
```

### Login dengan 2 Akun (Browser/Emulator lain)

**Account 1 (Admin):**
- Email: admin@geges.com (atau yang sudah terdaftar)
- Password: [password admin]

**Account 2 (Customer):**
- Email: customer@geges.com (atau yang sudah terdaftar)
- Password: [password customer]

### Test Buat Notifikasi

**Sebagai Admin:**
1. Tap **Dashboard** → **Kirim Notifikasi**
2. Di field "User ID atau cari nama":
   - Ketik nama customer (misal: "Ahmad")
   - Tunggu 0.5 detik (debounce)
   - Tap hasil search
3. Judul: `Tes Notifikasi`
4. Isi: `Ini adalah tes notifikasi`
5. Queue ID: *kosongkan*
6. Uncheck "Broadcast ke semua pengguna"
7. Uncheck "Kirim push melalui server"
8. **Tap "Kirim"**

### Verifikasi di Firestore

Buka **Firebase Console** → **Firestore**:
```
notifications (collection)
├─ [doc_id]
   ├─ title: "Tes Notifikasi"
   ├─ body: "Ini adalah tes notifikasi"
   ├─ user_id: "[customer_uid]"
   ├─ broadcast: false
   ├─ delivered: false
   └─ created_at: [timestamp]
```

### Lihat di Customer Device

**Sebagai Customer:**
- Lihat notifikasi muncul di **notification bar** (Android) atau **banner** (iOS)
- Tap notifikasi
- **Expected:** Buka app (atau page terkait, atau booking list)

✅ **Test 1 Selesai**

---

## Testing Scenario 2: Push Notifications (10 menit)

### Setup Express Server

**Terminal 2:** (jangan close Terminal 1)
```bash
cd /home/irsyad/Documents/geges_smartbarber/scripts/fcm_sender

# Verify dependencies sudah terinstall
npm list | grep express

# Set env variables
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/secure/firebase-service-account.json"
export PROCESS_API_KEY="test-key-123"

# Start server
node server.js

# Expected output:
# FCM helper server listening on 4000
```

### Admin Send Notification + Request Push

**Terminal 1 (Admin di app):**
1. Dashboard → **Kirim Notifikasi**
2. Cari customer lagi (misal: "Ahmad")
3. Judul: `Push Test`
4. Isi: `Ini test push notification`
5. Queue ID: *kosongkan*
6. Uncheck "Broadcast"
7. **CHECK "Kirim push melalui server"**
8. Tap **"Kirim"**

### Verify Push Request Dibuat

**Firebase Console → Firestore:**
```
push_requests (collection)
├─ [doc_id]
   ├─ title: "Push Test"
   ├─ body: "Ini test push notification"
   ├─ user_id: "[customer_uid]"
   ├─ broadcast: false
   ├─ processed: false
   └─ created_at: [timestamp]
```

### Proses Push via Server

**Terminal 3:** (atau di Terminal 2 setelah stop server, tapi lebih baik buka Terminal baru)
```bash
cd /home/irsyad/Documents/geges_smartbarber/scripts/fcm_sender

# Trigger processing
curl -X POST "http://localhost:4000/process-push" \
  -H "x-api-key: test-key-123"

# Expected response:
# {"ok":true,"result":{"processed":1}}
```

### Verify Push Processed

**Firebase Console → Firestore:**
```
push_requests/[doc_id]
├─ processed: true
├─ processed_at: [timestamp]
├─ result: "ok"
```

### Lihat Push di Device

**Customer device:**
- Notification muncul dari FCM (tidak hanya in-app)
- Tap untuk lihat detail
- Expected: buka app atau booking screen

✅ **Test 2 Selesai**

---

## Testing Scenario 3: Booking Payment Flow (Optional, ~5 menit)

Ini lebih kompleks, tapi skenario nyata.

### Admin Approve Booking Request

**Sebagai Admin:**
1. Dashboard → **Booking Requests**
2. Pilih pending request
3. Tap **"Approve"**
4. Expected: Status → `awaiting_payment`, notification otomatis dibuat

### Customer Upload Payment Proof

**Sebagai Customer:**
1. Dashboard → **My Bookings**
2. Tap booking yang status `awaiting_payment`
3. Lihat **countdown timer** (9 menit 55 detik, misal)
4. Tap **"Upload Bukti Pembayaran"**
5. Pilih foto dari galeri
6. Tunggu upload selesai
7. Lihat preview foto

### Admin Verify Payment

**Sebagai Admin:**
1. Dashboard → **Payment Verification**
2. Lihat list dengan status `awaiting_payment`
3. Lihat preview foto
4. Tap **"Confirm"** (atau "Reject")
5. Expected: Status → `booked`, notification dibuat

### Customer Menerima Confirmation

**Sebagai Customer:**
1. Notification muncul: "Booking confirmed"
2. Tap notifikasi → lihat booking detail dengan status `booked`

✅ **Test 3 Selesai**

---

## Troubleshooting Cepat

| Problem | Solution |
|---------|----------|
| Notifikasi tidak muncul | Check app permission, restart app, ensure fcm_token saved |
| Push request tidak process | Ensure PROCESS_API_KEY benar, check server logs |
| App crash saat notification tap | Check console error, ensure app_navigator.dart imported |
| Payment proof tidak save | Check image picker permission, ensure internet connection |
| Server returns "invalid_api_key" | Check `-H "x-api-key: test-key-123"` matches PROCESS_API_KEY env |

---

## Cleanup & Reset

Jika ingin clean slate untuk test berikutnya:

### Hapus Test Data (Firestore)

⚠️ **Caution: Destructive operation**

```bash
# Via Firebase Console UI:
# 1. Firestore → notifications
# 2. Select test docs → Delete
# 3. Repeat untuk push_requests

# Atau via gcloud CLI:
gcloud firestore documents delete notifications/[doc_id]
gcloud firestore documents delete push_requests/[doc_id]
```

### Logout & Login Ulang

```bash
# Terminal 1 (app):
# Tap "Logout"
# Login ulang sebagai admin/customer
```

---

## Success Checklist

- [ ] Notifikasi in-app muncul ketika admin buat
- [ ] Tap notification → navigate ke booking/page
- [ ] Push request created di Firestore
- [ ] Server process push via curl
- [ ] Customer menerima push notification
- [ ] Payment countdown works
- [ ] Payment proof upload works
- [ ] Admin verify payment + notification sent

---

## Next Steps

Setelah testing berhasil:

1. **Review** `SETUP_NOTIFICATIONS_PAYMENTS_GUIDE.md` untuk detail
2. **Follow** `SETUP_OPERATIONS_CHECKLIST.md` untuk production setup
3. **Deploy** Express server ke cloud (GCP, AWS, atau internal server)
4. **Monitor** push delivery rates & errors

---
CI & running slow/integration tests

- The repo CI is split into **fast** (unit + widget) and **slow/integration** tests. Fast tests run on PRs and on push; slow/integration tests run on `main` or via manual workflow dispatch.
- To run slow/integration tests locally, run only files that include `integration` or `e2e` in their names:

```bash
# run slow/integration tests locally
flutter test "$(git ls-files 'test/**' | grep -E 'integration|e2e')"
```

- During local test development you can enable network calls for tests that require real HTTP by calling `enableNetworkCalls()` from `test/test_utils.dart` in your test setup or by running the integration workflow manually in CI.

---
**Happy Testing! 🚀**

Jika ada error, check console logs:
```bash
# Android
adb logcat | grep "GEGES\|FCM\|NotificationService"

# iOS (in Xcode or)
log stream --predicate 'process == "geges_smartbarber"'
```

---

Created: November 28, 2025
