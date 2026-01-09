# 🎯 BOOKING FLOW DIAGRAM - VISUAL REFERENCE

---

## 1️⃣ COMPLETE BOOKING LIFECYCLE (Timeline)

```
TIME:     0 min        5 min        10 min       15 min       20 min
          |            |            |            |            |
CUSTOMER: Book ────► Pay ──────► Wait ────────► Confirmed ──► Service
          Request   Notif     Upload Proof    Notification  Begins
          ├──────────────────────────────────┤
          │    ADMIN VERIFICATION GATES      │
          └──────────────────────────────────┘

STATUS:   waiting ──► awaiting_payment ────► booked ──► ongoing ──► served
          (0 min)    (10 min window)      (verified)  (started)  (done)

QUEUE:    ❌ Hidden   ❌ Hidden            ✅ ACTIVE   ✅ ACTIVE   ❌ Done
          from       from                 in queue   in queue    (archived)
          barber     barber
```

---

## 2️⃣ STAGE-BY-STAGE FLOW CHART

```
╔═══════════════════════════════════════════════════════════════════════════╗
║                           STAGE 1: REQUEST                               ║
╚═══════════════════════════════════════════════════════════════════════════╝

  CUSTOMER SIDE:                        FIRESTORE:
  ───────────────                       ──────────
  
  1. Browse services                    Queue document created:
  2. Select date/time          ───→    {
  3. Tap "Book"                          status: "waiting",
  4. Submit request                      customer_id: "uid123",
                                         booking_time: "2025-11-29 14:00",
                                         created_at: NOW,
  
  Status shown: "Waiting..."             created_at: NOW
                                       }
  
  Admin sees:
  "New Booking Request" in dashboard


╔═══════════════════════════════════════════════════════════════════════════╗
║                    STAGE 2: ADMIN APPROVAL (FIRST GATE)                   ║
╚═══════════════════════════════════════════════════════════════════════════╝

  ADMIN SIDE:                           FIRESTORE UPDATE:
  ──────────────                        ─────────────────
  
  1. Dashboard                          Queue status CHANGED:
  2. Click "Verify Booking"    ───→    {
  3. See new requests                     status: "awaiting_payment",
  4. Review details                       request_status: "approved",
  5. Click "Approve"                      verified_by: "admin_uid_456",
                                          payment_due_at: NOW + 10 MIN,
  Status shows: "Approved"              }
                                        
                                        ✅ Notification AUTO-CREATED:
                                        {
                                          user_id: "uid123",
                                          title: "Booking Disetujui",
                                          body: "Pembayaran dalam 10 menit",
                                          queue_id: "queue_xyz",
                                          created_at: NOW
                                        }
  
  CUSTOMER SIDE:
  ──────────────
  Notification arrives in app/phone
  See countdown timer: 9:59 ⏱️


╔═══════════════════════════════════════════════════════════════════════════╗
║                   STAGE 3: PAYMENT UPLOAD (TIME CRITICAL)                 ║
╚═══════════════════════════════════════════════════════════════════════════╝

  CUSTOMER SIDE:                        FIRESTORE UPDATE:
  ───────────────                       ─────────────────
  
  1. Tap notification           ───→   Queue UPDATED:
  2. BookingDetailScreen opens  {
  3. See countdown timer          status: "awaiting_payment",
     ├─ Color: 🟢 (> 5 min)       payment_proof_base64: "[BASE64_IMAGE]",
     ├─ Color: 🟡 (3-5 min)       payment_uploaded_at: NOW
     └─ Color: 🔴 (< 3 min)     }
  4. Tap "Upload Bukti"
  5. Select image from gallery
  6. Confirm upload
  
  Status shown: "Waiting admin verify"
  
  ⚠️  IF TIMEOUT (10 min passed):
      Auto-cancel triggered
      Status → "cancelled"
      Notification: "Waktu pembayaran habis"


╔═══════════════════════════════════════════════════════════════════════════╗
║                    STAGE 4: ADMIN PAYMENT VERIFY (SECOND GATE)             ║
╚═══════════════════════════════════════════════════════════════════════════╝

  ADMIN SIDE:                           FIRESTORE UPDATE:
  ──────────────                        ─────────────────
  
  1. Dashboard                          Queue status CHANGED:
  2. Click "Verify Payment"    ───→    {
  3. See awaiting_payment list           status: "booked",
  4. Click booking                       payment_verified_by: "admin_uid_456",
  5. See proof preview                   payment_verified_at: NOW,
  6. Click "Confirm"                     request_status: "approved"
                                       }
     OR                                  
     Click "Reject"                      ✅ Notification AUTO-CREATED:
                                         {
  Status shows: "Verified ✓"              user_id: "uid123",
                                          title: "Pembayaran Terverifikasi",
                                          body: "Booking siap untuk service",
                                          queue_id: "queue_xyz",
                                          created_at: NOW
                                        }
  
  CUSTOMER SIDE:
  ──────────────
  Notification arrives: "Payment Verified ✓"
  Status: "Booking Confirmed - Ready"
  Countdown: GONE ✓


╔═══════════════════════════════════════════════════════════════════════════╗
║                    STAGE 5: QUEUE ACTIVE (READY FOR SERVICE)               ║
╚═══════════════════════════════════════════════════════════════════════════╝

  BARBER SIDE:                          FIRESTORE:
  ──────────────                        ──────────
  
  1. Open Dashboard                     Queue status: "booked" ✅ VISIBLE
  2. See active queue               {   
  3. Queue shows customer name          status: "booked",
  4. Click to see details               payment_verified: true,
  5. Tap "Start Service"       ───→    created_at: "2025-11-29 14:00",
                                        updated_at: NOW
  Status shows: "Ongoing"             }
  
  CUSTOMER SIDE:
  ──────────────
  See: "Service ready at 14:00"
  Barber: Ahmad (Rating: 4.8⭐)
  
  Later: Notification "Service started"
```

