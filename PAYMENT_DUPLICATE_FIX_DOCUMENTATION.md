# Perbaikan Duplikasi Booking & State Inconsistency - Dokumentasi Lengkap

**Tanggal**: 28 November 2025  
**Versi**: 1.0  
**Status**: Ready for Implementation

---

## 1. Ringkasan Perbaikan

### Masalah Utama
- ❌ Duplikasi booking saat customer upload bukti pembayaran
- ❌ Inkonsistensi status di My Bookings dan Admin panels
- ❌ Customer bisa upload bukti berkali-kali (double-payment risk)
- ❌ Booking muncul di multiple tabs secara bersamaan

### Solusi Implementasi
- ✅ Firestore transaction untuk atomic write
- ✅ Field lock mechanism (`proofLocked = true`) untuk disable upload
- ✅ Query eksklusif per tab (tidak ada overlap)
- ✅ Deduplication di service layer
- ✅ Real-time snapshot listener untuk UI consistency

---

## 2. Data Model - Firestore Schema

### Perubahan bookings Collection

**Sebelum:**
```json
{
  "bookingId": "...",
  "userId": "...",
  "status": "confirmed",
  "payment": {
    "amount": 20000,
    "proofUrl": null
  }
}
```

**Sesudah (struktur lengkap):**
```json
{
  "bookingId": "...",
  "userId": "...",
  "status": "confirmed",
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
  "scheduledAt": Timestamp,
  "serviceId": "...",
  
  "payment": {
    "amount": 20000,
    "currency": "IDR",
    "deadlineAt": Timestamp,
    "proofUrl": null,
    "proofUploadedAt": null,
    "proofUploadedBy": null,
    "proofUploadAttemptCount": 0,
    "proofLocked": false,
    "verificationStatus": null,
    "verificationAcceptedAt": null,
    "verificationAcceptedBy": null,
    "verificationRejectedAt": null,
    "verificationRejectedBy": null,
    "rejectionReason": null,
    "verificationNotes": null
  },
  
  "cancellation": {
    "cancelledAt": null,
    "cancelledBy": null,
    "cancelledReason": null
  }
}
```

**Penjelasan Field Baru:**

| Field | Type | Purpose |
|-------|------|---------|
| `proofUrl` | String | URL bukti pembayaran (diset sekali) |
| `proofUploadedAt` | Timestamp | Server timestamp upload |
| `proofUploadedBy` | String | UID customer yang upload |
| `proofUploadAttemptCount` | Int | Increment setiap percobaan (diagnosa) |
| `proofLocked` | Boolean | Jika true, UI disable upload |
| `verificationStatus` | String | 'pending' \| 'accepted' \| 'rejected' \| null |
| `verificationAcceptedAt` | Timestamp | Kapan admin terima |
| `verificationAcceptedBy` | String | UID admin yang terima |
| `verificationRejectedAt` | Timestamp | Kapan admin tolak |
| `verificationRejectedBy` | String | UID admin yang tolak |
| `rejectionReason` | String | Alasan penolakan |
| `verificationNotes` | String | Catatan admin |

---

## 3. State Transition Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    BOOKING STATUS TRANSITIONS                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  STEP 1: Customer membuat booking                                   │
│  ────────────────────────────────────────────                       │
│  Status: created                                                     │
│  verificationStatus: null                                            │
│  proofLocked: false                                                  │
│  ↓                                                                   │
│                                                                      │
│  STEP 2: Admin confirm (set payment deadline)                       │
│  ──────────────────────────────────                                 │
│  Status: confirmed                                                   │
│  payment.deadlineAt: now + 10 minutes                               │
│  ↓                                                                   │
│                                                                      │
│  STEP 3: Customer upload bukti pembayaran                           │
│  ──────────────────────────────────────                             │
│  [TRANSACTION - ATOMIC]                                              │
│  - Validasi: status=='confirmed', proofUrl==null, proofLocked==false│
│  - Set: proofUrl, proofUploadedAt, proofUploadedBy                  │
│  - Increment: proofUploadAttemptCount                               │
│  - Lock: proofLocked=true (prevent re-upload UI)                    │
│  - Set: verificationStatus='pending'                                │
│  ↓                                                                   │
│                                                                      │
│  STEP 4: Admin verifikasi pembayaran                                │
│  ──────────────────────────────                                     │
│                                                                      │
│  Option A: ACCEPT                                                    │
│  ─────────────────                                                  │
│  - verificationStatus: 'pending' → 'accepted'                       │
│  - status: 'confirmed' → 'paid_verified'                            │
│  - Set: verificationAcceptedAt, verificationAcceptedBy              │
│  - Booking siap untuk service                                       │
│                                                                      │
│  Option B: REJECT (allow re-upload)                                 │
│  ────────────────────────────────────                               │
│  - verificationStatus: 'pending' → 'rejected'                       │
│  - status: 'confirmed' (tidak berubah)                              │
│  - proofLocked: false (allow re-upload)                             │
│  - proofUrl: DELETE (clear untuk re-upload)                         │
│  - Set: verificationRejectedAt, rejectionReason                     │
│  - Customer bisa upload ulang                                       │
│                                                                      │
│  Option C: REJECT (cancel booking)                                  │
│  ─────────────────────────────────────                              │
│  - verificationStatus: 'pending' → 'rejected'                       │
│  - status: 'confirmed' → 'cancelled'                                │
│  - proofLocked: true (tidak bisa upload lagi)                       │
│  - Booking dibatalkan                                               │
│  ↓                                                                   │
│                                                                      │
│  FINAL: Service dapat dimulai (status==paid_verified)               │
│  ──────────────────────────────────────────────────────             │
│  Ongoing → Completed → History                                       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Query per Tab (Customer My Bookings)

