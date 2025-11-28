## Option C: QA Checklist - Duplikasi Fix Verification

### 🎯 Overview
8 comprehensive test cases untuk memverifikasi bahwa duplikasi booking fix berfungsi dengan benar.

Jalankan di **staging environment** setelah deploy appointment_screen + PaymentScreenImproved fix.

---

## ✅ Test Case 1: Create Booking & Check Single Document

**Objective**: Verifikasi bahwa ketika user membuat booking via appointment flow baru, hanya 1 dokumen dibuat di `bookings` collection.

**Setup**:
- Logged in as customer (test_customer@test.com)
- Navigate to barbershop detail → appointment screen

**Steps**:
1. Select service (cth: "Haircut Rp100,000")
2. Select barberman
3. Select date & time
4. Click "Konfirmasi Booking"
5. Should redirect to PaymentScreenImproved
6. Open Firestore console

**Verification**:
```
Expected:
- ✅ Exactly 1 new document in bookings collection
- ✅ Document has fields: userId, barbermanId, serviceIds, amount, scheduledAt, status
- ✅ payment nested object exists with: amount, currency, proofUrl (null), proofLocked (false)
- ❌ NO documents in 'queues' collection from this booking
- ❌ NO nested collection under barbermen/{id}/bookings

Query:
db.collection('bookings').where('userId', '==', auth.currentUser.uid)
  .where('createdAt', '>', timestamp_of_test_start)
```

**Pass Criteria**: Exactly 1 document, no duplicates in queues or nested collections

---

## ✅ Test Case 2: Admin Confirms Booking

**Objective**: Verifikasi bahwa ketika admin confirm booking, hanya update existing document (bukan create baru).

**Setup**:
- Same booking from Test Case 1 (status: 'pending_confirmation')
- Logged in as admin
- Navigate to admin dashboard → "Konfirmasi Booking"

**Steps**:
1. Find the booking in "Menunggu Konfirmasi" list
2. Click confirm button
3. Wait 2-3 seconds for real-time update
4. Check Firestore console

**Verification**:
```
Expected in Firestore:
- ✅ Document ID unchanged (same as Test Case 1)
- ✅ Field updated: status = 'confirmed'
- ✅ Field updated: payment.amount set correctly
- ✅ createdAt timestamp unchanged
- ✅ updatedAt = serverTimestamp() (new/updated)

Document count in bookings:
- Before: 1
- After: 1 (no new document!)
```

**Pass Criteria**: Same document ID, fields updated in-place, no duplicates

---

## ✅ Test Case 3: Customer Uploads Proof, No Duplicates Created

**Objective**: Verifikasi bahwa submit proof via PaymentScreenImproved tidak create dokumen baru.

**Setup**:
- Same booking from Test Case 2 (status: 'confirmed')
- Customer on PaymentScreenImproved
- Image file ready for upload (any image < 5MB)

**Steps**:
1. Open PaymentScreenImproved (should auto-redirect after confirm in Test Case 2)
2. Take photo / select image from gallery
3. Click "Upload Bukti Pembayaran"
4. Wait for "✅ Bukti dikirim" confirmation
5. Check Firestore console
6. Check payment field in document

**Verification**:
```
Expected in Firestore document:
- ✅ Document ID unchanged (same as Test Case 1)
- ✅ payment.proofUrl = {gs://... URL to image}
- ✅ payment.proofUploadedAt = serverTimestamp()
- ✅ payment.proofLocked = true (prevents re-upload)
- ✅ payment.verificationStatus = 'pending'
- ✅ status = 'waiting_payment' (or similar state)

Document count:
- Before: 1
- After: 1 (no new document!)

Button status:
- Before upload: "Upload Bukti Pembayaran" (enabled)
- After upload: "Upload Bukti Pembayaran" (disabled/loading state)
```

**Pass Criteria**: Proof URL set, proofLocked=true, button disabled, no new documents created

---

## ✅ Test Case 4: Concurrent Payment Uploads (Transaction Safety)

**Objective**: Verifikasi bahwa jika 2+ devices upload proof untuk booking yang sama, hanya 1 succeed.

**Setup**:
- Same booking from Test Case 3 (payment.proofLocked=false after admin rejects in later test)
- 2 devices: mobile_1, mobile_2 (both logged in as same customer)

**Steps**:
1. On mobile_1: Navigate to PaymentScreenImproved for this booking
2. On mobile_2: Navigate to PaymentScreenImproved for same booking
3. On mobile_1: Select image & click Upload
4. Immediately on mobile_2: Select different image & click Upload
5. Observe which completes first
6. Check Firestore console

