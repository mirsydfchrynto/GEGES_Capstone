# QA Checklist: Booking & Payment Flow

**Date**: November 28, 2025  
**Version**: 1.0  
**Scope**: Client-side booking/payment workflow (Firestore-only, no Cloud Functions)

---

## Pre-Flight Checks

- [ ] Device/emulator connected: `10.10.10.9:5555`
- [ ] Flutter run: `flutter run -d 10.10.10.9:5555` (or debug/release as needed)
- [ ] Analyzer clean: `flutter analyze --no-pub` returns "No issues found!"
- [ ] Firestore emulator running (optional, for local testing)
- [ ] Test accounts created:
  - Customer: `customer@test.com` / password `test123`
  - Admin: `admin@test.com` / password `test123`
  - Barbershop/Barberman configured in Firestore

---

## Happy Path Tests

### Test 1: Customer Creates Booking (Admin Approve → Payment)

**Steps**:
1. Customer app: Navigate to New Booking
2. Select a barbershop, barberman, service(s)
3. Choose a future booking time
4. Tap "Book" → Queue created with `status='waiting'`, `request_status='pending'`
5. **Verify Firestore**: New doc in `queues` collection
   - `status = 'waiting'`
   - `request_status = 'pending'`
   - `order_id` is present (UUID or order identifier)
   - `created_at` is server timestamp

**Expected**: Booking appears in customer's "Waiting for Confirmation" tab.

---

### Test 2: Admin Confirms Booking Request

**Steps**:
1. Admin app: Open "Konfirmasi Booking" screen
2. Should see the booking created in Test 1
3. Tap "Konfirmasi Request"
4. Confirm the dialog

**Verify Firestore**:
- Same queue doc now has:
  - `status = 'awaiting_payment'`
  - `request_status = 'approved'`
  - `payment_deadline = Timestamp.fromDate(now + 10 minutes)`
  - Notification written to `notifications` collection

**Expected**:
- Booking disappears from Booking Confirmation screen (query filters `waiting` + `pending` only)
- Customer receives notification "Booking Disetujui - Silakan Bayar"
- Customer app shows booking in "Waiting for Payment" tab with countdown timer (HH:MM:SS)

---

### Test 3: Customer Uploads Payment Proof

**Steps**:
1. Customer app: Open "Waiting for Payment" tab
2. Tap the booking → Payment Screen opens
3. Verify:
   - Timer shows remaining time (countdown to payment deadline)
   - Bank details displayed
4. Tap "Upload Payment Proof" → Select image from gallery/camera
5. Verify upload button is enabled
6. Tap "Submit Proof & Create Queue" (or "Submit Proof")

**Verify Firestore**:
- Queue doc updated with:
  - `payment_proof_base64 = <base64 encoded image>`
  - `payment_submitted_at = server timestamp`
  - `status = 'awaiting_payment'` (preserved, no revert to 'waiting')
  - `order_index/{order_id}` doc created (if new) or already exists

**Expected**:
- Screen shows "Bukti Terunggah (Menunggu Verifikasi)" message
- Upload button is disabled (greyed out)
- Navigation closes and customer returns to My Bookings
- Booking now appears in "Payment Verified" tab (or "Menunggu Verifikasi" tab) with status showing "Bukti Terunggah"

---

### Test 4: Admin Verifies Payment

**Steps**:
1. Admin app: Open "Verifikasi Pembayaran" screen
2. Should see the booking with proof uploaded (green border, "PROOF OK")
3. Tap the booking card → Bottom sheet opens showing:
   - Customer name, shop, service, booking time
   - Payment proof image displayed
4. Verify image can be viewed in full-screen (tap "Lihat Full Size")
5. Optionally add notes in text field
6. Tap "Konfirmasi"

**Verify Firestore**:
- Queue doc updated with:
  - `status = 'booked'`
  - `payment_confirmed_at = server timestamp`
  - `payment_confirmed_by = admin uid`
  - `booked_at = server timestamp`

**Expected**:
- Payment verification screen updates, booking disappears (no longer `awaiting_payment`)
- Customer receives notification "Pembayaran Dikonfirmasi"
- Booking appears in customer "Booked" tab

---

### Test 5: Live Queue Appears for Barberman

**Steps**:
1. Barberman app: Open Live Queue screen
2. Should see the booking (now `status='booked'`)
3. Tap to start service → `status = 'ongoing'`
4. Complete service → `status = 'served'`

**Expected**: Booking flows through live queue states correctly.

---

## Regression / Edge Case Tests

### Test 6: Double Payment Prevention

**Steps**:
1. Repeat Test 3, but after successful upload, while still in Payment Screen:
2. Quickly tap "Submit Proof & Create Queue" again (attempt double-submit)

**Expected**:
- First submit succeeds (payment proof set, status preserved)
- Second submit shows error or is disabled (button disabled after first upload)
- **Firestore check**: Only ONE queue doc exists for `order_id` (verify `order_index/{order_id}` points to single queue)
- No duplicate queues created

---

### Test 7: Payment Expiry Auto-Cancel

**Steps**:
1. Create and confirm a booking (Test 1 + Test 2)
2. Do NOT upload proof
3. Wait until payment deadline passes (or manually advance device time by ~10 minutes)
4. Customer app: Resume app (trigger `WidgetsBindingObserver.didChangeAppLifecycleState`)

