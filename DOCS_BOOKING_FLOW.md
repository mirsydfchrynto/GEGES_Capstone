# 📋 DOKUMENTASI ALUR BOOKING APLIKASI GEGES SMARTBARBER

## 🎯 Ringkasan

Alur booking dirancang untuk memastikan customer dapat memesan layanan barbershop dengan aman, terstruktur, dan terintegrasi dengan sistem pembayaran. Sistem ini meminimalkan celah kecurangan, double-booking, dan kesalahpahaman melalui validasi multi-layer dan status tracking yang jelas.

---

## 📊 STATUS BOOKING (STATE DIAGRAM)

```
waiting 
  ↓ (admin confirm payment)
booked 
  ├─ (customer request cancellation) → cancellation_requested
  │    ├─ (admin approve) → refund_pending → (system: complete)
  │    └─ (admin reject) → booked (kembali)
  │
  ├─ (start service) → ongoing
  │    └─ (finish service) → served
  │         └─ (customer rate) → served + rating
  │
  └─ (admin reject payment) → cancelled

cancelled (terminal status)
refund_pending (terminal status)
served (terminal status)
```

### Status Detail

| Status | Deskripsi | Aksi Customer | Aksi Admin |
|--------|-----------|---------------|-----------|
| **waiting** | Booking baru, menunggu konfirmasi pembayaran admin | Lihat countdown 10 menit pembayaran | Cek bukti pembayaran, confirm/reject |
| **booked** | Pembayaran confirmed, pesanan aktif | Bisa batalkan dengan alasan | Mulai/selesai service, atau konfirmasi pembatalan |
| **ongoing** | Service sedang berjalan | Tidak bisa batalkan | Tombol "Selesai" untuk ubah ke served |
| **served** | Service selesai | Kasih rating + comment | Lihat rating di dashboard |
| **cancelled** | Pembatalan approved atau timeout payment | - | Lihat alasan pembatalan |
| **refund_pending** | Refund approval selesai, uang akan dikembalikan | Tunggu uang masuk | Upload bukti refund (opsional, audit trail) |

---

## 🔄 ALUR BOOKING LENGKAP

### 1️⃣ APPOINTMENT SCREEN (Customer Membuat Pesanan)

**File:** `lib/screens/customer/appointment_screen.dart`

#### Validasi Input
- ✅ Pilih **minimal 1 layanan** (multiple selection allowed)
- ✅ Pilih **1 hair specialist** (single selection, required)
- ✅ Pilih **tanggal**: tidak bisa mundur dari hari ini (firstDate = DateTime.now())
- ✅ Pilih **waktu**:
  - Harus dalam jam operasional barbershop (barbershop.openHour — barbershop.closeHour)
  - Jika hari ini: tidak bisa pilih waktu yang sudah lewat
  - Sistem akan check apakah jam tersebut bentrok dengan booking sebelumnya

#### Contoh Flow Validasi Waktu
```dart
// Saat customer pilih waktu
final now = DateTime.now();
final isToday = _selectedDate.year == now.year && ...;
if (isToday && pickedDateTime.isBefore(now)) {
  // Reject: "Tidak bisa memilih waktu yang sudah lewat"
}
```

#### Slot Availability Check
Sebelum submit, aplikasi query Firestore:
```
Cek apakah ada queue dengan:
- barbershop_id = selected barbershop
- barberman_id = selected barberman
- status = "booked" ATAU "ongoing"
- booking_time + duration bertumbukan dengan selected time

Jika ya → "Slot bentrok dengan booking lain" → reject
Jika tidak → "Slot tersedia" → allow submit
```

#### Proses Submit Booking
1. Validasi semua field (service, barberman, date, time)
2. Validasi booking time bukan masa lalu
3. Buat queue document di Firestore dengan:
   - `status: 'waiting'` (default)
   - `payment_due_at: now + 10 minutes` (otomatis dihitung)
   - `booking_time: selectedDateTime`
   - `service_ids, total_price, estimated_duration`
4. Navigate ke **Payment Screen**

**Catatan:** Transaksi Firestore memastikan tidak ada race condition. Jika 2 customer memesan slot sama, hanya 1 yang berhasil (first-win).

---

### 2️⃣ PAYMENT SCREEN (Customer Upload Bukti Pembayaran)

**File:** `lib/screens/customer/payment_screen.dart`