---

## 3️⃣ STATUS TRANSITION DIAGRAM

```
                    ┌─────────────────────┐
                    │  Customer Creates   │
                    │  Booking Request    │
                    └──────────┬──────────┘
                               │
                          WAITING
                               │
                               ▼
                    ┌─────────────────────┐
                    │  ADMIN APPROVES     │
                    │  (First Gate) ✅     │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
          ┌────────►│ AWAITING_PAYMENT    │◄─────────┐
          │         │ (10 min deadline)   │          │
          │         └──────────┬──────────┘          │
          │                    │                     │
    PAYMENT              CUSTOMER UPLOADS        NO PAYMENT
    EXPIRED              PROOF WITHIN 10 MIN     (Auto-cancel)
    (Auto-cancel)              │                     │
          │                    ▼                     │
          │          ┌─────────────────────┐         │
          │          │  ADMIN VERIFIES     │         │
          │          │  (Second Gate) ✅    │         │
          │          └──────────┬──────────┘         │
          │                     │                    │
          │          ┌──────────┴──────────┐         │
          │          │                     │         │
          │    APPROVE ✓          REJECT ✗ │         │
          │          │                     │         │
          │          ▼                     ▼         ▼
          │     ┌──────────┐          ┌──────────────────┐
          │     │  BOOKED  │          │  CANCELLED       │
          │     │ ✅ ACTIVE│          │ (No queue entry) │
          │     │ IN QUEUE │          └──────────────────┘
          │     └────┬─────┘
          │          │
    EXPIRES     SERVICE STARTS
          │          │
          └────────►▼
              ┌──────────────┐
              │   CANCELLED  │
              │ (No service) │
              └──────────────┘

              BARBER STARTS
                   │
                   ▼
              ┌──────────────┐
              │   ONGOING    │
              │ (Service)    │
              └────────┬─────┘
                       │
              SERVICE COMPLETED
                       │
                       ▼
              ┌──────────────┐
              │    SERVED    │
              │ (Completed)  │
              └──────────────┘
```

---

