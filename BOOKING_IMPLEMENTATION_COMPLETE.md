# GEGES SmartBarber - Booking Flow Implementation Guide

**Updated: November 26, 2025**  
**Status: Phase 3 Complete (Core Booking, Payment, Cancellation, Rating, & Auto-Cancel)**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Booking Lifecycle](#booking-lifecycle)
3. [Database Schema](#database-schema)
4. [API/Service Methods](#apiservice-methods)
5. [UI Screens & Navigation](#ui-screens--navigation)
6. [Cloud Functions Setup](#cloud-functions-setup)
7. [Testing Guide](#testing-guide)
8. [Deployment Checklist](#deployment-checklist)

---

## Overview

This document describes the complete booking flow for GEGES SmartBarber, including:
- Customer booking request & validation
- Admin confirmation with 10-minute payment deadline
- Customer payment proof upload (base64 stored in Firestore)
- Admin payment verification
- Customer cancellation & refund flows
- Customer rating functionality
- Automated payment timeout cancellation
- Firebase Cloud Functions for notifications & cleanup

All data is stored in **Firestore only** (no Firebase Storage). Payment proofs are base64-encoded strings.

---

## Booking Lifecycle

### Step-by-Step Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. CUSTOMER CREATES BOOKING REQUEST                                │
│    - Screen: AppointmentScreen                                      │
│    - Validates: ≥1 service, 1 barber, date (today or future),      │
│                 time (not past if today), within shop hours         │
│    - Creates Queue doc with status: 'waiting'                      │
│    - requestStatus: 'pending'                                       │
│    - Result: Customer sees "Permintaan dibuat, tunggu konfirmasi"  │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 2. ADMIN REVIEWS REQUEST                                            │
│    - Screen: BookingConfirmationScreen                              │
│    - Views: All 'waiting' & 'payment_pending' queues               │
│    - Can: Approve or Reject booking                                │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 3a. ADMIN APPROVES (Positive Path)                                 │
│    - Updates Queue:                                                 │
│      - status: 'booked'                                            │
│      - requestStatus: 'approved'                                   │
│      - paymentDeadline: now + 10 minutes                           │
│    - Customer receives notification                                │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 3b. ADMIN REJECTS (Negative Path)                                  │
│    - Updates Queue:                                                 │
│      - status: 'cancelled'                                         │
│      - requestStatus: 'rejected'                                   │
│      - rejectionReason: admin's reason                             │
│    - Booking is void, customer can create new request              │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 4. CUSTOMER UPLOADS PAYMENT PROOF (if approved)                    │
│    - Screen: PaymentScreen                                          │
│    - Timer: Shows remaining time (max 10 minutes)                  │
│    - Action: Select image → compress → encode to base64            │
│    - Uploads: Stores base64 in paymentProofBase64 field            │
│    - Updates Queue:                                                 │
│      - status: 'payment_pending'                                   │
│      - paymentProofBase64: <base64-string>                         │
│    - Result: Waiting for admin verification                        │
│                                                                     │
│    - If timeout (10 min passed, no proof):                         │
│      Cloud Function auto-cancels booking                           │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 5. ADMIN VERIFIES PAYMENT                                           │
│    - Screen: BookingConfirmationScreen                              │
│    - Reviews: Payment proof image                                  │
│    - Can: Confirm or Reject payment                                │
│    - If Confirm:                                                    │
│      - status: 'booked' (or 'ongoing' if starting immediately)    │
│      - verifiedBy: admin UID                                       │
│      - Customer notified: payment approved                         │
│    - If Reject:                                                     │
│      - status: 'cancelled'                                         │
│      - rejectionReason: reason for rejection                       │
│      - Customer notified: payment rejected                         │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 6. BARBER SERVES CUSTOMER                                           │
│    - Barber marks: startService → status: 'ongoing'               │
│    - Barber marks: finishService → status: 'served'               │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 7. CUSTOMER RATES SERVICE                                           │
│    - Screen: RatingScreen (accessed from My Bookings after served) │
│    - Inputs: Star rating (1-5), optional comment                   │
│    - Saves: Stores rating in Queue document                        │
└─────────────────────────────────────────────────────────────────────┘

ALTERNATIVE PATHS:

┌─────────────────────────────────────────────────────────────────────┐
│ CANCELLATION (from 'booked' or 'payment_pending')                  │
│    - Customer clicks Cancel in My Bookings                         │
│    - status: 'cancel_requested'                                    │
│    - Admin can: Approve or Reject cancellation                     │
│    - If Approve: status: 'cancelled', refundAmount calculated      │
│    - If Reject: status reverts to 'booked'                         │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ REFUND PROCESSING                                                   │
│    - Admin uploads refund proof (e.g., bank transfer screenshot)   │
│    - Stores as base64 in refundProofBase64 field                  │
│    - refundStatus: 'completed'                                     │
│    - Calculation: refundAmount = totalPrice * 0.9 (10% admin fee)│
└─────────────────────────────────────────────────────────────────────┘
```

---

## Database Schema

### `queues` Collection

```firestore
queues/{queueId}
  // Core Booking Info
  barbershop_id: String
  customer_id: String
  barberman_id: String
  booking_time: Timestamp       // When customer created request
  
  service_ids: Array<String>    // At least 1 service
  total_price: Integer          // Sum of all service prices
  
  // Status Fields
  status: String                // 'waiting' | 'booked' | 'payment_pending' | 
                               // 'ongoing' | 'served' | 'cancel_requested' | 'cancelled'
  request_status: String        // 'pending' | 'approved' | 'rejected'
  
  // Admin Approval (when request_status changes to 'approved')
  payment_deadline: Timestamp   // approval_time + 10 minutes
  payment_method: String        // 'manual' (for future: 'digital')
  
  // Payment Info
  payment_proof_base64: String  // Base64 encoded image
  payment_confirmed_at: Timestamp
  payment_confirmed_by: String  // Admin UID
  
  // Cancellation Fields
  cancellation_requested_by: String    // Customer UID
  cancellation_requested_at: Timestamp
  cancellation_request_reason: String
  
  // Refund Fields (if cancellation approved)
  refund_amount: Integer               // = total_price * 0.9
  refund_status: String                // 'pending' | 'completed'
  refund_proof_base64: String          // Admin's refund receipt (e.g., bank transfer)
  refund_processed_at: Timestamp
  refund_processed_by: String          // Admin UID
  
  // Service Completion
  start_time: Timestamp
  finish_time: Timestamp
  actual_duration: Integer             // Minutes
  
  // Rating (after served)
  rating: Double                       // 1.0 - 5.0
  rating_comment: String
  rated_at: Timestamp
  
  // Metadata
  created_at: Timestamp                // Record creation time (set by server)
  updated_at: Timestamp                // Last update time
  rejection_reason: String             // If request_status = 'rejected'
  verified_by: String                  // Admin UID for final verification
```

---

## API/Service Methods

### QueueService Methods

#### Booking Creation & Validation
```dart
Future<String> createQueue({
  required String barbershopId,
  required String customerId,
  required String barbermanId,
  required Timestamp bookingTime,
  required List<String> serviceIds,
  required int totalPrice,
}) → Returns queue ID

Future<bool> isSlotAvailable({
  required String barbershopId,
  required String barbermanId,
  required Timestamp bookingTime,
  int durationMinutes = 60,
}) → Checks against 'booked', 'payment_pending', 'ongoing'
```

#### Admin Actions
```dart
Future<void> manualConfirmBooking({
  required String queueId,
  String? adminUid,
}) → Sets status: 'booked', requestStatus: 'approved', 
     paymentDeadline = now + 10 min

Future<void> rejectBooking({
  required String queueId,
  String? rejectionReason,
  String? adminUid,
}) → Sets status: 'cancelled', requestStatus: 'rejected'

Future<void> confirmPayment({
  required String queueId,
  String? adminUid,
}) → Sets status: 'booked' (or 'ongoing'), payment_confirmed flags
```

#### Payment Handling
```dart
Future<void> submitPaymentProof({
  required String queueId,
  required String proofBase64,
}) → Updates paymentProofBase64, status: 'payment_pending'
```

#### Cancellation & Refund
```dart
Future<void> requestCancellation({
  required String queueId,
  String? reason,
}) → Sets status: 'cancel_requested', stores cancellation metadata

Future<void> adminApproveCancellation({
  required String queueId,
  String? adminUid,
}) → Sets status: 'cancelled', calculates refund (90% of total)

Future<void> adminRejectCancellation({
  required String queueId,
  String? reason,
  String? adminUid,
}) → Reverts status to 'booked'

Future<void> processRefund({
  required String queueId,
  required String refundProofBase64,
  String? adminUid,
}) → Uploads refund proof, sets refund_status: 'completed'
```

#### Rating
```dart
Future<void> submitRating({
  required String queueId,
  required double rating,        // 1.0 - 5.0
  String? comment,
}) → Saves rating + comment + ratedAt timestamp

Future<double> getBarbermanAverageRating(String barbermanId)
  → Returns average rating (0.0 if no ratings)

Future<List<Queue>> getBarbermanRatings(String barbermanId)
  → Returns all ratings for a barber (sorted by rating, then date)
```

---

## UI Screens & Navigation

### Customer Journey

1. **AppointmentScreen** (`lib/screens/customer/appointment_screen.dart`)
   - Validates: service selection, barber selection, date/time rules
   - Creates queue with `status: 'waiting'`
   - Shows confirmation message
   - Does NOT auto-navigate to PaymentScreen

2. **My Bookings Screen** (`lib/screens/customer/tabs/my_bookings_screen.dart`)
   - Lists all customer queues
   - For `status: 'booked'`: shows "View" button → navigates to PaymentScreen
   - For `status: 'payment_pending'`: shows "View" button → navigates to PaymentScreen
   - For `status: 'served'`: shows "Give Rating" button → navigates to RatingScreen
   - Cancel button calls `requestCancellation()` if status is 'booked' or 'payment_pending'

3. **PaymentScreen** (`lib/screens/customer/payment_screen.dart`)
   - Loads queue by `orderId` parameter
   - Displays remaining time (from `paymentDeadline`)
   - Allows image selection & upload as base64
   - On success: sets `status: 'payment_pending'`, shows waiting message
   - On error: shows retry option
   - Auto-disables after 10 minutes (or shows error)

4. **RatingScreen** (`lib/screens/customer/rating_screen.dart`)
   - Accessed only when `status: 'served'`
   - Star rating selector (1-5)
   - Optional comment text field
   - Submits rating via `QueueService.submitRating()`

### Admin Journey

1. **BookingConfirmationScreen** (`lib/screens/admin/booking_confirmation_screen.dart`)
   - Lists queues filtered by `status: 'waiting'` and `status: 'payment_pending'`
   - For `status: 'waiting'`:
     - **Approve** button → calls `manualConfirmBooking()` (sets booked + payment deadline)
     - **Reject** button → calls `rejectBooking()` with reason
   
   - For `status: 'payment_pending'`:
     - Shows payment proof image (base64 decoded)
     - **Confirm** button → calls `confirmPayment()` (sets booked/ongoing)
     - **Reject** button → calls `rejectBooking()` with reason
   
   - For `status: 'cancel_requested'`:
     - Shows cancellation reason
     - **Approve** button → calls `adminApproveCancellation()` (calc refund)
     - **Reject** button → calls `adminRejectCancellation()` (revert to booked)
   
   - For `status: 'cancelled'` (with pending refund):
     - Shows refund amount
     - Image picker for refund proof
     - **Process Refund** button → calls `processRefund()` with proof base64

2. **Admin Dashboard** (`lib/screens/admin/admin_dashboard.dart`)
   - Overview of pending requests
   - Queue filters & status-based actions

---

## Cloud Functions Setup

### Prerequisites
- Firebase CLI installed: `npm install -g firebase-tools`
- Node.js 14+ installed
- Firestore database set up
- Cloud Functions API enabled in Firebase Console

### Files

**Location:** `functions/src/index.ts` (TypeScript) or `functions/index.js` (JavaScript)

**Key Functions:**

1. **`autoCancelPaymentTimeouts`** (Scheduled, runs every minute)
   - Finds all `status: 'booked'` with `paymentDeadline` passed and no proof
   - Cancels them automatically
   - Sets `rejection_reason: "Payment timeout - bukti pembayaran tidak diunggah dalam waktu yang ditentukan"`

2. **`notifyOnQueueStatusChange`** (Firestore trigger)
   - Listens to all queue updates
   - Sends FCM notifications for:
     - Admin approval (waiting → booked)
     - Payment verified (payment_pending → ongoing)
     - Payment rejected or timeout
     - Cancellation processed

3. **`cleanupOldPaymentProofs`** (Scheduled, runs daily)
   - Removes base64 payment/refund proofs from documents older than 30 days
   - Keeps Firestore document size manageable

### Deployment Steps

```bash
# 1. Navigate to functions directory
cd functions

# 2. Install dependencies
npm install

# 3. Deploy all functions
firebase deploy --only functions

# 4. Deploy specific function
firebase deploy --only functions:autoCancelPaymentTimeouts

# 5. View logs
firebase functions:log

# 6. Set up Cloud Scheduler jobs
# In Firebase Console → Cloud Scheduler:
#   - Job 1: "auto-cancel-timeouts" → Pub/Sub topic "auto-cancel-timeouts" → Frequency: "* * * * *" (every minute)
#   - Job 2: "cleanup-old-proofs" → Pub/Sub topic "cleanup-proofs" → Frequency: "0 0 * * *" (daily at midnight)
```

### Firebase Console Setup

1. **Enable APIs:**
   - Cloud Functions
   - Cloud Firestore
   - Cloud Pub/Sub
   - Cloud Scheduler
   - Cloud Messaging

2. **Create Pub/Sub Topics:**
   - `auto-cancel-timeouts`
   - `cleanup-proofs`

3. **Create Cloud Scheduler Jobs:**
   ```
   Job 1:
   - Name: auto-cancel-payment-timeouts
   - Frequency: * * * * *
   - Timezone: UTC (or your timezone)
   - Topic: auto-cancel-timeouts
   
   Job 2:
   - Name: cleanup-old-proofs
   - Frequency: 0 0 * * *
   - Timezone: UTC
   - Topic: cleanup-proofs
   ```

---

## Testing Guide

### Unit Tests

Run tests with:
```bash
flutter test test/booking_validation_test.dart
```

**Test Coverage:**
- Date validation (cannot be before today)
- Time validation (cannot be before now on same day)
- Service selection (at least 1 required)
- Barberman selection (exactly 1 required)
- Operating hours validation
- Queue model creation
- Status transitions
- Slot blocking logic
- Payment deadline calculation (10 minutes)
- Refund calculation (90%)
- Rating validation (1-5 range)
- String conversion for enum

### Manual Testing

#### Customer Flow
1. **Create Booking:**
   - Open Appointment Screen
   - Select ≥1 service
   - Select 1 barberman
   - Select future date or today with future time
   - Check that past times/dates are disabled
   - Tap "Book" → should create with `status: 'waiting'`

2. **Wait for Admin Approval:**
   - Open My Bookings
   - See "Menunggu Konfirmasi" status
   - (Wait for admin to approve in BookingConfirmationScreen)

3. **Upload Payment Proof:**
   - Status changes to `booked` after admin approval
   - Tap "View" → navigates to PaymentScreen
   - Timer shows remaining time
   - Select image → uploads as base64
   - Status changes to `payment_pending`
   - (Wait for admin to verify)

4. **Service Complete:**
   - Admin marks as `ongoing` then `served`
   - In My Bookings, "Give Rating" button appears
   - Tap button → RatingScreen opens
   - Select rating (1-5 stars)
   - Add comment (optional)
   - Tap "Kirim Rating"

#### Admin Flow
1. **Review Pending Requests:**
   - Open BookingConfirmationScreen
   - See all `waiting` requests
   - Check booking details (customer, services, price, time)
   - Tap "Approve" to set payment deadline
   - Or tap "Reject" with reason

2. **Verify Payment:**
   - See `payment_pending` requests
   - View payment proof image (decoded from base64)
   - Tap "Confirm" if valid
   - Or tap "Reject" with reason

3. **Process Cancellation:**
   - See `cancel_requested` requests
   - Review cancellation reason
   - Tap "Approve Cancellation" → calculates refund (90%)
   - Upload refund proof image (bank transfer, etc.)
   - Tap "Process Refund" → marks as completed

#### Timeout Testing
1. **Simulate Payment Timeout:**
   - Create booking → admin approves
   - Do NOT upload proof
   - Wait 10 minutes (or modify Cloud Function to test with shorter timeout)
   - Cloud Function should auto-cancel
   - In My Bookings, status should be `cancelled`

---

## Deployment Checklist

### Pre-Deployment
- [ ] All unit tests pass: `flutter test`
- [ ] No compile errors: `flutter analyze`
- [ ] No lint warnings
- [ ] Tested all customer flows (create → pay → rate)
- [ ] Tested all admin flows (approve → verify → refund)
- [ ] Tested timeout scenario
- [ ] Firebase Emulator tested locally (optional)

### Firebase Setup
- [ ] Enable Cloud Functions API
- [ ] Enable Cloud Pub/Sub API
- [ ] Enable Cloud Scheduler API
- [ ] Create Pub/Sub topics: `auto-cancel-timeouts`, `cleanup-proofs`
- [ ] Deploy Cloud Functions: `firebase deploy --only functions`
- [ ] Create Cloud Scheduler jobs
- [ ] Enable FCM API
- [ ] Configure FCM in Flutter app (`firebase_messaging` package)

### App Deployment
- [ ] Update `pubspec.yaml` dependencies to latest stable versions
- [ ] Update app version in `pubspec.yaml` and iOS/Android build config
- [ ] Build APK: `flutter build apk --release`
- [ ] Build iOS: `flutter build ios --release`
- [ ] Test on physical device
- [ ] Submit to Play Store / App Store

### Post-Deployment
- [ ] Monitor Cloud Functions logs
- [ ] Monitor Firestore database growth
- [ ] Test timeout cancellation (wait 10+ minutes)
- [ ] Verify customer notifications arriving
- [ ] Verify admin notifications arriving
- [ ] Check that payment proofs are properly stored
- [ ] Check refund proofs storage

---

## Known Limitations & Future Improvements

### Current Limitations
1. **Payment Processing:** Manual verification only (no automated payment gateway)
2. **Refund Transfer:** Manual (no automated bank transfer)
3. **Notifications:** Basic FCM only (no email/SMS)
4. **Document Size:** Base64 images can grow large; cleanup job recommended
5. **Concurrency:** Slot blocking handles most cases but heavy load may need Firestore transactions

### Recommended Improvements
1. Integrate payment gateway (Stripe, Midtrans, etc.)
2. Add email notifications
3. Implement Firestore transaction for critical updates
4. Add queue analytics dashboard
5. Add barber's peak time preferences
6. Add customer review/reputation system
7. Add loyalty points
8. Mobile push notifications badge counter

---

## Support & Troubleshooting

### Cloud Function Not Triggering
- Check Cloud Scheduler job status in Console
- Verify Pub/Sub topic name matches
- Check function logs: `firebase functions:log`

### Payment Proof Not Saving
- Check Firestore document size limit (1 MB)
- Ensure image compression is working
- Check base64 encoding (should be valid UTF-8)

### Notifications Not Arriving
- Verify FCM tokens are saved in Firestore
- Check Firebase Console → Cloud Messaging → Credentials
- Verify app has notification permissions (Android/iOS)

### Slot Availability Issues
- Ensure `isSlotAvailable` is blocking all relevant statuses
- Check `payment_deadline` is correctly set (10 min)
- Verify timezone consistency across app and server

---

**Document Version:** 1.0  
**Last Updated:** November 26, 2025  
**Maintainer:** Development Team