#### Countdown Timer
- Durasi: **10 menit** dari saat booking dibuat (`payment_due_at`)
- Setiap second, timer berkurang
- Jika habis → button Submit disabled
- Jika habis dan belum submit → booking otomatis di-cancel (client-side call `cancelExpiredWaitingQueuesForCustomer`)

#### Informasi Pembayaran
- Nomor rekening: BCA 87705955837 (FEBRIAN BARBERSHOP)
- Nominal: jumlah yang tepat (copy button tersedia)
- Order ID: untuk tracking pembayaran

#### Upload Bukti Pembayaran
1. Customer tap "Upload Payment Proof"
2. Pilih dari **Gallery** atau **Camera**
3. Crop/review gambar jika perlu
4. Tap **Submit Proof & Create Queue**
5. Sistem:
   - Convert gambar → Base64
   - Update queue document dengan:
     - `payment_proof_base64: <image data>`
     - `payment_submitted_at: serverTimestamp()`
     - `payment_method: 'bank_transfer'`
     - `status: 'waiting'` (tetap)
   - Pop ke halaman sebelumnya dengan result `true`

#### Hasil Submit
- ✅ Booking terlihat di halaman **My Bookings** dengan status "Waiting Payment Confirmation"
- ⏳ Customer menunggu admin confirm (maksimal 1-10 menit sesuai jam kerja)
- 📱 (Nanti) Notifikasi dikirim ke customer saat admin confirm/reject

---

### 3️⃣ ADMIN DASHBOARD - BOOKING REQUESTS (Admin Konfirmasi Pembayaran)

**File:** `lib/screens/admin/` (perlu dibuat/diperbaiki)

#### List Booking Requests
Admin melihat queue dengan `status: 'waiting'`:
- Barbershop ID sesuai dengan barbershop admin tersebut
- Tampilkan: customer name, service, booking time, total price, bukti pembayaran (image preview)

#### Aksi Admin
1. **Confirm Payment**
   - Tap "Konfirmasi Pembayaran"
   - (Opsional) Input admin notes (e.g., "Transfer confirmed via bank app")
   - System update queue:
     ```
     status: 'booked'
     payment_confirmed_at: serverTimestamp()
     payment_confirmed_by: adminUid
     admin_payment_notes: '...'
     ```
   - Customer notified (nanti via notification system)

2. **Reject Payment**
   - Tap "Tolak Pembayaran"
   - Input alasan (e.g., "Bukti transfer tidak jelas", "Jumlah kurang")
   - System update queue:
     ```
     status: 'cancelled'
     cancellation_reason: 'Rejected by admin - payment not confirmed'
     cancelled_by_uid: adminUid
     ```
   - Customer bisa lihat alasan di **My Bookings** → detail booking

---

### 4️⃣ LIVE QUEUE / ONGOING SERVICE (Barberman/Admin Mulai Service)

**File:** `lib/screens/admin/live_queue_screen.dart` atau halaman queue barbershop

#### Daftar Booking Aktif (Status Booked)
Admin/barberman melihat list queue dengan `status: 'booked'` untuk barbershop mereka:
- Urut berdasarkan `booking_time` (ascending)
- Tampilkan: customer name, service, barberman, waktu booking

#### Tombol "Mulai Potong" (Start Service)
1. Tap tombol untuk booking tertentu
2. System update queue:
   ```
   status: 'ongoing'
   start_time: serverTimestamp()
   ```
3. Queue bergerak dari **list booked** → **list ongoing**
4. (Nanti) Notifikasi ke customer: "Barberman Anda siap"

#### Tombol "Selesai" (Finish Service)
1. Tap tombol setelah service selesai
2. System update queue:
   ```
   status: 'served'
   finish_time: serverTimestamp()
   actual_duration: (finish_time - start_time) in minutes
   ```
3. Queue hilang dari **list ongoing**
4. (Nanti) Notifikasi ke customer: "Service selesai, kasih rating"

---

### 5️⃣ MY BOOKINGS / HISTORY (Customer Lihat Riwayat & Rating)

**File:** `lib/screens/customer/tabs/my_bookings_screen.dart` (perlu update)

