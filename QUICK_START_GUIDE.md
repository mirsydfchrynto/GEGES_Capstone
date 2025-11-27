# ⚡ Quick Start Guide - Booking System

**For:** GEGES SmartBarber Development Team  
**Date:** November 26, 2025  
**Status:** Implementation Complete ✅

---

## 🎯 What's New

Your booking system is now **100% complete** with:
- ✅ Full booking lifecycle (request → approval → payment → service → rating)
- ✅ 10-minute payment deadline enforcement
- ✅ Automated payment timeout cancellation (Cloud Function)
- ✅ Customer cancellation & refund flows (90% refund)
- ✅ 5-star rating system
- ✅ Comprehensive testing (13 test cases)
- ✅ Complete documentation

---

## 📍 Where to Start

### 1. **Review Core Files** (10 minutes)
```
lib/models/queue.dart           → Data model with all fields
lib/services/queue_service.dart → Business logic (all methods)
BOOKING_IMPLEMENTATION_COMPLETE.md → Full technical documentation
```

### 2. **Test Locally** (15 minutes)
```bash
# Run all tests
flutter test test/booking_validation_test.dart

# Should see: ✓ 13 tests passed
```

### 3. **Set Up Cloud Functions** (20 minutes)
```bash
cd functions
npm install
firebase deploy --only functions

# Then create Cloud Scheduler jobs in Firebase Console:
# - Job 1: "auto-cancel-payment-timeouts" (every minute)
# - Job 2: "cleanup-old-proofs" (daily at midnight)
```

### 4. **Deploy to Firebase** (5 minutes)
```bash
flutter clean
flutter pub get
flutter build apk --release
# Deploy via Play Store/TestFlight
```

---

## 🧪 Manual Testing Checklist

### Customer Flow (5 minutes)
- [ ] Open Appointment Screen
- [ ] Select 1+ services
- [ ] Select 1 barberman
- [ ] Select date (try past date → should disable)
- [ ] Select time (try past time → should disable)
- [ ] Tap "Book" → should create with "Menunggu Konfirmasi"
- [ ] Go to My Bookings → see waiting status

### Admin Approval (2 minutes)
- [ ] Open BookingConfirmationScreen
- [ ] See "waiting" request
- [ ] Tap "Approve" → should set 10-min deadline
- [ ] Check Firestore doc: `status: 'booked'`, `requestStatus: 'approved'`

### Payment Upload (3 minutes)
- [ ] Customer goes to My Bookings
- [ ] Tap "View" button (now shows for booked)
- [ ] PaymentScreen opens with timer
- [ ] Select image → tap "Kirim Bukti"
- [ ] Status should change to "payment_pending"
- [ ] Check Firestore: `status: 'payment_pending'`, `paymentProofBase64` populated

### Admin Verification (2 minutes)
- [ ] Admin sees "payment_pending" request
- [ ] Taps to view image (base64 decoded)
- [ ] Taps "Confirm Payment"
- [ ] Status changes to "booked" or "ongoing"

### Rating (2 minutes)
- [ ] After service marked "served"
- [ ] In My Bookings, "Give Rating" button appears
- [ ] Tap button → RatingScreen opens
- [ ] Select 3 stars
- [ ] Add comment
- [ ] Tap "Kirim Rating"
- [ ] Check Firestore: `rating: 3.0`, `ratingComment: "..."`, `ratedAt: <timestamp>`

**Total Test Time: ~15 minutes**

---

## 📋 File Overview

### Model
- **lib/models/queue.dart**
  - New statuses: `payment_pending`, `cancel_requested`
  - New fields: payment deadline, refund data, rating
  - New methods: `copyWith` updated

### Service
- **lib/services/queue_service.dart**
  - `submitRating()` - customer rates
  - `getBarbermanAverageRating()` - get rating
  - `requestCancellation()` - customer cancel
  - `adminApproveCancellation()` - 90% refund calc
  - `adminRejectCancellation()` - revert
  - `processRefund()` - upload refund proof

### Screens
- **lib/screens/customer/rating_screen.dart** (NEW)
  - 5-star picker
  - Comment textbox
  - Submits rating to Firestore
  
- **lib/screens/customer/payment_screen.dart** (UPDATED)
  - Loads queue by `orderId`
  - Timer: counts down from `paymentDeadline`
  - Base64 image upload
  - Sets `status: 'payment_pending'`

- **lib/screens/customer/tabs/my_bookings_screen.dart** (UPDATED)
  - Shows "Give Rating" for served
  - Shows "View" for booked/payment_pending
  - Can request cancellation

- **lib/screens/admin/booking_confirmation_screen.dart** (UPDATED)
  - Shows cancellation requests
  - Approve/Reject cancellation
  - Process refund with image upload