**Verification**:
```
Expected:
- ✅ First upload succeeds (proofUrl set, proofLocked=true)
- ✅ Second upload fails (proofLocked=true prevents it, or transaction aborts)
- ✅ Document still has ONLY 1 proof URL (first one wins)
- ✅ Both devices receive clear feedback (success vs fail)

Document count:
- Unchanged = 1 (no duplicates)

payment field:
- proofUrl = first_image_url (NOT second_image_url)
- proofUploadAttemptCount = 2 (both attempts logged)
```

**Pass Criteria**: Transaction prevents double-write, first upload wins, no duplicates

---

## ✅ Test Case 5: Admin Accepts Payment Verification

**Objective**: Verifikasi bahwa admin accept update existing document + move booking to paid state.

**Setup**:
- Same booking from Test Case 3 (payment.verificationStatus='pending')
- Logged in as admin
- Navigate to admin dashboard → "Verifikasi Pembayaran"

**Steps**:
1. Find booking in pending verification queue
2. View proof image (preview)
3. Click "Accept" button
4. Confirm acceptance in dialog
5. Wait 2-3 seconds for update
6. Check Firestore

**Verification**:
```
Expected in Firestore:
- ✅ Document ID unchanged
- ✅ payment.verificationStatus = 'accepted'
- ✅ payment.verificationAcceptedAt = serverTimestamp()
- ✅ payment.verificationAcceptedBy = admin_uid
- ✅ status = 'paid' (or equivalent)

UI update:
- ✅ Booking disappears from pending verification queue
- ✅ Booking appears in "Terbayar" tab in My Bookings
- ✅ Real-time update within 2-3 seconds

Document count: 1 (no duplicates)
```

**Pass Criteria**: Status updated, doc ID unchanged, UI refreshes, booking moved correctly

---

## ✅ Test Case 6: Admin Rejects & Allows Re-upload

**Objective**: Verifikasi bahwa admin reject dengan allow-reupload setting membuka ulang proof upload.

**Setup**:
- Create fresh booking (from Test Case 1 flow)
- Customer uploads "wrong" proof (or test image)
- Admin rejects in verification queue

**Steps**:
1. Admin opens pending verification for this booking
2. Click "Reject" button
3. Enter rejection reason (cth: "Bukti tidak valid")
4. Toggle "Izinkan re-upload" to ON
5. Click "Reject" in dialog
6. Wait for notification to customer
7. Customer receives SnackBar notification
8. Customer can upload new proof

**Verification**:
```
Expected in Firestore after reject:
- ✅ payment.verificationStatus = 'rejected'
- ✅ payment.proofLocked = false (allows re-upload)
- ✅ payment.proofUrl = null (cleared)
- ✅ payment.rejectionReason = "Bukti tidak valid"
- ✅ payment.verificationRejectedAt = serverTimestamp()
- ✅ Document ID unchanged

UI on customer side:
- ✅ PaymentScreenImproved shows "❌ Pembayaran Ditolak"
- ✅ Rejection reason displayed
- ✅ "Upload Bukti Pembayaran" button enabled again
- ✅ Customer can select & upload new image

If admin rejects without allow-reupload:
- ✅ payment.proofLocked = true (no more upload)
- ✅ Customer cannot retry
```

**Pass Criteria**: Proof cleared, lock released, button re-enabled, reason shown

---

## ✅ Test Case 7: My Bookings Tab Exclusivity (No Duplicates in UI)

**Objective**: Verifikasi bahwa setiap booking muncul HANYA di 1 tab, tidak di multiple tabs.

**Setup**:
- Create 3-4 bookings dengan statuses berbeda:
  - Booking A: status='pending_confirmation' (tab: Menunggu Konfirmasi)
  - Booking B: status='confirmed', verificationStatus=null (tab: Menunggu Pembayaran)
  - Booking C: status='confirmed', verificationStatus='pending' (tab: Pembayaran Dikirim)
  - Booking D: status='confirmed', verificationStatus='accepted' (tab: Terbayar)

**Steps**:
1. Open "My Bookings" screen as customer
2. Check each of 5 tabs (Menunggu Konfirmasi, Menunggu Pembayaran, Pembayaran Dikirim, Terbayar, Dibatalkan)
3. Count which tabs each booking appears in
4. Switch tabs multiple times to ensure consistency

