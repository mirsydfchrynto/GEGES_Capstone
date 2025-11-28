# GEGES SmartBarber: Quick Command Reference

**Quick access untuk common commands & procedures**

---

## 🚀 Getting Started (First Time)

```bash
# 1. Navigate to project
cd /home/irsyad/Documents/geges_smartbarber

# 2. Get dependencies
flutter pub get

# 3. Run on device
flutter run -d 10.10.10.9:5555  # atau device ID Anda

# 4. Check for errors
flutter analyze
```

---

## 🧪 Testing Commands

### In-App Notifications Test
```bash
# 1. Run app on 2 devices:
flutter run -d [DEVICE_1]
flutter run -d [DEVICE_2]

# 2. On Device 2, go to:
#    Admin Dashboard → Kirim Notifikasi

# 3. On Device 1, watch Notifications screen
#    Should see notification appear in real-time
```

### Payment Flow Test
```bash
# 1. Customer: Create new booking
# 2. Admin: Approve booking via Admin Dashboard → Verify Booking
# 3. Customer: See countdown timer on booking detail
# 4. Customer: Upload payment proof (screenshot atau foto)
# 5. Admin: Verify payment via Admin Dashboard → Verify Payment
# 6. Verify booking status = "booked"
```

### Push Notification Test
```bash
# Setup (one time):
cd scripts/fcm_sender
npm install

# Create .env file:
cp .env.example .env
# Fill GOOGLE_APPLICATION_CREDENTIALS with path to service account JSON

# Test 1 - Manual push:
node send_push.js --type=personal --uid=[USER_UID] --title="Test" --body="Hello"

# Test 2 - Broadcast push:
node send_push.js --type=broadcast --title="Promo" --body="Diskon 50%"

# Test 3 - Process pending requests:
node send_push.js --processPending
```

---

## 🛠️ Development Commands

### Code Analysis
```bash
# Check for errors/warnings
flutter analyze --no-pub

# Format code
dart format lib/

# Get package updates
flutter pub upgrade
```

### Database Inspection
```bash
# View Firestore data:
# 1. Open Firebase Console: https://console.firebase.google.com
# 2. Select project
# 3. Go to Firestore Database
# 4. Browse collections:
#    - users/{uid}
#    - notifications/{doc_id}
#    - push_requests/{doc_id}
#    - queues/{id}
```

### Logs & Debugging
```bash
# Clear and rebuild app
flutter clean
flutter pub get
flutter run -d [DEVICE] --verbose

# View device logs (Android)
adb logcat | grep -i flutter

# View device logs (iOS)
# Open Xcode → Device Logs
```

---

## 📱 App Navigation (User Perspective)

### Admin Flow
```
Admin Dashboard
  ├── Verify Booking (admin_dashboard.dart → payment_verification_screen.dart)
  │   ├── See awaiting_payment bookings
  │   ├── View proof preview
  │   ├── Tap Confirm/Reject
  │   └── Notification auto-sent
  │
  ├── Kirim Notifikasi (send_notification_screen.dart)
  │   ├── Search customer by name
  │   ├── Type notification
  │   ├── Check "Broadcast" if needed
  │   ├── Check "Kirim push" if server enabled
  │   └── Tap Kirim
  │
  └── Other menus...
```

### Customer Flow
```
Home / Dashboard
  ├── My Bookings (see all bookings)
  │
  ├── Booking Detail (booking_detail_screen.dart)
  │   ├── If status = "waiting"
  │   │   └── Wait for admin approval
  │   │
  │   ├── If status = "awaiting_payment"
  │   │   ├── See countdown timer
  │   │   ├── Upload payment proof
  │   │   ├── See proof preview
  │   │   └── Wait for admin verification
  │   │
  │   ├── If status = "booked"
  │   │   ├── Confirmed (show booking date/time)
  │   │   └── Ready for appointment
  │   │
  │   └── If status = "served" or "canceled"
  │       └── View past booking
  │
  ├── Notifications (notifications_screen.dart)
  │   ├── List all notifications
  │   ├── Tap notification → Go to booking
  │   └── Dismiss/mark read
  │
  └── Other menus...
```

---

## 🔄 Firestore Collections & Paths

### Users
```firestore
users/{uid}
├── name: String
├── email: String
├── role: String (customer/admin_owner)
├── phone_number: String
├── fcm_token: String
├── fcm_token_updated_at: Timestamp
└── created_at: Timestamp
```

### Queues (Bookings)
```firestore
queues/{queue_id}
├── customer_uid: String
├── barber_uid: String
├── service_id: String
├── status: String (waiting/awaiting_payment/booked/ongoing/served/canceled)
├── scheduled_time: Timestamp
├── payment_proof: String (base64 image)
├── payment_verified_by: String (admin uid)
├── payment_verified_at: Timestamp
├── notes: String
├── created_at: Timestamp
├── updated_at: Timestamp
└── expires_at: Timestamp (for auto-cancel)
```

