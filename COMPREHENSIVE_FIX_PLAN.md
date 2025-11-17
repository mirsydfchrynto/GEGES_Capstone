# comprehensive project fix & improvement plan

**tanggal dimulai:** 17 november 2025
**status:** phase 1 selesai, phase 2-5 dalam progress

---

## phase 1: audit & initial fixes ✅ SELESAI

### apa yang sudah dikerjakan:
- [x] audit project lengkap
- [x] jalankan flutter analyze (45 issues)
- [x] jalankan flutter doctor (all good)
- [x] hapus semua print statements (3 fixes)
- [x] jalankan dart fix --apply
- [x] flutter analyze ulang (sekarang 39 issues, turun 6!)

### hasil:
- 45 issues → 39 issues (6 fixed)
- semua print statements dihapus
- deprecated methods semi-fixed oleh dart fix
- print statements di register_screen.dart dihapus

---

## phase 2: remaining fixes dari flutter analyze (39 issues)

### kategori sisa issues:

#### 1. deprecated withOpacity (info - masih banyak)
**files affected:**
- lib/screens/customer/home_screen.dart:439
- lib/screens/customer/tabs/barbershop_detail_screen.dart
- lib/screens/customer/tabs/chat_assistant_screen.dart
- lib/screens/customer/tabs/profile_screen.dart
- lib/screens/customer/tabs/stylescan_screen.dart
- lib/screens/onboarding_screen.dart
- lib/widgets/admin/queue_card.dart

**action:** cari dan ganti `withOpacity(0.xx)` dengan `withValues(alpha: xx)`
- 0.28 opacity = 0.71 alpha (1.0 - 0.28) atau use Colors.withAlpha()

#### 2. deprecated .red, .green, .blue (info)
**files affected:**
- lib/screens/customer/tabs/my_bookings_screen.dart:272,273,274
- lib/widgets/admin/queue_card.dart:286

**action:** ganti dengan proper color values atau use withValues pattern

#### 3. deprecated updateEmail() → verifyBeforeUpdateEmail() (info)
**files affected:**
- lib/services/auth_service.dart:281

**action:** update method call, perhatikan return type & behavior berbeda

#### 4. deprecated fetchSignInMethodsForEmail() (info - security issue)
**files affected:**
- lib/services/auth_service.dart:338

**action:** pertimbangkan menghapus atau gunakan alternative approach

#### 5. deprecated WillPopScope → PopScope (info)
**files affected:**
- lib/screens/customer/payment_screen.dart:565

**action:** ganti WillPopScope dengan PopScope & update parameter

#### 6. naming convention issues - camelCase (info)
**files affected:**
- lib/screens/admin/admin_dashboard.dart:35 (_auth_service)
- lib/screens/admin/admin_dashboard.dart:118 (_barbershop_service_getBarbershopSafe)
- lib/screens/admin/live_queue_screen.dart:354 (_queue_service_stream)
- lib/screens/customer/appointment_screen.dart:139 (_queue_service_createQueue)
- lib/screens/customer/payment_screen.dart:265 (_queue_service_createQueue)
- lib/widgets/admin/queue_card.dart:74 (_barbershop_service_getBarbermanSafe)

**action:** rename variables dari snake_case ke camelCase

#### 7. buildcontext across async gaps (info)
**files affected:**
- lib/screens/admin/add_manual_booking_screen.dart:160
- lib/screens/admin/admin_dashboard.dart:126
- lib/screens/admin/admin_dashboard.dart:369

**action:** tambah `if (!mounted) return;` sebelum setState/navigation

#### 8. unused imports, fields, variables
**status:** SUDAH FIX, jika ada sisa akan ditunjukkan flutter analyze

---

## phase 3: documentation & inline comments (hari ke-2 & 3)

### yang perlu didokumentasikan inline:
- [ ] home_screen.dart (466 baris - kompleks)
- [ ] appointment_screen.dart
- [ ] payment_screen.dart
- [ ] edit_profile_screen.dart
- [ ] admin_dashboard.dart
- [ ] live_queue_screen.dart
- [ ] add_manual_booking_screen.dart
- [ ] booking_confirmation_screen.dart
- [ ] queue_service.dart
- [ ] barbershop_service.dart
- [ ] barberman_service.dart
- [ ] service_service.dart
- [ ] queue_card.dart
- [ ] semua tab screens (9 files)

### dokumentasi format:
```dart
// ========================================
// [function/class name] - [deskripsi singkat]
// ========================================
// penjelasan:
//   - point 1
//   - point 2
//   - point 3
// firebase operations: [list operasi]
// return: [tipe & penjelasan]
// ========================================
```

---

## phase 4: firebase setup & configuration (hari ke-3 & 4)