### Tab 1: Menunggu Konfirmasi
```dart
where('userId', isEqualTo: userId)
  .where('status', isEqualTo: 'created')
```

### Tab 2: Menunggu Pembayaran
```dart
where('userId', isEqualTo: userId)
  .where('status', isEqualTo: 'confirmed')
  .where('payment.verificationStatus', isNull: true)
  // Atau: isNotEqualTo: 'pending' jika nullable handling rumit
```

### Tab 3: Pembayaran Dikirim (Menunggu Verifikasi)
```dart
where('userId', isEqualTo: userId)
  .where('payment.verificationStatus', isEqualTo: 'pending')
```

### Tab 4: Terbayar
```dart
where('userId', isEqualTo: userId)
  .where('status', isEqualTo: 'paid_verified')
```

### Tab 5: Dibatalkan
```dart
where('userId', isEqualTo: userId)
  .where('status', isEqualTo: 'cancelled')
```

**Penting: Setiap query EKSKLUSIF** → booking tidak muncul di dua tab sekaligus

---

## 5. Admin Payment Verification Query

```dart
FirebaseFirestore.instance
  .collection('bookings')
  .where('payment.verificationStatus', isEqualTo: 'pending')
  .orderBy('payment.proofUploadedAt', descending: false)
  .snapshots()
  .map((snapshot) {
    // Deduplicate by bookingId (safety net)
    final Map<String, DocumentSnapshot> unique = {};
    for (var doc in snapshot.docs) {
      unique[doc.id] = doc;
    }
    return unique.values.toList();
  })
```

---

## 6. Implementation Checklist

### File-file yang harus dibuat/dimodifikasi:

- [ ] **`lib/services/booking_anti_duplicate_service.dart`** (BARU)
  - Implementasi transaction logic
  - Submit payment proof
  - Accept/reject verification
  - Stream queries
  - Duplicate identification

- [ ] **`lib/screens/customer/payment_screen_improved.dart`** (BARU)
  - Disable button setelah upload
  - Snapshot listener real-time
  - Countdown timer
  - Error handling
  - Lock mechanism UI

- [ ] **`lib/screens/customer/my_bookings_screen_improved.dart`** (BARU)
  - 5 tabs dengan eksklusif queries
  - Deduplicate by bookingId
  - Status label dan UI updates

- [ ] **`lib/screens/admin/payment_verification_screen_improved.dart`** (BARU)
  - Query only pending
  - Accept/reject buttons
  - Proof preview
  - Dialog rejection dengan reason

- [ ] **`pubspec.yaml`** (CHECK)
  - Pastikan dependencies: `cloud_firestore`, `firebase_auth`, `intl`

### Migrasi Existing Bookings:

- [ ] Jika ada booking lama tanpa field baru, tambahkan values default:
  ```dart
  payment.proofLocked: false
  payment.verificationStatus: null
  payment.proofUploadAttemptCount: 0
  ```

- [ ] Jika ada duplicate, identifikasi & cleanup (lihat bagian "Cleanup")

---

## 7. Mekanisme Prevent Double-Upload (Code Snippet)

**Untuk diintegrasikan ke payment flow:**

