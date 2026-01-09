## Booking & Payment Fixes — Implementation Index

Ringkasan komprehensif perbaikan yang sudah diterapkan terkait bug status booking, flow pembayaran, dan implementasi lengkap pembatalan/refund.

### 1. Status Parsing & Mapping
- **File**: `lib/models/queue.dart`
- **Perubahan**: Perbarui `QueueStatusExtension.fromString()` mapping sehingga string Firestore seperti `awaiting_payment`, `paid_verified`, `payment_pending`, dan `confirmed` dipetakan ke bucket enum yang tepat (mis. `booked`/`waiting`). Ini menghindari inkonsistensi UI dimana status tidak berubah di tab customer.

### 2. UI Customer — My Bookings & Payment
- **Files**: 
  - `lib/screens/customer/tabs/my_bookings_screen.dart`
  - `lib/screens/customer/booking_detail_screen.dart`
  
- **Perubahan**:
  - Tab "Menunggu Pembayaran" menampilkan booking yang benar-benar menunggu bukti pembayaran (status `awaiting_payment`/`booked` dengan `requestStatus.approved` dan `paymentDeadline != null`).
  - Countdown timer real-time untuk window pembayaran dengan warna indikator (hijau/orange/merah).
  - Tombol "Bayar Sekarang" navigasi ke PaymentScreen.
  - Tombol "Minta Pembatalan / Refund" muncul setelah bukti pembayaran diupload atau status `booked`.
  - Dialog input alasan pembatalan yang wajib diisi sebelum submit request.

### 3. UI Admin — Cancellation Management
- **File**: `lib/screens/admin/cancellation_requests_screen.dart`
  
- **Fitur**:
  - Screen untuk menampilkan semua request pembatalan (status `cancellation_requested`).
  - Detail modal menunjukkan refund calculation: Original Price → Deduction 10% → Final Refund Amount.
  - Tombol "Reject": Mengembalikan booking ke status `booked`.
  - Tombol "Approve": Memungkinkan admin memilih upload bukti refund (kamera/galeri).
  
- **Validasi Upload Bukti Refund**:
  - Max file size: 5 MB dengan pesan error yang menampilkan ukuran file aktual.
  - Format yang diizinkan: JPG/JPEG/PNG saja.
  - Preview gambar dengan display ukuran file dalam KB.
  - Error message container untuk feedback validasi.
  - Progress dialog saat encoding image ke base64 ("Processing proof...").
  - Progress dialog kedua saat approval backend ("Approving...").

- **User Experience**:
  - Loading indicators untuk setiap aksi admin.
  - SnackBar feedback untuk setiap operasi (berhasil/gagal).
  - Modal sheet untuk approve-with-proof flow.

### 4. Service / Backend Logic
- **File**: `lib/services/queue_service.dart`
  
- **Implemented Methods**:
  - `adminConfirmRequest()`: Admin approve request booking → `awaiting_payment` (10-min deadline)
  - `adminConfirmPayment()`: Admin verify payment proof → `booked`
  - `customerRequestCancellation()`: Customer request refund → `cancellation_requested` (calc 90% refund)
  - `adminApproveCancellation()`: Admin approve refund → `refund_pending` (upload proof optional)
  - `adminRejectCancellation()`: Admin reject refund → `booked` (booking tetap valid)
  - `adminRefundBooking()`: Manual refund processing
  - `cancelExpiredWaitingQueuesForCustomer()`: Auto-cancel expired requests
  - `cancelExpiredAwaitingPaymentQueuesForCustomer()`: Auto-cancel expired payment windows

### 5. Status Flow Diagram
```
CUSTOMER REQUEST
    ↓
[status: waiting, requestStatus: pending]
    ↓
ADMIN APPROVE
    ↓
[status: awaiting_payment, requestStatus: approved, paymentDeadline: now+10m]
    ↓
CUSTOMER UPLOAD PROOF
    ↓
[status: awaiting_payment, paymentProofBase64: set, verifiedBy: null]
    ↓
ADMIN VERIFY PAYMENT
    ↓
[status: booked, verifiedBy: admin_uid]
    ↓
CUSTOMER REQUEST CANCELLATION (optional)
    ↓
[status: cancellation_requested, refundAmount: totalPrice*0.9]
    ↓
ADMIN APPROVE REFUND
    ↓
[status: refund_pending, refundProofBase64: optional]
    ↓
CUSTOMER VIEWS REFUND STATUS
```

### 6. Testing Checklist
- [ ] Tab "Menunggu Pembayaran" menampilkan booking dengan status `awaiting_payment` setelah admin confirm request
- [ ] Countdown timer countdown dan berhenti di 00:00:00
- [ ] Tombol "Bayar Sekarang" navigasi ke payment screen
- [ ] Upload bukti pembayaran mengubah status menjadi "Pembayaran Dikirim"
- [ ] Admin dapat melihat request pembatalan dengan refund calculation yang benar (90% dari total)
- [ ] Validasi file size (> 5MB ditolak)
- [ ] Validasi format file (hanya JPG/PNG)
- [ ] Progress indicator muncul saat encode image
- [ ] Approve/Reject loading indicators berfungsi
- [ ] Refund approved → status `refund_pending`
- [ ] Customer dapat melihat refund details di booking detail

### 7. Known Limitations & Future Enhancements
1. **Auto Refund Transfer**: Saat ini `refund_pending` status hanya sebagai marker. Implementasi actual transfer ke payment gateway diperlukan di fase berikutnya.
2. **Refund Proof Storage**: Bukti refund (base64) disimpan di Firestore. Untuk production, pertimbangkan storage ke Firebase Storage.
3. **Batch Refund Processing**: Admin saat ini memproses refund per-request. Batch processing UI bisa ditambahkan.
4. **Email Notifications**: Notification via email untuk refund approval/rejection belum diimplementasikan.

### 8. Files Modified
- `lib/models/queue.dart` — Status enum mapping
- `lib/screens/customer/tabs/my_bookings_screen.dart` — Status label logic
- `lib/screens/customer/booking_detail_screen.dart` — Payment UI + cancellation button
- `lib/screens/admin/cancellation_requests_screen.dart` — Admin cancellation management with proof upload & validation
- `lib/services/queue_service.dart` — Business logic (pre-existing)

---

**Status**: ✅ COMPLETED (Phase 1 — Core Booking/Payment/Cancellation Flow)

**Next Phase Recommendations**:
1. Implement Firestore transaction tests with emulator
2. Add batch refund processing UI
3. Integrate email notifications for status changes
4. Implement actual refund transfer to payment gateway