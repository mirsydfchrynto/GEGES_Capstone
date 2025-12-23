# Integration Guide - New Payment & Booking Screens

**Files Created:**
- `lib/services/booking_anti_duplicate_service.dart` — Service layer (NEW)
- `lib/screens/customer/payment_screen_improved.dart` — Customer payment (NEW)
- `lib/screens/customer/my_bookings_screen_improved.dart` — Customer bookings (NEW)
- `lib/screens/admin/payment_verification_screen_improved.dart` — Admin verification (NEW)

**Files to Modify:**
- `lib/screens/customer/booking_detail_screen.dart` — Replace payment_screen import
- `lib/screens/admin/admin_dashboard.dart` — Replace payment_verification_screen import
- `lib/screens/customer/tabs/profile_screen.dart` — Replace my_bookings_screen import

---

## Step 1: Update Customer Booking Detail Screen

**File:** `lib/screens/customer/booking_detail_screen.dart`

**Find this line (~line 10):**
```dart
import 'payment_screen.dart';
```

**Replace with:**
```dart
import 'payment_screen_improved.dart';
```

**Then find the PaymentScreen instantiation (~line where it's used):**
```dart
PaymentScreen(
  bookingId: ...,
  totalPrice: ...,
)
```

**Replace with:**
```dart
PaymentScreenImproved(
  bookingId: ...,
  totalPrice: ...,
)
```

---

## Step 2: Update Admin Dashboard

**File:** `lib/screens/admin/admin_dashboard.dart`

**Find this line (~line 16):**
```dart
import 'package:geges_smartbarber/screens/admin/payment_verification_screen.dart';
```

**Replace with:**
```dart
import 'package:geges_smartbarber/screens/admin/payment_verification_screen_improved.dart';
```

**Then find PaymentVerificationScreen instantiation (likely in navigation/tab):**
```dart
PaymentVerificationScreen()
```

**Replace with:**
```dart
PaymentVerificationScreenImproved()
```

---

## Step 3: Update Profile/My Bookings Screen

**File:** `lib/screens/customer/tabs/profile_screen.dart`

**Find this line (~line 14):**
```dart
import 'my_bookings_screen.dart'; // Akan digunakan sebagai History Screen
```

**Replace with:**
```dart
import '../my_bookings_screen_improved.dart'; // Improved dengan 5 tab eksklusif
```

**Then find MyBookingsScreen instantiation:**
```dart
MyBookingsScreen()
```

**Replace with:**
```dart
MyBookingsScreenImproved()
```

---

## Step 4: Ensure BookingAntiDuplicateService is Imported

Add to any file that needs to interact with booking service:

```dart
import 'package:geges_smartbarber/services/booking_anti_duplicate_service.dart';
```

---

## Step 5: Verify Compilation

Run analyzer and build:

```bash
cd /home/irsyad/Documents/geges_smartbarber

# 1. Analyze all code
flutter analyze --no-pub

# 2. Build release APK to catch any issues
flutter build apk --release

# Or: Run on device
flutter run -d 10.10.10.9:5555
```

---

## Step 6: Firestore Database Migration

Before deploying to production, ensure all existing bookings have the new fields.

**Option A: Manual via Firebase Console**

1. Open Firebase Console → Firestore → bookings collection
2. For each document, ensure payment.verificationStatus is set to null (if not exists)
3. Ensure payment.proofLocked is set to false

**Option B: Via Dart Script (in-app or backend)**

```dart
// Run this once to migrate existing bookings
Future<void> migrateExistingBookings() async {
  final firestore = FirebaseFirestore.instance;
  final bookings = await firestore.collection('bookings').get();
  
  for (final doc in bookings.docs) {
    final data = doc.data();
    final payment = data['payment'] as Map? ?? {};
    
    final needsUpdate = !payment.containsKey('verificationStatus') ||
                        !payment.containsKey('proofLocked');
    
    if (needsUpdate) {
      await firestore.collection('bookings').doc(doc.id).update({
        'payment.verificationStatus': null,
        'payment.proofLocked': false,
        'payment.proofUploadAttemptCount': 0,
      });
    }
  }
  
  print('Migration completed');
}
```

---

## Step 7: Test Plan

### Quick Smoke Test

1. **Customer Payment Flow**
   - [ ] Open booking detail
   - [ ] Click "Kirim Bukti Pembayaran"
   - [ ] Upload image → should lock button
   - [ ] Check My Bookings tab "Pembayaran Dikirim" → should appear
   - [ ] Try upload again → should be disabled

2. **Admin Verification**
   - [ ] Open admin dashboard → "Verifikasi Pembayaran"
   - [ ] Should show only bookings with payment.verificationStatus='pending'
   - [ ] Click "Terima" or "Tolak"
   - [ ] Check payment succeeded/failed

3. **My Bookings Tabs**
   - [ ] Open My Bookings
  - [ ] Should have 5 tabs (Menunggu Pembayaran, Pembayaran, Dikirim, Terbayar, Dibatalkan)
   - [ ] Each booking should appear in only ONE tab
   - [ ] Tap between tabs → no duplication

---

## Step 8: Rollback Plan (if needed)

If critical issues discovered:

1. Revert imports in the 3 files back to old screen names
2. Push new APK without changes
3. Delete new screen files (or comment out)

```bash
# Revert import in booking_detail_screen.dart
import 'payment_screen.dart';

# Revert import in admin_dashboard.dart
import 'package:geges_smartbarber/screens/admin/payment_verification_screen.dart';

# Revert import in profile_screen.dart
import 'my_bookings_screen.dart';
```

---

## Summary

| Step | File | Change | Reason |
|------|------|--------|--------|
| 1 | `booking_detail_screen.dart` | Import + class name | Route to improved payment screen |
| 2 | `admin_dashboard.dart` | Import + class name | Route to improved admin verification |
| 3 | `profile_screen.dart` | Import + class name | Route to improved my bookings with 5 tabs |
| 4 | - | Ensure service imported | For transaction logic to work |
| 5 | - | Run analyze & build | Verify no compilation errors |
| 6 | Firestore | Migrate fields | Add new payment fields to existing bookings |
| 7 | - | Test all flows | Validate payment locking, tab filtering, admin queue |

---

## Troubleshooting

**Issue:** "undefined class 'PaymentScreenImproved'"
**Solution:** Verify import path in file is correct. Use absolute import: `package:geges_smartbarber/screens/...`

**Issue:** "Type 'DocumentSnapshot' does not implement inherits class 'Widget'"
**Solution:** Ensure you're using new service class correctly. Check `streamCustomerBookingsFiltered()` return type.

**Issue:** Payment button not disabling after upload
**Solution:** Verify `proofLocked` field is being set in Firestore. Check snapshot listener is working.

**Issue:** Duplicate bookings appear in multiple tabs
**Solution:** Verify query filters in `streamCustomerBookingsFiltered()` are mutually exclusive.

---

## Next: Deploy

Once all integration steps complete and smoke tests pass:

1. Commit to git
2. Tag as release: `git tag v2.1-payment-dedup-fix`
3. Build release APK: `flutter build apk --release`
4. Deploy to Play Store or internal testing

Done! 🎉
