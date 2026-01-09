# 📋 BOOKING FLOW REQUIREMENT - PROFESSIONAL SPECIFICATION

**Document Version:** 1.0  
**Date:** November 28, 2025  
**Status:** ✅ VERIFIED & IMPLEMENTED

---

## 🎯 Executive Summary

**Requirement:** 5-Stage Booking Confirmation & Payment Workflow

Sistem yang dibangun mengikuti prosedur ketat untuk memastikan:
1. Admin **konfirmasi pesanan** sebelum customer membayar
2. Customer punya **10-menit window** untuk upload bukti pembayaran
3. Admin **verifikasi pembayaran** sebelum booking final
4. Hanya setelah verified, booking masuk ke **antrian/queue**

---

## 📊 Complete Booking Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COMPLETE BOOKING FLOW                               │
└─────────────────────────────────────────────────────────────────────────────┘

STAGE 1: CUSTOMER CREATE BOOKING REQUEST
═════════════════════════════════════════════════════════════════════════════
  • Customer browse services
  • Choose date/time
  • Tap "Book" → Submit request
  • Status: "waiting" ✓

  Firestore:
  queues/{queue_id}
    - status: "waiting"
    - request_status: null
    - customer_id: "{uid}"
    - booking_time: 2025-11-29 14:00
    - created_at: timestamp

  Admin sees: "New Booking Request" in dashboard
  UI: Admin Dashboard → Verify Booking


STAGE 2: ADMIN CONFIRMS REQUEST
═════════════════════════════════════════════════════════════════════════════
  • Admin review request details
  • Admin tap "Approve" (or "Reject")
  • Status changes: "waiting" → "awaiting_payment"
  • 10-minute payment deadline set

  Action: adminConfirmRequest(queueId)
  
  Firestore UPDATE:
  queues/{queue_id}
    - status: "awaiting_payment"
    - request_status: "approved"
    - verified_by: "{admin_uid}"
    - payment_due_at: now() + 10 minutes
    - updated_at: timestamp

  ✅ AUTO NOTIFICATION CREATED:
  notifications/{doc_id}
    - user_id: "{customer_uid}"
    - title: "Booking Disetujui - Silakan Bayar"
    - body: "Silakan lakukan pembayaran dalam 10 menit..."
    - queue_id: "{queue_id}"
    - created_at: timestamp
    - delivered: false


STAGE 3: CUSTOMER RECEIVES NOTIFICATION
═════════════════════════════════════════════════════════════════════════════
  • NotificationService detects new notification doc
  • Show OS notification (Android: bar, iOS: banner)
  • Customer tap notification
  
  FLOW:
  1. Notification arrives in Firestore
  2. Client listener detects (realtime)
  3. Show local OS notification
  4. Tap → Navigate to BookingDetailScreen
  5. Mark notification as delivered: true


STAGE 4: CUSTOMER UPLOAD PAYMENT PROOF
═════════════════════════════════════════════════════════════════════════════
  • Customer open booking detail from notification or My Bookings
  • See countdown timer (10:00 → 9:59 → ... → 0:00)
  • Countdown color-coded:
    - Green: > 5 minutes
    - Yellow: 3-5 minutes
    - Red: < 3 minutes
  
  • Customer tap "Upload Bukti Pembayaran"
  • Choose image from gallery
  • Image converted to base64
  • Upload to Firestore

  Firestore UPDATE:
  queues/{queue_id}
    - payment_proof_base64: "{base64_image_string}"
    - payment_uploaded_at: timestamp
    - status: "awaiting_payment" (tetap sama)

  ⏰ AUTO-CANCEL if payment_due_at passed:
  If customer tidak upload dalam 10 menit:
    - Background job akan cancel (adminConfirmRequestExpiry)
    - Status: "awaiting_payment" → "cancelled"
    - Notification: "Payment window expired"


STAGE 5: ADMIN VERIFIES PAYMENT
═════════════════════════════════════════════════════════════════════════════
  • Admin buka "Verify Payment" screen
  • See all awaiting_payment bookings
  • Click booking to see:
    - Payment proof preview (image from base64)
    - Booking details
    - Payment info
  
  • Admin two options:
    A) "Confirm" (verify payment)
       - Status: "awaiting_payment" → "booked"
       - Queue now active (ready for service)
       - Auto notification: "Payment Verified - Booking Confirmed"
    
    B) "Reject" (payment not valid)
       - Status: "awaiting_payment" → "cancelled"
       - Auto notification: "Payment Rejected"

  Action: adminConfirmPayment(queueId) or adminRejectPayment(queueId)
  
  Firestore UPDATE:
  queues/{queue_id}
    - status: "booked"
    - request_status: "approved"
    - payment_verified_at: timestamp
    - payment_verified_by: "{admin_uid}"
    - updated_at: timestamp

  ✅ AUTO NOTIFICATION CREATED:
  notifications/{doc_id}
    - user_id: "{customer_uid}"
    - title: "Pembayaran Terverifikasi"
    - body: "Booking Anda sudah confirmed dan siap untuk service"
    - queue_id: "{queue_id}"
    - created_at: timestamp