```dart
// lib/services/booking_anti_duplicate_service.dart → submitPaymentProof()

Future<void> submitPaymentProof({
  required String bookingId,
  required String proofUrl,
  required String userId,
}) async {
  final bookingRef = FirebaseFirestore.instance
      .collection('bookings')
      .doc(bookingId);

  await FirebaseFirestore.instance.runTransaction((tx) async {
    // 1. READ
    final snapshot = await tx.get(bookingRef);
    if (!snapshot.exists) {
      throw Exception('Booking tidak ditemukan');
    }

    final data = snapshot.data() ?? {};
    final status = data['status'] as String?;
    final payment = Map<String, dynamic>.from(data['payment'] ?? {});
    
    final currentProofUrl = payment['proofUrl'] as String?;
    final proofLocked = payment['proofLocked'] as bool? ?? false;

    // 2. VALIDATE
    if (status != 'confirmed') {
      throw Exception('Booking harus dalam status confirmed');
    }
    if (currentProofUrl != null && currentProofUrl.isNotEmpty) {
      throw Exception('Bukti pembayaran sudah dikirim');
    }
    if (proofLocked) {
      throw Exception('Upload sudah terkunci');
    }

    // 3. UPDATE (atomically)
    tx.update(bookingRef, {
      'payment.proofUrl': proofUrl,
      'payment.proofUploadedAt': FieldValue.serverTimestamp(),
      'payment.proofUploadedBy': userId,
      'payment.proofUploadAttemptCount': FieldValue.increment(1),
      'payment.proofLocked': true,
      'payment.verificationStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}
```

**Key Points:**
- ✅ Transaction membuat read-modify-write atomik
- ✅ Cek status sebelum update
- ✅ Set proofLocked=true untuk lock UI
- ✅ Increment attempt count untuk diagnosa
- ✅ Jika 2 client race → hanya 1 yang berhasil

---

## 8. UI Flow (Payment Screen)

```
┌──────────────────────────────────────────┐
│  PAYMENT SCREEN (Customer)               │
├──────────────────────────────────────────┤
│                                           │
│  [Snapshot listener mendengarkan changes]│
│                                           │
│  1. Tampilkan countdown timer             │
│  2. Tampilkan bank details                │
│  3. Button "Kirim Bukti Pembayaran"       │
│     (enabled jika: belum upload & timing) │
│                                           │
│  ↓ User tap button                        │
│                                           │
│  4. setState → _isSubmitting=true         │
│  5. Tampilkan spinner loading             │
│  6. Call submitPaymentProof(transaction)  │
│                                           │
│  ↓ Transaction sukses                     │
│                                           │
│  7. setState → _proofLocked=true          │
│  8. Button disable & "Bukti Sudah Dikirim"│
│  9. Tampilkan badge orange: "Menunggu    │
│     Verifikasi Admin"                     │
│  10. Snapshot update → UI real-time       │
│                                           │
│  ↓ Admin verifikasi                       │
│                                           │
│  11. verificationStatus='accepted'        │
│  12. Snapshot trigger → badge hijau       │
│  13. "Pembayaran Diverifikasi"            │
│                                           │
│  [END]                                    │
│                                           │
└──────────────────────────────────────────┘
```

---

## 9. Migrasi & Cleanup (Jika ada duplikasi existing)

### Script Identify Duplicates

```dart
// Panggil dari admin panel atau Firebase console

Future<void> findAndCleanupDuplicates() async {
  final antiDupService = BookingAntiDuplicateService();
  
  // 1. Identify duplicates
  final duplicates = await antiDupService.identifyDuplicateBookings();
  
  debugPrint('Found ${duplicates.length} duplicate groups');
  
  // 2. Untuk setiap group
  for (final group in duplicates) {
    // group = ['bookingId1', 'bookingId2', 'bookingId3']
    
    // Pick authoritative: latest dengan proofUploadedAt
    // atau newest createdAt jika belum upload
    
    final firestore = FirebaseFirestore.instance;
    final docs = await Future.wait(
      group.map((id) => firestore.collection('bookings').doc(id).get())
    );
    
    DocumentSnapshot? authoritative;
    for (var doc in docs) {
      if (authoritative == null) {
        authoritative = doc;
      } else {
        final authData = authoritative.data() as Map? ?? {};
        final currData = doc.data() as Map? ?? {};
        
        // Compare: prefer with proof
        final authProofTime = authData['payment']?['proofUploadedAt'] as Timestamp?;
        final currProofTime = currData['payment']?['proofUploadedAt'] as Timestamp?;
        
        if (currProofTime != null && 
            (authProofTime == null || currProofTime.compareTo(authProofTime) > 0)) {
          authoritative = doc;
        } else if (authProofTime == null && currProofTime == null) {
          // Keduanya belum upload, compare createdAt
          final authCreated = authData['createdAt'] as Timestamp?;
          final currCreated = currData['createdAt'] as Timestamp?;
          if (currCreated != null && (authCreated == null || currCreated.compareTo(authCreated) > 0)) {
            authoritative = doc;
          }
        }
      }
    }
    
    // Mark non-authoritative as duplicate_removed
    for (var doc in docs) {
      if (doc.id != authoritative!.id) {
        await antiDupService.markAsDuplicateRemoved(
          bookingId: doc.id,
          reason: 'Duplicate of ${authoritative.id}',
        );
        debugPrint('Marked ${doc.id} as duplicate');
      }
    }
  }
  
  debugPrint('Cleanup completed');
}
```