## 4️⃣ DATA FLOW: REQUEST → APPROVAL → PAYMENT → VERIFICATION

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          CUSTOMER APP                                    │
└──────────────────────────────────────────────────────────────────────────┘

        Step 1: Browse & Book
        ├─ Service selection
        ├─ Date/time picker
        └─ Submit request
               │
               │ creates
               ▼
        Queue: status="waiting"
               │
               │ poll/listen
               │ (every 2s or Firestore stream)
               │
               ▼
        [WAITING for admin...]
               │
               │ notification received (realtime)
               │ "Booking Disetujui - Bayar dalam 10 menit"
               │
               ▼
        Step 2: Upload Payment Proof
        ├─ Tap notification → BookingDetailScreen
        ├─ See countdown: 10:00 ⏱️
        ├─ Tap "Upload Bukti"
        ├─ Choose image
        └─ Confirm
               │
               │ uploads to Firestore
               │ (base64 string)
               │
               ▼
        Queue: payment_proof_base64 set
               │
               │ wait for admin verification
               │
               ▼
        [WAITING for admin verification...]
               │
               │ notification received (realtime)
               │ "Pembayaran Terverifikasi!"
               │
               ▼
        Step 3: View Booking Confirmed
        ├─ Status: "Booking Confirmed ✓"
        ├─ See barber name
        ├─ See service time
        └─ Ready for service


┌──────────────────────────────────────────────────────────────────────────┐
│                          ADMIN APP                                       │
└──────────────────────────────────────────────────────────────────────────┘

        Step 1: Verify New Requests
        ├─ Dashboard → "Verify Booking" tab
        ├─ See new requests (status="waiting")
        ├─ Click to view details
        └─ Tap "Approve" or "Reject"
               │
               │ calls adminConfirmRequest()
               │
               ▼
        Queue: status="awaiting_payment"
        Queue: payment_due_at = now + 10 min
        Notification: auto-created & sent
               │
               │ customer receives notification
               │ customer uploads payment proof
               │
               ▼
        Step 2: Verify Payment
        ├─ Dashboard → "Verify Payment" tab
        ├─ See awaiting_payment bookings
        ├─ Click booking
        ├─ See proof preview (base64 → image)
        └─ Tap "Confirm" or "Reject"
               │
               │ calls adminConfirmPayment()
               │
               ▼
        Queue: status="booked"
        Queue: payment_verified_at = now
        Notification: auto-created & sent
               │
               │ NOW visible in barber's active queue
               │
               ▼
        Step 3: Monitor Active Queue
        ├─ Barber dashboard
        ├─ See "booked" bookings in queue
        └─ Can start service


┌──────────────────────────────────────────────────────────────────────────┐
│                      FIRESTORE (Data Source)                             │
└──────────────────────────────────────────────────────────────────────────┘

Collection: queues

waiting ────────────────► {
│                           status: "waiting"
│ Admin confirms            customer_id: "uid_123"
│                           created_at: Timestamp
│                         }
│
awaiting_payment ──────► {
│                           status: "awaiting_payment"
│ Customer uploads proof    payment_due_at: Timestamp(+10min)
│ + Admin verifies          payment_proof_base64: "..."
│                         }
│
booked ────────────────► {
│ (ACTIVE in queue)         status: "booked"
│ Barber starts service     payment_verified: true
│                           payment_verified_at: Timestamp
│                         }
│
ongoing ───────────────► {
│                           status: "ongoing"
│ Service completed         start_time: Timestamp
│                         }
│
served ────────────────► {
                           status: "served"
                           end_time: Timestamp
                         }
```

---

## 5️⃣ TIMING & CRITICAL WINDOWS

```
Timeline (Minutes)
────────────────────────────────────────────────────────────

0 min     5 min          10 min         15 min
│         │              │              │
│         │ ADMIN        │              │
│         │ CONFIRMS     │              │
│         ▼              │              │
│         ║ CUSTOMER HAS 10 MIN TO PAY  │
│         ║              │              │
│         ║ 🟢 Green     🟡 Yellow 🔴Red│
│         ║              │              │
│         ║ Upload proof │              │
│         ║ anytime here │              │
│         │              ▼              │
│         │         ⏰ TIMEOUT        │
│         │              │              │
│         │              ├─ If no proof:
│         │              │   Auto-cancel
│         │              │
│         │              └─ If proof uploaded:
│         │                  Admin can verify
│         │                  up to 24 hours
│         │
└─────────┴──────────────┴──────────────┴─
           ↑              ↑
        Payment          Auto-cancel
        window opens     if no proof