STAGE 6: BOOKING READY FOR SERVICE
═════════════════════════════════════════════════════════════════════════════
  • Status: "booked" ✓
  • Now in active queue for barber
  • Barber can start service: "booked" → "ongoing"
  • Track status: ongoing → served → completed

```

---

## 🔑 Key Points (Profesional & Ahli)

### 1. **Two-Step Admin Approval**
- ✅ **First Confirmation**: Admin approve request (`adminConfirmRequest`)
  - Validasi availability barber/service
  - Cek schedule conflict
  - Set 10-minute payment deadline
  - Auto-create notification for customer

- ✅ **Second Verification**: Admin verify payment (`adminConfirmPayment`)
  - Check payment proof
  - Validate amount & payment method
  - Only then: booking enters queue

**Benefit:** Prevents fraud, ensures payment before booking confirmed

### 2. **Payment Deadline (Hard Stop)**
- Customer punya **exactly 10 minutes** untuk upload bukti
- Countdown timer visual di UI (color-coded)
- Expired? Auto-cancel via background job
- No payment = no booking
- Clear communication via notification

**Benefit:** Urgency + clarity, prevents booking limbo

### 3. **Notification Integration**
- **Automatic**: Triggered by admin actions
- **Real-time**: Firestore listeners (< 1 second latency)
- **Multi-channel**: In-app + local OS notification
- **Tap Navigation**: Direct to payment/booking screen
- **Tracking**: delivered flag, read flag

**Benefit:** Customer always informed, no missed updates

### 4. **Payment Proof in Firestore**
- Base64 image stored directly in queue document
- No Firebase Storage needed (per requirement)
- Scalable for MVP (< 1MB images)
- Admin can preview in-app

**Benefit:** Simple, no external dependencies, GDPR-compliant

### 5. **Queue Status Never Ambiguous**
| Status | Meaning | Queue Active? |
|--------|---------|---------------|
| `waiting` | Request submitted, awaiting admin | ❌ No |
| `awaiting_payment` | Admin approved, customer paying | ❌ No |
| `booked` | Payment verified, ready to serve | ✅ **Yes** |
| `ongoing` | Service in progress | ✅ Yes |
| `served` | Service completed | ❌ No |
| `cancelled` | Admin rejected or payment expired | ❌ No |

**Only `booked` or later = enters active queue for barber**

---

## 📱 UI/UX Flows

### Customer Flow
```
Home
  ↓
Browse Services → Select date/time
  ↓
Tap "Book"
  ↓
See status: "Waiting for admin approval"
  ↓
[Notification arrives]
  ↓
Tap notification
  ↓
BookingDetailScreen opens
  ├─ See countdown timer (10:00 → 0:00)
  ├─ See "Upload Bukti Pembayaran" button
  └─ Tap to upload image
  ↓
[Wait for admin to verify]
  ↓
[Notification: Payment Verified]
  ↓
Status: "Booking Confirmed" - Ready for service
  ↓
See barber name, time, service details
```

### Admin Flow
```
Admin Dashboard
  ├─ "Verify Booking" tab
  │  ├─ See new requests (status: waiting)
  │  ├─ Click request → see details
  │  ├─ Tap "Approve"
  │  │  └─ Status → awaiting_payment
  │  │  └─ Notification auto-sent to customer
  │  └─ OR Tap "Reject"
  │     └─ Status → cancelled
  │
  └─ "Verify Payment" tab
     ├─ See awaiting_payment bookings
     ├─ Click booking → see payment proof
     ├─ Tap "Confirm"
     │  └─ Status → booked
     │  └─ Queue now active
     │  └─ Notification auto-sent to customer
     └─ OR Tap "Reject"
        └─ Status → cancelled
```

---

## 🔐 Business Rules

### Rule 1: Cannot Skip Steps
```
❌ INVALID:
Customer creates booking → status booked (WRONG!)

✅ VALID:
waiting → admin approves → awaiting_payment 
→ customer pays → admin verifies → booked
```

### Rule 2: Payment Deadline is Hard
```
❌ INVALID:
Admin approves at 14:00
Customer pays at 14:15 (expired by 5 min)
```

Solution: Auto-cancel + re-book

### Rule 3: No Payment = No Booking
```
❌ INVALID:
Admin approves → No payment proof uploaded
→ Status still booked (WRONG!)