### Manual Fix (Admin UI)

Tambahkan di admin panel:
```dart
// Button "Cleanup Duplicates"
ElevatedButton(
  onPressed: () async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cleanup Duplicates?'),
        content: const Text('Proses ini akan mengidentifikasi dan menandai booking duplikat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await findAndCleanupDuplicates();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cleanup selesai')),
              );
            },
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
  },
  label: const Text('Cleanup Duplicates'),
)
```

---

## 10. QA Test Cases (Mandatory)

### Test 1: Single Upload Success
**Steps:**
1. Customer buka payment screen
2. Upload bukti pembayaran
3. Tap "Kirim Bukti Pembayaran"

**Expected:**
- ✅ Transaction sukses
- ✅ payment.proofUrl terisi
- ✅ payment.proofLocked = true
- ✅ payment.verificationStatus = 'pending'
- ✅ UI button disabled → "Bukti Sudah Dikirim"
- ✅ Badge orange tampil: "Menunggu Verifikasi"
- ✅ Booking muncul di tab "Pembayaran Dikirim" (hanya 1x)

**Firestore Check:**
```javascript
db.collection('bookings').doc(bookingId).get()
// payment.proofUrl: "https://..."
// payment.proofLocked: true
// payment.verificationStatus: "pending"
// payment.proofUploadAttemptCount: 1
```

---

### Test 2: Block Double Upload (Simultaneous)
**Steps:**
1. Simulasi 2 tab/device submit ke booking ID sama
2. Keduanya submit hampir bersamaan

**Expected:**
- ✅ Hanya 1 transaction berhasil
- ✅ Yang gagal: error "Bukti pembayaran sudah dikirim"
- ✅ proofUploadAttemptCount = 2 (increment kedua percobaan)
- ✅ Firestore: hanya 1 dokumen

**Test Manual:**
```javascript
// Open 2 browser tabs, same payment screen
// Tab 1: tap "Kirim" → loading
// Tab 2: tap "Kirim" → loading (race condition)
// Expected: 1 success, 1 error message
```

---

### Test 3: No Duplicate Doc Creation
**Steps:**
1. Buat booking, confirm, upload bukti

**Expected:**
- ✅ bookings collection → hanya 1 dokumen dengan bookingId
- ✅ Tidak ada dokumen dengan ID berbeda tapi data mirip

**Firestore Check:**
```javascript
db.collection('bookings')
  .where('userId', '==', 'test@user.com')
  .where('scheduledAt', '==', /* same time */)
  .get()
// Result: 1 document (not multiple)
```

---

### Test 4: Admin Filter Only Pending
**Steps:**
1. Create 3 bookings: 1 uploaded, 1 rejected, 1 paid_verified
2. Open "Verifikasi Pembayaran" screen

**Expected:**
- ✅ Admin screen hanya tampil booking dengan verificationStatus='pending'
- ✅ Booking yang rejected/paid tidak tampil
- ✅ Jumlah item = 1

**Query Check:**
```javascript
db.collection('bookings')
  .where('payment.verificationStatus', '==', 'pending')
  .get()
// Result: 1 document
```

---

### Test 5: Customer Cannot Re-Pay
**Steps:**
1. Upload bukti sukses → proofLocked=true
2. Try tap button lagi

**Expected:**
- ✅ Button disabled (greyed out)
- ✅ Snapshot listener update → tetap locked
- ✅ Tidak bisa upload ulang sampai admin reject

---

### Test 6: Rejected Path (Allow Re-upload)
**Steps:**
1. Customer upload bukti
2. Admin tolak dengan alasan, checkbox "Izinkan upload ulang" = checked
3. Screen kembali ke customer