```

---

## 6️⃣ WHAT HAPPENS IF...?

```
SCENARIO 1: Customer Doesn't Upload in 10 Min
─────────────────────────────────────────────
Timer: 10:00 → ... → 0:01 → 0:00 ⏰
Action: Background job triggers
Result:
  ✓ Status: awaiting_payment → cancelled
  ✓ Notification: "Waktu pembayaran habis"
  ✓ Queue removed from awaiting_payment
  ✓ Customer can re-book
  ✓ Slot freed for others

SCENARIO 2: Admin Rejects Payment
──────────────────────────────────
Admin sees proof, it's invalid:
  ✓ Tap "Reject"
  ✓ Status: awaiting_payment → cancelled
  ✓ Notification: "Pembayaran ditolak"
  ✓ Queue removed
  ✓ Customer can upload again or re-book

SCENARIO 3: Network Error During Upload
────────────────────────────────────────
Customer uploading when connection lost:
  ✓ App retries automatically
  ✓ Or shows error: "Upload gagal, coba lagi"
  ✓ Customer can retry within 10 min window

SCENARIO 4: Payment Expires While Admin is Verifying
────────────────────────────────────────────────────
Timeline:
  - Customer uploads proof at 9:50 (in time)
  - 10 min deadline at 10:00
  - Admin starts verification at 10:05 (too late!)
  
Result: DEPENDS ON IMPLEMENTATION
  Option A: Block (don't allow verify)
  Option B: Auto-extend deadline (suggest 5 more min)
  Option C: Admin override (verify anyway)
  
Recommended: Option A (strict, prevents gaming)
```

---

## 7️⃣ QUEUE VISIBILITY BY ROLE

```
┌──────────────────────────────────────────────────────────────┐
│                 QUEUE VISIBILITY MATRIX                      │
└──────────────────────────────────────────────────────────────┘

Status              │ Customer  │ Admin  │ Barber │ Public
─────────────────────────────────────────────────────────────
waiting             │ ✓ (own)   │ ✓      │ ✗      │ ✗
awaiting_payment    │ ✓ (own)   │ ✓      │ ✗      │ ✗
booked              │ ✓ (own)   │ ✓      │ ✓✓✓    │ ✗
ongoing             │ ✓ (own)   │ ✓      │ ✓✓✓    │ ✗
served              │ ✓ (own)   │ ✓      │ ✓      │ ✗
cancelled           │ ✓ (own)   │ ✓      │ ✗      │ ✗

Legend:
✓ = Can see (read-only)
✓✓✓ = Can see + interact (start service, complete, etc)
✗ = Cannot see
(own) = Only their own bookings
```

---

## 8️⃣ NOTIFICATION TRIGGERS

```
Event                              │ Trigger By      │ Auto-create?
──────────────────────────────────────────────────────────────
Customer creates booking           │ Customer        │ ✗ (no notify)
Admin approves request             │ Admin action    │ ✅ Yes (payment notif)
Payment deadline approaching       │ 5-min warning   │ ⏰ Soon (TBD)
Payment uploaded by customer       │ Customer action │ ✗ (no notify)
Admin verifies payment             │ Admin action    │ ✅ Yes (confirm notif)
Admin rejects payment              │ Admin action    │ ✅ Yes (reject notif)
Payment deadline expired           │ Auto-job        │ ✅ Yes (expired notif)
Barber starts service              │ Barber action   │ 🔔 Soon (TBD)
Service completed                  │ Barber action   │ 🔔 Soon (TBD)
```

---

**Created:** November 28, 2025  
**Format:** Visual Diagrams & Flowcharts  
**Audience:** Product Team, QA, Developers  

✅ **Booking Flow is Professional & Foolproof**
