# Dokumentasi: Booking Flow & Database Fields

Dokumentasi singkat untuk alur booking, status, dan perubahan database yang telah diterapkan.

## Ringkasan Alur (singkat)
1. Customer membuat *booking request* via `AppointmentScreen` → dokumen `queues` dibuat dengan `status: 'waiting'`.
2. Admin melihat request pada `BookingConfirmationScreen` (menampilkan `waiting` dan `payment_pending`).
3. Admin `Approve` request → `manualConfirmBooking` men-set:
   - `status: 'booked'`
   - `request_status: 'approved'`
   - `payment_deadline`: 10 menit dari waktu approve
4. Customer melihat status `booked` di `My Bookings` dan diarahkan ke `PaymentScreen` untuk upload bukti.
5. Setelah upload, booking di-update menjadi `status: 'payment_pending'` (menunggu verifikasi admin).
6. Admin verifikasi bukti di `BookingConfirmationScreen` → jika valid: set `status: 'booked'` (atau `ongoing` jika langsung ingin mulai), `payment_confirmed_at`, dst. Jika tidak valid: `status: 'cancelled'` dengan `cancellation_reason`.
7. Proses lanjutan: `startService` → `ongoing`, `finishService` → `served`.

## Status yang digunakan (enriched)
- `waiting` : request customer dibuat, menunggu konfirmasi admin.
- `booked` : admin sudah approve, customer harus bayar dalam window (lihat `payment_deadline`).
- `payment_pending` : customer sudah upload bukti, menunggu admin verifikasi.
- `ongoing` : layanan sedang berlangsung.
- `served` : layanan selesai.
- `cancelled` : dibatalkan (oleh admin atau timeout atau user).

## Field baru / penting di dokumen `queues`
- `request_status` : 'pending' | 'approved' | 'rejected' — tracking approval admin.
- `payment_deadline` (Timestamp) : batas waktu upload bukti pembayaran setelah approve.
- `payment_proof_base64` : string base64 dari bukti (opsional jika menggunakan url/file storage).
- `payment_method`, `payment_amount` : informasi pembayaran.
- `payment_confirmed_at`, `payment_confirmed_by` : metadata verifikasi admin.
- `cancellation_reason`, `cancelled_by_uid`, `cancelled_at` : metadata pembatalan.
- `booked_at`, `booked_by` : metadata saat admin meng-approve.

## Perubahan kode penting
- `lib/models/queue.dart` : enum `QueueStatus` ditambahkan `payment_pending` dan mapping string.
- `lib/services/queue_service.dart` :
  - `manualConfirmBooking` men-set `payment_deadline` 10 menit.
  - Slot availability mem-block status `payment_pending` juga.
- `lib/screens/customer/appointment_screen.dart` : setelah membuat request, user mendapatkan notifikasi dan tidak langsung diarahkan ke payment.
- `lib/screens/customer/payment_screen.dart` : membaca dokumen berdasarkan `orderId`, hanya mengizinkan upload bila `request_status == 'approved'` dan `status == 'booked'` (payment window aktif). Upload mengubah `status` menjadi `payment_pending`.
- `lib/screens/admin/booking_confirmation_screen.dart` : sekarang menampilkan `waiting` & `payment_pending`. Admin bisa approve request, confirm payment (set `booked` + payment metadata) atau reject (cancel).
- `lib/screens/customer/tabs/my_bookings_screen.dart` : navigasi ke `PaymentScreen` untuk status `booked` diperbarui.

## Contoh Cloud Function (Node.js) — Auto-cancel payment timeouts
Gunakan Cloud Scheduler + Cloud Functions (atau Cloud Tasks) untuk menjalankan secara berkala. Contoh ringkas:

```js
// index.js (Cloud Function)
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.cancelExpiredPayments = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const q = db.collection('queues')
      .where('status', '==', 'booked')
      .where('payment_deadline', '<=', now)
      .limit(200);

    const snap = await q.get();
    const batch = db.batch();
    snap.forEach(doc => {
      const data = doc.data();
      // If no payment proof uploaded, cancel
      if (!data.payment_proof_base64 && !data.payment_proof_url) {
        batch.update(doc.ref, {
          status: 'cancelled',
          cancellation_reason: 'Payment timeout (no proof uploaded)',
          cancelled_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
          request_status: 'rejected'
        });
      }
    });

    if (!snap.empty) await batch.commit();
    return null;
  });
```

Catatan: perlu penyesuaian (pagination, retries, monitoring) pada produksi.

## Saran lanjutan
- Implementasikan verifikasi bukti yang lebih kuat: unggah ke Firebase Storage (bukan base64), gunakan virus scan jika diperlukan.
- Tambahkan notifikasi push (FCM) untuk memberitahu customer tentang status berubah (approved, payment_pending, confirmed, cancelled).
- Tambahkan endpoint Cloud Function untuk refund otomatis (dengan bukti) jika admin setujui refund.

---
Dokumentasi ini ditambahkan otomatis oleh Copilot helper. Kalau mau, saya bisa lanjut:
- Implementasi UI admin khusus untuk `payment_pending` (dengan tombol "Confirm Payment" dan "Reject Payment with reason" yang sudah ditambahkan di `BookingConfirmationScreen`).
- Menambahkan Cloud Function deploy script dan file contoh `package.json`.

Mau saya lanjut ke implementasi refund + notifikasi sekarang? (saya lanjutkan coding setelah konfirmasi)