✅ VALID:
Admin approves → Payment proof required
→ Only after verification = booked
```

### Rule 4: Queue Activity Depends on Status
```
- waiting: NOT in queue (hidden from barber)
- awaiting_payment: NOT in queue (hidden from barber)
- booked: IN queue (visible to barber, can start service)
- ongoing: IN queue (service running)
- served: Completed (archive)
```

---

## 💾 Firestore Schema

### Queue Document
```firestore
queues/{queue_id}
{
  // Identity
  customer_id: String,
  barbershop_id: String,
  barber_id: String,
  service_id: String,
  
  // Booking Details
  booking_time: Timestamp,
  service_duration_minutes: Number,
  
  // Status Fields
  status: String (waiting|awaiting_payment|booked|ongoing|served|cancelled),
  request_status: String (null|approved|rejected),
  
  // Approval & Verification
  verified_by: String (admin_uid),
  payment_due_at: Timestamp (now + 10 min),
  payment_uploaded_at: Timestamp,
  payment_proof_base64: String,
  payment_verified_at: Timestamp,
  payment_verified_by: String,
  rejection_reason: String (optional),
  
  // Timeline
  created_at: Timestamp,
  updated_at: Timestamp,
  start_time: Timestamp (when service started),
  end_time: Timestamp (when service ended),
  
  // Notes
  customer_notes: String (optional),
  admin_notes: String (optional)
}
```

### Notification Document
```firestore
notifications/{doc_id}
{
  user_id: String (customer_uid, empty if broadcast),
  broadcast: Boolean,
  title: String,
  body: String,
  queue_id: String (optional, for navigation),
  created_at: Timestamp,
  delivered: Boolean,
  delivered_at: Timestamp,
  read: Boolean (optional)
}
```

---

## 🧪 Verification Points

### Test Case 1: Admin Approve Request
```
Given: Queue with status="waiting"
When: Admin tap "Approve"
Then:
  ✓ Queue status → "awaiting_payment"
  ✓ payment_due_at set to now + 10 min
  ✓ verified_by set to admin_uid
  ✓ Notification created & auto-sent to customer
  ✓ Customer receives notification in real-time
```

### Test Case 2: Customer Upload Payment Proof
```
Given: Queue status="awaiting_payment" with countdown visible
When: Customer upload payment image
Then:
  ✓ Image converted to base64
  ✓ Stored in queue.payment_proof_base64
  ✓ payment_uploaded_at set
  ✓ Status remains "awaiting_payment"
  ✓ Waiting for admin verification
```

### Test Case 3: Admin Verify Payment
```
Given: Queue with status="awaiting_payment" + proof uploaded
When: Admin tap "Confirm"
Then:
  ✓ Queue status → "booked"
  ✓ payment_verified_at set
  ✓ payment_verified_by set to admin_uid
  ✓ Notification created & sent to customer
  ✓ Queue now visible in active queue for barber
  ✓ Barber can start service
```

### Test Case 4: Payment Deadline Expired
```
Given: Queue with payment_due_at = now - 1 min (past)
When: Background job runs (or next app open)
Then:
  ✓ Status → "cancelled"
  ✓ Notification sent: "Payment window expired"
  ✓ Queue removed from awaiting_payment list
```

---

## 📋 Implementation Checklist

### Backend (Firestore)
- [x] Queue model supports 5-stage status
- [x] Notification auto-creation on admin actions
- [x] Payment deadline tracking
- [x] Base64 proof storage
- [x] Admin verification fields

### Client App
- [x] Notification listener (real-time)
- [x] Countdown timer UI (color-coded)
- [x] Payment proof upload (image → base64)
- [x] Proof preview UI
- [x] Tap notification → navigate to booking

### Admin App
- [x] Verify Booking screen (approve/reject)
- [x] Payment Verification screen (confirm/reject)
- [x] Send Notification UI (manual trigger)
- [x] User search with autocomplete
- [x] Broadcast notification support

### Server Helper (Optional)
- [x] FCM push notification capability
- [x] CLI script for manual pushing
- [x] Express server for scheduled pushing
- [x] Pending push_requests queue

### Documentation
- [x] Complete setup guide
- [x] Testing procedures
- [x] Troubleshooting guide
- [x] Architecture reference

---

## ✅ Conclusion

**Status:** ✅ **FULLY IMPLEMENTED & VERIFIED**

Sistem booking telah dirancang dan dibangun mengikuti best practices:

✓ **Two-step confirmation**: Admin approve request, then verify payment  
✓ **10-minute payment window**: Countdown timer, auto-cancel if expired  
✓ **Real-time notifications**: Automatic, tracked, tap-navigable  
✓ **Payment verification gate**: Payment proof required before booking active  
✓ **Queue protection**: Only `booked` status enters active queue  
✓ **Error handling**: Expired payments, rejected payments, network issues  
✓ **Security**: User-specific notifications, admin verification required  
✓ **Scalability**: Firestore-only, no external storage, efficient queries  

**Result:** Professional, secure, user-friendly booking system. ✅

---

**Prepared by:** GitHub Copilot  
**Date:** November 28, 2025  
**Classification:** Professional Technical Specification
