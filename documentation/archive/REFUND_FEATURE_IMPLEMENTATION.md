# 💰 REFUND FEATURE IMPLEMENTATION

## Overview
Fitur refund yang complete untuk handling pembatalan booking dengan tracking refund status dan automatic proof deletion.

---

## 1. Database Schema Updates

### Queue Model (`lib/models/queue.dart`)
Added 4 new fields untuk track refund:

```dart
final bool? isRefunded;           // apakah booking sudah di-refund
final Timestamp? refundedAt;      // waktu refund diproses
final String? refundReason;       // alasan refund (cancelled, rejected, etc)
final String? refundedBy;         // admin uid yang process refund
```

**Updates dilakukan di 3 lokasi:**
1. **Field Declaration** - Definisi property di class
2. **Constructor** - Add parameter untuk initialization
3. **fromFirestore()** - Parse dari Firestore dengan backward compatibility
4. **toJson()** - Serialize ke Firestore dengan FieldValue.delete() support
5. **copyWith()** - Builder method support refund fields

---

## 2. Service Layer Implementation

### QueueService (`lib/services/queue_service.dart`)

#### New Method: `adminRefundBooking()`
```dart
Future<void> adminRefundBooking(
  String queueId, {
  String? reason = 'Dibatalkan oleh admin',
  String? adminUid,
})
```

**Functionality:**
- Sets status to 'cancelled'
- Sets isRefunded = true
- Records refundedAt timestamp (server-generated)
- Stores refundReason and refundedBy
- **CRITICAL**: Clears paymentProofBase64 using `FieldValue.delete()` (HIDES proof)
- Creates notification untuk customer

**Business Logic:**
```
1. Get queue document
2. Update dengan transaction:
   - status: 'cancelled'
   - is_refunded: true
   - refunded_at: server timestamp
   - refund_reason: reason
   - refunded_by: admin uid
   - payment_proof_base64: DELETE (remove from database)
   - updated_at: server timestamp
3. Fetch updated document
4. Create customer notification
```

---

## 3. Customer UI Updates

### BookingDetailScreen (`lib/screens/customer/booking_detail_screen.dart`)

#### Payment Proof Display Logic
**BEFORE:** Showed payment proof anytime it existed
**AFTER:** Only shows during awaiting_payment phase

```dart
// Only show payment proof confirmation during awaiting_payment phase
if (_queue!.status.name == 'awaiting_payment' && _queue!.paymentProofBase64 != null) ...[
  const SizedBox(height: 4),
  const Text('✓ Bukti pembayaran terunggah', style: TextStyle(color: Colors.green)),
],
```

#### Upload & View Buttons
Both buttons now check status:
```dart
// Upload Button - Only show during awaiting_payment phase
if (_queue!.status.name == 'awaiting_payment')
  ElevatedButton(...)

// View Proof Button - Only show during awaiting_payment with proof uploaded
if (_queue!.status.name == 'awaiting_payment' && _queue!.paymentProofBase64 != null)
  ElevatedButton(...)
```

#### Refund Information Display
New section shows when cancelled AND refunded:
```dart
// Show refund information when cancelled & refunded
if (_queue!.status.name == 'cancelled' && _queue!.isRefunded == true) ...[
  const SizedBox(height: 4),
  const Text('💰 Refund Diproses', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
  if (_queue!.refundReason != null) ...[
    const SizedBox(height: 4),
    Text('Alasan: ${_queue!.refundReason}', style: const TextStyle(color: kTextGrey, fontSize: 12)),
  ],
  if (_queue!.refundedAt != null) ...[
    const SizedBox(height: 4),
    Text('Tanggal refund: ${_formatTimestamp(_queue!.refundedAt!)}', 
         style: const TextStyle(color: kTextGrey, fontSize: 12)),
  ],
],
```

**Payment Proof Lifecycle:**
1. **awaiting_payment**: Show upload form + proof button if uploaded
2. **cancelled (not refunded)**: Hide proof, no refund info shown
3. **cancelled (isRefunded=true)**: Hide proof, show refund info instead

---

## 4. Admin UI Updates

### QueueCard Component (`lib/widgets/admin/queue_card.dart`)

#### Refund Button
Shows only for cancelled bookings that haven't been refunded:

```dart
// REFUND ACTION BUTTON - Show for cancelled bookings that haven't been refunded yet
if (status == QueueStatus.cancelled && (queue.isRefunded != true))
  Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _processingRefund ? null : _handleRefund,
        icon: _processingRefund
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Icon(Icons.money_off, size: 16),
        label: const Text('Proses Refund'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
  ),
```

#### Refund Dialog Flow
1. Admin clicks "Proses Refund" button
2. Dialog appears untuk input alasan refund
3. Admin enter reason dan click "Proses Refund"
4. Backend call: `adminRefundBooking(queueId, reason)`
5. Success notification ditampilkan

---

## 5. Data Flow Diagram

```
CUSTOMER VIEW (BookingDetailScreen)
=====================================

Status: awaiting_payment
├─ Show: Upload button + "Bukti pembayaran terunggah" (jika sudah upload)
├─ Hide: Refund info
└─ Action: Customer upload proof

Status: cancelled (isRefunded = false)
├─ Show: Nothing about payment/refund
├─ Hide: Proof, Refund info
└─ Action: None

Status: cancelled (isRefunded = true)
├─ Show: "💰 Refund Diproses"
│        "Alasan: [refundReason]"
│        "Tanggal refund: [refundedAt]"
├─ Hide: Proof (deleted from DB)
└─ Action: None


ADMIN VIEW (QueueCard)
======================

Status: cancelled (isRefunded = false)
├─ Show: "Proses Refund" button (orange)
└─ Click: Open refund dialog

Dialog Action:
├─ Input reason
├─ Click "Proses Refund"
├─ Backend: adminRefundBooking()
│  ├─ Set status='cancelled'
│  ├─ Set isRefunded=true
│  ├─ Set refundedAt=now
│  ├─ Set refundReason=input
│  ├─ Set refundedBy=adminUid
│  └─ DELETE payment_proof_base64
├─ Create notification
└─ UI Update: Button disappear, Refund info shown

Status: cancelled (isRefunded = true)
├─ Show: Refund info (Refund diproses)
└─ Hide: "Proses Refund" button
```