### Notifications
```firestore
notifications/{doc_id}
├── title: String
├── body: String
├── user_id: String (empty if broadcast)
├── broadcast: Boolean
├── queue_id: String (optional)
├── created_at: Timestamp
├── delivered: Boolean
├── delivered_at: Timestamp
└── read: Boolean
```

### Push Requests
```firestore
push_requests/{doc_id}
├── title: String
├── body: String
├── user_id: String (empty if broadcast)
├── broadcast: Boolean
├── queue_id: String (optional)
├── created_at: Timestamp
├── processed: Boolean
├── processed_at: Timestamp
└── result: String
```

---

## 🔑 Important File Locations

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point (init notifications) |
| `lib/services/notification_service.dart` | Core notification logic |
| `lib/services/app_navigator.dart` | Global navigator key |
| `lib/services/queue_service.dart` | Booking logic |
| `lib/screens/admin/admin_dashboard.dart` | Admin home screen |
| `lib/screens/admin/send_notification_screen.dart` | Send notification UI |
| `lib/screens/admin/payment_verification_screen.dart` | Payment verify UI |
| `lib/screens/customer/booking_detail_screen.dart` | Booking detail with countdown |
| `lib/screens/customer/notifications_screen.dart` | Notification list |
| `scripts/fcm_sender/send_push.js` | Push CLI script |
| `scripts/fcm_sender/server.js` | Express server for push |
| `pubspec.yaml` | Dependencies |

---

## ⚙️ Common Configuration

### Firebase Messaging (FCM)
```dart
// Automatically initialized in notification_service.dart
// Token automatically saved to users/{uid}.fcm_token
// No additional setup needed
```

### Local Notifications
```dart
// Automatically initialized in notification_service.dart
// Permissions requested automatically
// No additional setup needed
```

### Firestore Rules
```javascript
// Check firebase.rules in your project
// Should allow:
// - customers: read notifications, read queues, write payment_proof
// - admins: write notifications, read/update queues
// - service account: full access (for server)
```

---

## 🐛 Troubleshooting Quick Fixes

| Issue | Solution |
|-------|----------|
| Notifications not appearing | Check user role in Firestore users/{uid} |
| | Check notification listener not blocked by rules |
| | Restart app after role change |
| Countdown timer not showing | Refresh booking detail screen |
| Payment proof not uploading | Check image size (should be < 5MB) |
| | Check Firestore rules allow write to queues |
| Push not received | Check fcm_token exists in users/{uid} |
| | Check Firebase Cloud Messaging enabled |
| | Ensure app has notification permission |
| Server script error | Run `npm install` first |
| | Set .env variables correctly |
| | Check service account JSON permissions |

---

## 📊 Monitoring & Health Check

```bash
# Flutter:
flutter analyze

# Firestore:
# Check Firebase Console for error logs

# Node Server:
curl http://localhost:4000/health
# Should respond: {"status":"ok"}

# Check pending push requests:
# Go to Firebase Console → push_requests collection
# Count docs where processed = false
```

---

## 🚀 Deployment Checklist

Before going to production:

- [ ] All tests pass
- [ ] Firestore rules configured securely
- [ ] Service account JSON stored securely (not in git)
- [ ] .env file not committed (.gitignore includes it)
- [ ] FCM enabled in Firebase Console
- [ ] App signed (for Android/iOS)
- [ ] Server helper hosted (or scheduled via cron)
- [ ] Monitoring setup (logs, error tracking)
- [ ] Backup strategy defined
- [ ] Rollback plan defined

---

## 📞 Support Contacts

**For Documentation:**
- See `SETUP_NOTIFICATIONS_PAYMENTS_GUIDE.md` for detailed explanations
- See `SETUP_OPERATIONS_CHECKLIST.md` for step-by-step setup
- See `FILE_REFERENCE.md` for architecture & schemas

**For Code Issues:**
- Run `flutter analyze`
- Check `flutter run --verbose` output
- Check Firebase Console logs

**For Firebase Setup:**
- https://firebase.google.com/docs/firestore
- https://firebase.google.com/docs/cloud-messaging
- Firebase Console: https://console.firebase.google.com

---

## 🎯 Quick Stats

| Metric | Value |
|--------|-------|
| Implementation Status | ✅ 100% Complete |
| Code Compile Status | ✅ Clean (no errors/warnings) |
| Notification Service | ✅ Integrated |
| Payment Verification | ✅ Integrated |
| Push Notifications | ✅ Optional (ready) |
| Documentation | ✅ Complete (4 files) |
| Test Coverage | ✅ Manual testing procedures provided |

---

**Last Updated:** November 28, 2025  
**Version:** 1.0

Use this as quick reference. For detailed info, see main documentation files.

Senang membantu! 🎉