**Expected**:
- Queue status automatically changes to `'cancelled'` in Firestore
- `cancellation_reason = 'Payment timeout'`
- `cancelled_by_uid = 'system'`
- Customer app shows booking in "Cancelled" tab
- Optional: snackbar/notification "Waktu pembayaran habis. Pesanan dibatalkan otomatis."

---

### Test 8: No Double-Upload After Proof Submitted

**Steps**:
1. Follow Test 3 (upload proof)
2. Verify "Upload Payment Proof" button is disabled and shows "Bukti Pembayaran Sudah Diunggah"
3. Try tapping on it (should not respond)

**Expected**:
- Button disabled
- File picker not triggered
- User cannot select another image

---

### Test 9: Admin Screen Query Isolation

**Scenario**: After completing Test 2 (booking moved to `awaiting_payment`)

**Step A**: Open "Konfirmasi Booking" screen
- **Expected**: Booking should NOT appear (query filters `status='waiting' AND request_status='pending'`)

**Step B**: Open "Verifikasi Pembayaran" screen
- **Expected**: Booking should NOT appear yet (no payment proof uploaded)

**Step C**: Customer uploads proof (Test 3), then open Admin "Verifikasi Pembayaran"
- **Expected**: Booking NOW appears with status "PROOF OK"

**Step D**: Admin verifies payment (Test 4), then open "Konfirmasi Booking" and "Verifikasi Pembayaran"
- **Expected**:
  - "Konfirmasi Booking": Booking NOT shown (status no longer `waiting`)
  - "Verifikasi Pembayaran": Booking NOT shown (status no longer `awaiting_payment`)
  - Live Queue or Booked screen: Booking should appear

---

### Test 10: Status Regression Prevention

**Steps**:
1. Create booking (Test 1) → `status='waiting'`, `request_status='pending'`
2. Admin confirms (Test 2) → `status='awaiting_payment'`, `request_status='approved'`
3. Customer uploads proof (Test 3) → verify `status` is still `'awaiting_payment'` (NOT reverted to `'waiting'`)

**Expected**:
- Firestore doc shows `status='awaiting_payment'` throughout upload process
- No field update accidentally reverts `status` to `'waiting'`

---

### Test 11: Order Index Uniqueness Guard

**Technical Test** (requires direct Firestore inspection or test logs):

**Steps**:
1. Create booking and upload payment proof (Tests 1-3)
2. Inspect `order_index/{order_id}` collection in Firestore

**Expected**:
- Document exists with:
  - `queue_id = <id of the queue doc>`
  - `created_at = server timestamp`
- Only ONE `order_index` doc per `order_id` (no duplicates)

**Simulate Race (Advanced)**:
- Use two devices/clients to create bookings with the same `order_id` simultaneously
- Expected: Only one queue created; second client gets existing queue ref or error

---

### Test 12: Payment Proof Size Limit

**Steps**:
1. Create and confirm booking (Tests 1-2)
2. In Payment Screen, try uploading a VERY large image (>1MB)

**Expected**:
- Error shown: "Ukuran file terlalu besar. Silakan kompres atau crop gambar."
- Proof NOT submitted
- Queue status remains `'awaiting_payment'`

---

### Test 13: Network Reconnection Handling

**Steps**:
1. Turn off device network / disconnect WiFi
2. Customer attempts to upload proof
3. Expected error (no connectivity)
4. Reconnect network
5. Retry upload

**Expected**:
- After reconnect, retry should succeed
- No duplicate queues created
- Proof eventually reaches Firestore

---

### Test 14: Cancelled Booking Stays Cancelled

**Steps**:
1. Create booking and confirm (Tests 1-2)
2. Admin rejects payment (click "Tolak" in verification screen with a reason)
3. Verify booking moved to `'cancelled'` status
4. Check all customer tabs in My Bookings

**Expected**:
- Booking appears ONLY in "Cancelled" tab
- Does NOT reappear in "Waiting for Confirmation", "Waiting for Payment", etc.

---

## Cleanup & Documentation

### Post-Test Checklist

- [ ] Log analytics / screenshots of each test result
- [ ] Document any errors or unexpected behaviors
- [ ] Verify Firestore data consistency (no orphaned docs)
- [ ] Check for memory leaks / app crashes
- [ ] Validate notification delivery (FCM + local)

### Known Limitations / Future Improvements

1. **Order Index Cleanup**: Completed orders' `order_index` docs are not auto-purged; consider adding a Firestore TTL or batch cleanup Cloud Function if needed.
2. **Duplicate Prevention via Hash**: Payment proof could also use a `fileHash` field to detect re-uploads of identical proofs; currently only checks `order_id`.
3. **Automated Retry**: Client-side retry logic could use exponential backoff for transient failures.
4. **QR Code Scanning**: QR code payment feature stub in Payment Screen; not yet fully implemented.

---

## Sign-Off

| Role       | Name | Date | Status |
|------------|------|------|--------|
| QA Lead   | ___ | | ☐ Pass ☐ Fail |
| Developer | ___ | | ☐ Ready |
| Product   | ___ | | ☐ Approved |

---

**Summary**: All tests should pass to confirm the booking/payment system is robust and free of duplicate payments, status regressions, and expiry handling issues.