### yang perlu di-setup:
- [ ] verify firebase_options.dart syntax
- [ ] verify google-services.json path (android/app/)
- [ ] verify GoogleService-Info.plist path (ios/Runner/)
- [ ] buat template .env untuk development
- [ ] buat firebase security rules guide
- [ ] buat firebase setup step-by-step untuk tim

### firebase rules yang perlu documented:
- firestore collection rules (users, queues, bookings, etc)
- cloud storage rules (payment screenshots, etc)
- authentication security

---

## phase 5: testing & optimization (hari ke-4 & 5)

### unit tests:
- [ ] test models serialization/deserialization
- [ ] test auth_service methods
- [ ] test queue_service operations
- [ ] test data validation

### widget tests:
- [ ] test login form validation
- [ ] test register form validation
- [ ] test appointment screen date picker
- [ ] test payment screen image picker

### integration tests:
- [ ] test full auth flow (register → login)
- [ ] test booking flow (search → select → pay)
- [ ] test admin dashboard (real-time updates)

### optimization:
- [ ] review widget rebuilds (unnecessary rebuilds?)
- [ ] check image loading performance (cached_network_image?)
- [ ] check firestore query efficiency
- [ ] check firebase auth persistence

---

## phase 6: deployment preparation (minggu ke-2)

### android (apk/aab):
- [ ] update build.gradle (sign release)
- [ ] create keystore
- [ ] build apk release
- [ ] build aab (for play store)
- [ ] update version code & name

### ios (ipa):
- [ ] update build version
- [ ] create signing certificates
- [ ] build ipa for app store
- [ ] setup provisioning profiles

### play store:
- [ ] create google play console project
- [ ] prepare store listing (description, screenshots)
- [ ] upload aab
- [ ] setup privacy policy
- [ ] setup terms of service

### app store:
- [ ] create app store connect project
- [ ] prepare store listing
- [ ] upload ipa
- [ ] setup privacy policy

---

## quick reference: fixes per file

### lib/main.dart ✅
- [x] hapus print statements

### lib/screens/register_screen.dart ✅
- [x] hapus print statements

### lib/screens/admin/add_manual_booking_screen.dart
- [ ] fix buildcontext across async gaps line 160

### lib/screens/admin/admin_dashboard.dart
- [ ] rename _auth_service → _authService
- [ ] rename _barbershop_service_getBarbershopSafe
- [ ] fix buildcontext across async gaps line 126, 369
- [ ] ganti withOpacity jika ada sisa

### lib/screens/admin/live_queue_screen.dart
- [ ] rename _queue_service_stream

### lib/screens/customer/appointment_screen.dart
- [ ] rename _queue_service_createQueue

### lib/screens/customer/home_screen.dart
- [ ] ganti withOpacity (line 439)

### lib/screens/customer/payment_screen.dart
- [ ] rename _queue_service_createQueue
- [ ] ganti WillPopScope → PopScope

### lib/screens/customer/tabs/barbershop_detail_screen.dart
- [ ] ganti withOpacity jika ada

### lib/screens/customer/tabs/chat_assistant_screen.dart
- [ ] ganti withOpacity jika ada

### lib/screens/customer/tabs/my_bookings_screen.dart
- [ ] ganti .red, .green, .blue dengan proper colors

### lib/screens/customer/tabs/profile_screen.dart
- [ ] ganti withOpacity jika ada

### lib/screens/customer/tabs/stylescan_screen.dart
- [ ] ganti withOpacity jika ada

### lib/screens/onboarding_screen.dart
- [ ] ganti withOpacity jika ada

### lib/services/auth_service.dart
- [ ] ganti updateEmail → verifyBeforeUpdateEmail
- [ ] handle fetchSignInMethodsForEmail deprecated

### lib/widgets/admin/queue_card.dart
- [ ] rename _barbershop_service_getBarbermanSafe
- [ ] ganti .red, .green, .blue
- [ ] ganti withOpacity jika ada

---

## estimated timeline

- **hari 1:** audit + initial fixes (SELESAI ✅)
- **hari 2:** phase 2 remaining fixes
- **hari 3:** documentation inline 
- **hari 4:** firebase setup & guide
- **hari 5:** unit & widget tests
- **minggu 2:** integration tests + deployment prep

---

## commitment & notes

ini adalah rencana komprehensif untuk membuat aplikasi ini **production-ready** dengan:
- ✅ zero lint/analyze warnings
- ✅ dokumentasi lengkap & ramah pemula
- ✅ firebase setup guide untuk tim
- ✅ proper error handling di semua screens
- ✅ unit + widget + integration tests
- ✅ deployment guide untuk play store & app store

kami akan proceed langkah demi langkah, systematically, dan dokumentasikan setiap progress.