#### Status Waiting
```
[Status Badge: "Waiting Payment Confirmation"]
Admin sedang memeriksa bukti pembayaran Anda.
Estimasi 1-10 menit sesuai jam kerja barbershop.
Jangan tutup aplikasi.
```
- Countdown timer (jika masih < 10 menit dari `payment_due_at`)
- Tombol "Kembali ke Payment" (jika ingin lihat bukti lagi)

#### Status Booked
```
[Status Badge: "Booked"]
Pembayaran confirmed! Barbershop siap melayani.
Estimasi selesai: [waktu] (dari booking_time + estimated_duration)

[Tombol] BATALKAN PESANAN (dengan dialog alasan)
```

#### Status Ongoing
```
[Status Badge: "Ongoing"]
Sedang dipotong oleh [barberman name]...
Estimasi selesai: [waktu]

❌ Tidak bisa batalkan (service sedang berjalan)
```

#### Status Served
```
[Status Badge: "Completed"]
Service selesai! 🎉

[Bintang Rating] ⭐⭐⭐⭐ (jika sudah rate)
[Tombol] Kasih Rating (jika belum rate)
```

---

### 6️⃣ CANCELLATION FLOW (Customer Batalkan + Admin Approve)

**File:** `lib/screens/customer/tabs/my_bookings_screen.dart` + `lib/screens/admin/`

#### Customer Request Cancellation

**Dari Status Booked:**
1. Tap tombol "BATALKAN PESANAN"
2. Dialog muncul: "Masukkan alasan pembatalan"
   - Text field untuk input (e.g., "Jadwal berubah", "Sakit", dll)
3. Tap "Lanjutkan"
4. System calculate refund:
   ```
   refund_amount = total_price * 0.9  // 90% (10% dipotong)
   deduction = total_price * 0.1      // 10%
   ```
5. Dialog konfirmasi: "Pembatalan akan memotong 10% dari total pembayaran. Lanjutkan?"
6. Tap "Ya, batalkan"
7. System update queue:
   ```
   status: 'cancellation_requested'
   cancellation_reason: '...'
   cancellation_requested_by: customerId
   cancellation_requested_at: serverTimestamp()
   refund_amount: int
   original_price: int
   refund_deduction: int
   ```
8. Customer status berubah: "Waiting for Cancellation Approval" 
   - Tampilkan refund amount dan deduction

#### Admin Approve Cancellation

**Admin Dashboard → Cancellation Requests:**
1. Lihat list dengan `status: 'cancellation_requested'`
2. Review alasan customer
3. Tap "Setujui Pembatalan"
4. (Opsional) Upload bukti refund (screenshot transfer, dll)
5. System update queue:
   ```
   status: 'refund_pending'
   cancellation_approved_at: serverTimestamp()
   cancellation_approved_by: adminUid
   refund_proof_base64: <image data jika ada>
   refund_approved_at: serverTimestamp()
   ```
6. Customer status: "Refund Pending"
   - Tampilkan amount refund + bukti refund (jika ada)
   - Instruksi: "Refund akan masuk dalam 1-3 hari kerja"

#### Admin Reject Cancellation

1. Tap "Tolak Pembatalan"
2. Input alasan (e.g., "Service sudah dimulai, tidak bisa dibatalkan")
3. System update queue:
   ```
   status: 'booked'  // kembali ke status booked
   cancellation_rejected_at: serverTimestamp()
   cancellation_rejected_by: adminUid
   cancellation_rejection_reason: '...'
   ```
4. Customer notified & status kembali normal

---

### 7️⃣ RATING (Customer Kasih Rating Setelah Served)

**File:** `lib/screens/customer/tabs/my_bookings_screen.dart`

#### Submit Rating
1. Status booking = **served**
2. Tap tombol "Kasih Rating"
3. Dialog muncul:
   - Bintang rating (1-5)
   - Text field optional untuk comment
4. Tap "Kirim Rating"
5. System update queue:
   ```
   status: 'served' (tetap)
   rating: 4.5  // float 1-5
   rating_comment: '...'
   rating_submitted_by: customerId
   rating_submitted_at: serverTimestamp()
   ```
6. Rating tampil di profile barber & barbershop (aggregate ratings nanti di dashboard admin)

---

## 📡 DATA MODEL (Firestore Collection: `queues`)

### Struktur Document Queue