### Testing
- **test/booking_validation_test.dart** (NEW)
  - 13 comprehensive test cases
  - Validates all business rules

### Cloud Functions
- **functions/src/index.ts** (NEW)
  - `autoCancelPaymentTimeouts` - every 1 minute
  - `notifyOnQueueStatusChange` - FCM notifications
  - `cleanupOldPaymentProofs` - daily cleanup

### Documentation
- **BOOKING_IMPLEMENTATION_COMPLETE.md** - 300+ line technical guide
- **IMPLEMENTATION_SUMMARY.md** - feature summary
- **QUICK_START_GUIDE.md** - this file

---

## 🔑 Key Features Explained

### 1. Payment Window (10 minutes)
```
Admin approves → paymentDeadline = now + 10 minutes
Customer has 10 min to upload proof
After 10 min: Cloud Function auto-cancels if no proof
```

### 2. Slot Protection
```
Blocked statuses: 'booked', 'payment_pending', 'ongoing'
Customer cannot book same slot while payment pending
Protects against double-booking during payment window
```

### 3. Refund Calculation
```
Customer cancels with approved booking
Refund = totalPrice * 0.9 (90% to customer, 10% admin fee)
Admin uploads refund proof (bank transfer, etc.)
Proof stored as base64 in Firestore
```

### 4. Rating After Service
```
Only available when status == 'served'
1-5 star rating with optional comment
Stored in same Queue document
Can retrieve average rating for each barber
```

### 5. Auto-Cancel Timeout
```
Cloud Scheduler runs every minute
Checks: status='booked' AND paymentDeadline < now AND no proof
Auto-cancels with reason: "Payment timeout"
Customer notified via FCM
```

---

## 🐛 Debugging Tips

### View Firestore Doc Structure
```
Firebase Console → Firestore → queues → click any document
Look for: status, requestStatus, paymentDeadline, rating, etc.
```

### Check Cloud Function Logs
```bash
firebase functions:log
# Look for: autoCancelPaymentTimeouts, notifyOnQueueStatusChange
```

### Test Auto-Cancel Locally
```dart
// In booking_confirmation_screen.dart (temporary)
// Modify paymentDeadline to past time for testing
await _queueService.manualConfirmBooking(
  queueId,
  // paymentDeadline will be set to now + 10 min
  // Manually update in Firestore to past time for testing
);
```

### Check Status Colors
```
waiting: orangeAccent
payment_pending: orange (#FFA726)
booked: blue
ongoing: blue
cancel_requested: red (#EF5350)
served: green
cancelled: red
```

---

## 📊 Implementation Stats

| Metric | Value |
|--------|-------|
| Total Files Modified | 8 files |
| New Files Created | 3 files |
| New Statuses Added | 2 (payment_pending, cancel_requested) |
| New Fields Added | 15+ fields |
| New Methods Added | 7 service methods |
| Test Cases | 13 scenarios |
| Lines of Documentation | 300+ lines |
| Cloud Functions | 3 functions |
| Estimated Testing Time | 15 minutes |
| Estimated Deploy Time | 30 minutes |

---

## ✨ Quality Checklist

- ✅ No compile errors
- ✅ No critical lint warnings
- ✅ All unit tests pass
- ✅ Database fields documented
- ✅ Service methods documented
- ✅ Screens documented
- ✅ Cloud Functions documented
- ✅ Testing guide provided
- ✅ Deployment checklist included
- ✅ Quick start guide ready

---

## 🚀 Deployment Order

1. **Deploy Cloud Functions**
   ```bash
   firebase deploy --only functions
   ```

2. **Create Scheduler Jobs**
   - In Firebase Console → Cloud Scheduler
   - Create 2 jobs as described

3. **Run Tests**
   ```bash
   flutter test test/booking_validation_test.dart
   ```

4. **Manual Test on Device**
   - Follow testing checklist above

5. **Build & Deploy**
   ```bash
   flutter build apk --release
   flutter build ios --release
   ```

6. **Monitor Logs**
   ```bash
   firebase functions:log --lines 100
   ```

---

## 📞 Questions?

Refer to:
1. **BOOKING_IMPLEMENTATION_COMPLETE.md** - Complete technical reference
2. **lib/services/queue_service.dart** - Inline comments in each method
3. **test/booking_validation_test.dart** - Example test cases
4. **functions/src/index.ts** - Cloud Function examples

---

## 🎉 You're Ready!

All the hard work is done. The booking system is:
- ✅ Fully implemented
- ✅ Well tested
- ✅ Thoroughly documented
- ✅ Ready to deploy

**Next step:** Follow the "Quick Start" section above (30 minutes total)

---

**Happy coding! 🚀**

*Last Updated: November 26, 2025*  
*Implementation Status: Complete ✅*