**Verification**:
```
Expected:
- ✅ Booking A appears ONLY in "Menunggu Konfirmasi" tab
- ✅ Booking B appears ONLY in "Menunggu Pembayaran" tab
- ✅ Booking C appears ONLY in "Pembayaran Dikirim" tab
- ✅ Booking D appears ONLY in "Terbayar" tab
- ✅ None appear in "Dibatalkan" tab (unless cancelled)
- ✅ Scrolling through tabs shows no overlapping bookings

Query validation:
Each tab query should be mutually exclusive:
- Tab 1: status='pending_confirmation'
- Tab 2: status='confirmed' AND (verificationStatus==null OR verificationStatus=='pending')
- Tab 3: status='confirmed' AND verificationStatus='pending'
- Tab 4: status='confirmed' AND verificationStatus='accepted'
- Tab 5: status='cancelled'

No booking should match multiple conditions.
```

**Pass Criteria**: Each booking in exactly 1 tab, no overlaps, queries mutually exclusive

---

## ✅ Test Case 8: Real-Time Updates (StreamBuilder Responsiveness)

**Objective**: Verifikasi bahwa UI update real-time ketika booking status berubah di Firestore.

**Setup**:
- 2 screens open: customer My Bookings, admin Verification Queue
- Same booking: status='confirmed', verificationStatus='pending'
- Booking currently in "Menunggu Pembayaran" tab in My Bookings

**Steps**:
1. On customer device: Open My Bookings
2. On admin device: Open Payment Verification Queue
3. Admin clicks "Accept" for the booking
4. Observe customer My Bookings screen (DON'T refresh)
5. Measure time for booking to move from "Menunggu Pembayaran" to "Terbayar" tab

**Verification**:
```
Expected behavior:
- ✅ Within 1-3 seconds: booking disappears from current tab
- ✅ Within 1-3 seconds: booking appears in "Terbayar" tab
- ✅ No manual refresh needed
- ✅ Status badge updates in real-time
- ✅ Payment info updates without page reload

UI indicators:
- ✅ StatusChip changes color/text
- ✅ Payment section updates
- ✅ Timestamps refresh

StreamBuilder snapshot count:
- Should be 2-3 snapshots from backend (not excessive, not delayed)
```

**Pass Criteria**: Update appears within 3 seconds, UI responsive, no manual refresh needed

---

## 📊 Test Summary Sheet

Create table to track results:

| Test Case | Status | Issue Found | Fix Applied | Notes |
|-----------|--------|-------------|-------------|-------|
| 1. Create Booking | ⏳ | - | - | Check 1 doc created |
| 2. Admin Confirm | ⏳ | - | - | Check ID unchanged |
| 3. Upload Proof | ⏳ | - | - | Check proofLocked=true |
| 4. Concurrent Upload | ⏳ | - | - | Check transaction safety |
| 5. Admin Accept | ⏳ | - | - | Check status transition |
| 6. Admin Reject | ⏳ | - | - | Check proof cleared |
| 7. Tab Exclusivity | ⏳ | - | - | Check no overlaps |
| 8. Real-Time Update | ⏳ | - | - | Check < 3s response |

---

## 🚀 Execution Steps

### Before Testing:
1. Deploy updated appointment_screen.dart + PaymentScreenImproved
2. Deploy QueryBuilder fix in booking_anti_duplicate_service.dart
3. Clear Firestore data (or use isolated test users)
4. Have 2 test devices ready (or browser + mobile)

### During Testing:
1. Follow each test case sequentially (they build on each other)
2. Check Firestore console after each step
3. Note any issues in summary sheet
4. Take screenshots of failures

### After Testing:
1. Review issues found
2. File bugs with reproduction steps
3. Fix & re-test
4. Mark each test as ✅ PASSED
5. Get sign-off before production deploy

---

## ❌ Common Issues & Fixes

**Issue**: Booking appears in 2 tabs simultaneously
- Likely cause: Query not exclusive (verify WHERE clause logic)
- Fix: Check tab query conditions are mutually exclusive

**Issue**: Upload creates multiple documents
- Likely cause: Not using transaction (multiple `.add()` calls)
- Fix: Verify using `submitPaymentProof()` from BookingAntiDuplicateService (transaction-safe)

**Issue**: Concurrent uploads both succeed
- Likely cause: No proofLocked check in transaction
- Fix: Ensure transaction reads current proofLocked, rejects if true

**Issue**: Real-time update takes > 5 seconds
- Likely cause: Snapshot listener not properly attached or network delay
- Fix: Check StreamBuilder setup, verify Firestore permissions

---

**File**: lib/services/booking_anti_duplicate_service.dart
**Key Methods to Test**:
- `streamCustomerBookingsFiltered(userId, filterType)` - Exclusive queries
- `submitPaymentProof(bookingId, proofUrl, userId)` - Transaction for upload
- `acceptPaymentVerification(bookingId, adminUid)` - Transaction for accept
- `rejectPaymentVerification(bookingId, adminUid, reason, allowReupload)` - Transaction for reject