---

## 6. Proof Deletion Logic

**CRITICAL FEATURE**: Payment proof automatically deleted when refunding

### Firestore Update:
```dart
tx.update(ref, {
  'status': 'cancelled',
  'is_refunded': true,
  'refunded_at': FieldValue.serverTimestamp(),
  'refund_reason': reason,
  'refunded_by': refundedBy,
  // PENTING: Hapus bukti pembayaran dari database (hide proof)
  'payment_proof_base64': FieldValue.delete(),
  'updated_at': FieldValue.serverTimestamp(),
});
```

**Why delete?**
- Privacy: Tidak perlu simpan proof setelah refund
- Storage efficiency: Proof base64 bisa besar (hingga 5MB+)
- Security: Mengurangi data sensitif di database

---

## 7. Business Rules

### Refund Trigger Points
1. **Admin Cancel**: Admin klik cancel button saat status pending/booked → becomes cancelled (tanpa refund yet)
2. **Admin Refund**: Admin klik "Proses Refund" untuk process actual refund
3. **Payment Timeout**: Auto-cancel jika customer tidak bayar dalam 10 menit
4. **Payment Reject**: Admin reject payment → status cancelled (bisa refund nanti)

### Refund Status States
```
cancelled + isRefunded=false → "Pembayaran dibatalkan, belum di-refund"
cancelled + isRefunded=true  → "Pembayaran sudah di-refund"
```

### Proof Lifecycle
```
Created:      When customer upload (status = awaiting_payment)
Visible:      Only during awaiting_payment
              Admin & customer can view
Deleted:      When admin process refund
              FieldValue.delete() removes from database
Never Shown:  After refund processed
```

---

## 8. Testing Checklist

### Customer Side
- [ ] Payment proof upload works during awaiting_payment
- [ ] Proof not shown after cancellation (before refund)
- [ ] Refund info displayed after refund processed
- [ ] Refund reason & date visible
- [ ] Upload button hidden after status != awaiting_payment
- [ ] View proof button hidden after cancellation

### Admin Side
- [ ] Refund button appears on cancelled (not refunded) bookings
- [ ] Refund button NOT appear on already refunded bookings
- [ ] Refund dialog appears on button click
- [ ] Can input reason in dialog
- [ ] Refund processed after clicking confirm
- [ ] Notification sent to customer
- [ ] Database fields updated correctly
- [ ] Proof actually deleted from database
- [ ] UI refresh shows refund info

### Database
- [ ] isRefunded = true after refund
- [ ] refundedAt timestamp recorded
- [ ] refundReason stored correctly
- [ ] refundedBy has admin UID
- [ ] payment_proof_base64 is NULL after refund
- [ ] All fields persisted correctly

---

## 9. Files Modified

1. **lib/models/queue.dart**
   - Added 4 refund fields
   - Updated constructor, fromFirestore(), toJson(), copyWith()

2. **lib/services/queue_service.dart**
   - Added `adminRefundBooking()` method
   - Includes proof deletion & notification

3. **lib/screens/customer/booking_detail_screen.dart**
   - Conditional proof display (only awaiting_payment)
   - Refund info section (when cancelled & refunded)
   - Updated upload/view buttons conditions

4. **lib/widgets/admin/queue_card.dart**
   - Added _processingRefund state
   - Added _handleRefund() method
   - Added refund button to UI
   - Import QueueService & FirebaseAuth

5. **lib/screens/admin/live_queue_screen.dart**
   - (No changes needed - QueueCard handles refund)

---

## 10. API Summary

### Queue Model
```dart
// New fields
bool? isRefunded
Timestamp? refundedAt
String? refundReason
String? refundedBy
```

### QueueService
```dart
Future<void> adminRefundBooking(
  String queueId, {
  String? reason = 'Dibatalkan oleh admin',
  String? adminUid,
})
```

### UI Integration
```dart
// Customer: Show proof only during awaiting_payment
// Customer: Show refund info when cancelled + isRefunded
// Admin: Show refund button when cancelled + !isRefunded
```

---

## 11. Deployment Notes

- ✅ No database migration needed (backward compatible)
- ✅ Existing cancelled bookings unaffected
- ✅ No external API required
- ✅ Proof deletion uses Firestore FieldValue.delete()
- ✅ All changes in-memory only (QueueCard state)
- ✅ No new dependencies added

---

## 12. Future Enhancements

- [ ] Automatic refund processing (schedule after 1 hour)
- [ ] Refund reason templates dropdown
- [ ] Refund history report for admin
- [ ] Payment reconciliation report
- [ ] Partial refund support
- [ ] Refund reversal/undo feature
- [ ] SMS/Email notification on refund

---

## Summary

✅ **Refund feature fully implemented with:**
- Payment proof lifecycle management
- Automatic proof deletion on refund
- Customer refund info visibility
- Admin refund processing UI
- Complete notification system
- Backward compatible database design

**Key Feature:** Payment proof only visible during payment phase, automatically deleted when refunded, and replaced with refund info for customer.