```javascript
{
  // Basic Info
  "id": "queue_doc_id",
  "barbershop_id": "shop_123",
  "customer_id": "user_456",
  "barberman_id": "barber_789",
  "service_ids": ["svc_1", "svc_2"],
  
  // Pricing & Duration
  "total_price": 150000,
  "estimated_duration": 60,  // minutes
  "actual_duration": 58,     // filled saat finish service
  
  // Time
  "booking_time": Timestamp,
  "payment_due_at": Timestamp,      // for 10-min payment window
  "payment_submitted_at": Timestamp,
  "start_time": Timestamp,           // saat mulai service
  "finish_time": Timestamp,          // saat selesai service
  
  // Payment
  "payment_proof_base64": "base64_image_data",
  "payment_method": "bank_transfer",
  "payment_amount": 150000,
  "admin_payment_notes": "...",
  "payment_confirmed_at": Timestamp,
  "payment_confirmed_by": "admin_uid",
  
  // Cancellation (jika applicable)
  "cancellation_reason": "...",
  "cancellation_requested_by": "customer_uid",
  "cancellation_requested_at": Timestamp,
  "cancellation_approved_by": "admin_uid",
  "cancellation_approved_at": Timestamp,
  "cancellation_rejected_by": "admin_uid",
  "cancellation_rejected_at": Timestamp,
  "cancellation_rejection_reason": "...",
  "cancelled_by_uid": "admin/system",
  "cancelled_at": Timestamp,
  
  // Refund
  "refund_amount": 135000,      // 90% of total
  "original_price": 150000,
  "refund_deduction": 15000,    // 10%
  "refund_proof_base64": "base64_data",
  "refund_approved_at": Timestamp,
  
  // Rating
  "rating": 4.5,
  "rating_comment": "...",
  "rating_submitted_by": "customer_uid",
  "rating_submitted_at": Timestamp,
  
  // Status & Audit
  "status": "booked|waiting|ongoing|served|cancelled|refund_pending",
  "order_id": "ORD_1234567890",
  "created_at": Timestamp,
  "updated_at": Timestamp,
  "booked_at": Timestamp,
  "booked_by": "admin_uid",
}
```

---

## 🔒 SECURITY & VALIDASI

### Client-Side Validasi (UI)
- ✅ Service minimal 1
- ✅ Barberman harus dipilih
- ✅ Tanggal tidak mundur
- ✅ Waktu dalam jam operasional
- ✅ Waktu tidak mundur (jika hari ini)
- ✅ Slot check sebelum submit

### Server-Side (Firestore Transaction)
- ✅ Transactional createQueue: re-check slot availability saat write
- ✅ Prevent double-booking via concurrent slot check
- ✅ Status validation: admin hanya bisa confirm/reject dari status tertentu

### Payment Security
- ✅ Payment proof harus upload (bukti transfer wajib)
- ✅ payment_due_at 10 menit: auto-cancel jika timeout
- ✅ Admin manual verification (tanpa Cloud Functions, sesuai request)

### Cancellation Security
- ✅ Customer hanya bisa batalkan dari status `booked`
- ✅ Auto 10% refund deduction
- ✅ Admin harus approve refund
- ✅ Refund proof dapat di-audit

---

## 📋 API METHODS (QueueService)

### Booking Creation
```dart
Future<DocumentReference> createQueue(Map<String, dynamic> queueData)
// Auto-set payment_due_at jika status='waiting'
// Transactional: re-check slot availability saat write
```

### Payment
```dart
Future<void> adminConfirmPayment(String queueId, {String? adminUid, String? adminNotes})
// waiting → booked

Future<void> adminRejectPayment(String queueId, {String? reason, String? adminUid})
// waiting → cancelled
```

### Service Management
```dart
Future<void> startService(String queueId)
// booked → ongoing

Future<void> finishService(String queueId, Timestamp startTime)
// ongoing → served
```

### Cancellation
```dart
Future<void> customerRequestCancellation(String queueId, {required String reason})
// booked → cancellation_requested
// Auto-calc refund (90%)

Future<void> adminApproveCancellation(String queueId, {String? refundProofBase64})
// cancellation_requested → refund_pending

Future<void> adminRejectCancellation(String queueId, {String? reason})
// cancellation_requested → booked
```

### Rating
```dart
Future<void> submitRating(String queueId, {required double rating, String? comment})
// served + rating
```