**Expected:**
- ✅ verificationStatus = 'rejected'
- ✅ status = 'confirmed' (tidak berubah)
- ✅ proofLocked = false (UI button enabled lagi!)
- ✅ proofUrl = null (dihapus, boleh upload baru)
- ✅ Customer melihat: "Pembayaran ditolak — silakan upload ulang"
- ✅ Button "Kirim Bukti Pembayaran" enabled kembali

**Firestore Check:**
```javascript
db.collection('bookings').doc(bookingId).get()
// payment.verificationStatus: "rejected"
// payment.proofLocked: false
// payment.proofUrl: null
```

---

### Test 7: Query Exclusivity (No Overlap)
**Steps:**
1. Buat 5 booking dengan status berbeda:
   - A: status='created'
   - B: status='confirmed', verificationStatus=null
   - C: status='confirmed', verificationStatus='pending'
   - D: status='confirmed', verificationStatus='rejected'
   - E: status='paid_verified'

2. Buka My Bookings customer

**Expected:**
- ✅ Tab "Menunggu Konfirmasi" → A saja
- ✅ Tab "Menunggu Pembayaran" → B saja
- ✅ Tab "Pembayaran Dikirim" → C saja
- ✅ Tab "Terbayar" → E saja
- ✅ Tab "Dibatalkan" → (kosong)
- ✅ TIDAK ada booking muncul di 2 tab sekaligus

---

### Test 8: UI Snapshot Consistency
**Steps:**
1. Customer upload bukti
2. Buka My Bookings di 2 tab (atau app + admin change)
3. Admin verifikasi/terima pembayaran

**Expected:**
- ✅ Booking hilang dari tab "Pembayaran Dikirim"
- ✅ Booking muncul di tab "Terbayar" dalam <3 detik (snapshot update)
- ✅ Tidak ada lag/delay yang signifikan
- ✅ UI consistent antara customer & admin

---

## 11. Integration Testing Checklist

- [ ] Run `flutter analyze --no-pub` → No issues
- [ ] Compile release build → `flutter build apk --release`
- [ ] Test on real device (atau emulator)
- [ ] Test all 8 test cases di atas
- [ ] Verify Firestore data integrity
- [ ] Check no orphaned documents
- [ ] Verify notifications sent (optional)
- [ ] Load test: multiple concurrent uploads

---

## 12. Deployment Steps

1. **Code Review**
   - [ ] Review service layer (`booking_anti_duplicate_service.dart`)
   - [ ] Review UI components (payment screen, my bookings, admin verification)
   - [ ] Verify error handling & edge cases

2. **Database Preparation**
   - [ ] Backup bookings collection (atau Firestore export)
   - [ ] Run migration: add new fields to existing docs
   - [ ] Verify data consistency

3. **Staging Test**
   - [ ] Deploy to staging environment
   - [ ] Run full QA checklist
   - [ ] Get sign-off from QA

4. **Production Deployment**
   - [ ] Deploy new code (Flutter app release)
   - [ ] Monitor Firestore writes & errors
   - [ ] Check error logs & analytics
   - [ ] Be ready to rollback if issues

5. **Post-Deployment**
   - [ ] Run cleanup script untuk existing duplicates
   - [ ] Monitor for 24-48 hours
   - [ ] Collect metrics (transaction success rate, etc.)

---

## 13. Rollback Plan (jika diperlukan)

- Keep backup of bookings collection sebelum migration
- Jika critical bug ditemukan:
  1. Revert app code (push older APK)
  2. Mark affected bookings status (untuk manual review)
  3. Restore dari backup jika perlu

---

## 14. Files Summary

| File | Purpose | Status |
|------|---------|--------|
| `lib/services/booking_anti_duplicate_service.dart` | Service layer dengan transaction & queries | ✅ Ready |
| `lib/screens/customer/payment_screen_improved.dart` | UI payment dengan locking | ✅ Ready |
| `lib/screens/customer/my_bookings_screen_improved.dart` | My Bookings dengan 5 tab eksklusif | ✅ Ready |
| `lib/screens/admin/payment_verification_screen_improved.dart` | Admin verifikasi dengan accept/reject | ✅ Ready |
| Migration script (in documentation) | Cleanup duplicates | ✅ Ready |

---

**Next Step:** Integrate file-file di atas ke project utama, jalankan QA checklist, dan deploy ke production.

Pertanyaan atau issue? Check error logs di Firestore console.