### Queries
```dart
Future<int> cancelExpiredWaitingQueuesForCustomer(String customerId)
// Cancel waiting queues jika payment_due_at lewat

Future<Queue?> getQueueById(String queueId)
Future<List<Queue>> getBarbershopBookingHistory(String barbershopId, {int limit=50})
Stream<List<Queue>> getActiveQueueStream(String barbershopId)
Stream<List<Queue>> streamQueuesForBarbershop(...)
```

---

## 🧪 MANUAL TEST CASES

### Test 1: Happy Path Booking → Payment → Confirm → Serve → Rate
1. Login sebagai customer
2. Buka barbershop, tap "Book Now"
3. Pilih 2 service, 1 barberman, hari besok jam 10:00
4. Tap "Book Now" → Payment Screen
5. Upload bukti transfer → Submit
6. (Switch ke admin) Confirm pembayaran
7. (Switch ke customer) My Bookings → status "Booked"
8. (Switch ke admin) Tap "Mulai Potong" → status "Ongoing"
9. (Switch ke admin) Tap "Selesai" → status "Served"
10. (Switch ke customer) My Bookings → Kasih rating 5 bintang
11. ✅ Verify: rating tersimpan di Firestore

### Test 2: Payment Timeout
1. Create booking, go to Payment Screen
2. Wait 10+ minutes tanpa submit
3. Close app & reopen
4. (System internally) Call `cancelExpiredWaitingQueuesForCustomer`
5. ✅ Verify: Queue status changed to `cancelled` dengan reason "Payment timeout"

### Test 3: Cancellation Flow
1. Booking status = "Booked"
2. Tap "Batalkan Pesanan" → Input reason
3. Dialog konfirmasi 10% deduction → Lanjut
4. ✅ Verify: status = "cancellation_requested", refund_amount visible
5. (Switch ke admin) Approve cancellation + upload refund proof
6. ✅ Verify: status = "refund_pending", refund_proof_base64 saved
7. (Switch ke customer) Status = "Refund Pending", bukti terlihat

### Test 4: Slot Conflict (Double-Booking Prevention)
1. Customer A: Book barberman X, jam 10:00-11:00
2. Submit booking → Payment Screen
3. (Parallel) Customer B: Buka app, book barberman X, jam 10:30
4. Slot check → overlap detected
5. ✅ Verify: Customer B dapat pesan "Slot bentrok dengan booking lain"

### Test 5: Admin Reject Payment
1. Create booking, upload bukti
2. (Admin) Tap "Tolak Pembayaran" → Input reason "Bukti tidak jelas"
3. ✅ Verify: status = "cancelled", customer dapat lihat reason di My Bookings

---

## 📝 CATATAN & FUTURE ENHANCEMENTS

### Saat Ini (Implemented)
- ✅ Appointment form dengan multi-validasi
- ✅ Payment upload & 10-minute deadline
- ✅ Admin confirm/reject payment
- ✅ Service start/finish + status tracking
- ✅ Cancellation request → admin approve/reject + refund
- ✅ Rating submission

### TODO (Next Phase)
- 📲 Push notifications (payment confirm, service started, refund processed, etc.)
- 📊 Admin dashboard: analytics (ratings per barber, revenue, occupancy, etc.)
- 💬 Messaging: customer ↔ admin (complaint/support channel)
- 🔔 Email notifications (optional, untuk backup notification system)
- 📅 Calendar view untuk booking history
- 🎟️ Promo/discount codes (integration ke payment)
- 🏆 Loyalty points / rewards system

---

## 🛠️ TROUBLESHOOTING

### Booking tidak terlihat di My Bookings
- Verify: queue document ada di Firestore dengan `customer_id` yang benar
- Verify: `streamQueuesForCustomer` query sedang active di UI

### Payment timeout tidak cancel booking
- Call manual: `await queueService.cancelExpiredWaitingQueuesForCustomer(userId)`
- Ini client-side, bisa dipanggil saat app startup atau user buka My Bookings

### Admin payment confirm gagal
- Check: queue status masih "waiting"
- Check: admin punya akses ke barbershop_id tsb (firebase rules nanti)

### Rating tidak terlihat setelah submit
- Verify: status = "served" sebelum rating
- Verify: `rating` field ada di Firestore document

---

**Last Updated:** Nov 27, 2025  
**Author:** Development Team  
**Status:** Complete (Phase 1)
