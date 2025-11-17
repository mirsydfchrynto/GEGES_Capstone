# findings report - flutter analyze results

**tanggal:** 17 november 2025
**total issues:** 45
**critical:** 0
**warning:** 8
**info:** 37

---

## ringkasan issues

### kategori issues

#### 1. print statements (info - 3 issues)
- `lib/main.dart:41,43` - avoid_print
- `lib/screens/register_screen.dart:526,534` - avoid_print

**solusi:** ganti dengan logging package atau hapus di production

#### 2. unused imports (warning - 2 issues)
- `lib/screens/admin/add_manual_booking_screen.dart:3` - cloud_firestore
- `lib/screens/admin/admin_dashboard.dart:9` - barberman.dart

**solusi:** hapus import yang tidak dipakai

#### 3. unused fields (warning - 3 issues)
- `add_manual_booking_screen.dart:33,36,38,39` - kLightText, _queueService, _barbermanService, _authService
- tidak digunakan dalam kode

**solusi:** hapus fields atau gunakan

#### 4. deprecated methods (info - 6 issues)
- `withOpacity()` diubah menjadi `withValues()` (flutter 3.22+)
- `updateEmail()` diubah menjadi `verifyBeforeUpdateEmail()`
- `fetchSignInMethodsForEmail()` deprecated untuk security
- `WillPopScope` diubah menjadi `PopScope`

**solusi:** update semua calls ke method baru

#### 5. naming convention (info - 5 issues)
- `_auth_service` harus `_authService` (lowerCamelCase)
- `_queue_service_stream`, `_queue_service_isSlotAvailable_impl` harus camelCase
- `_queue_service_createQueue` harus camelCase

**solusi:** rename variables ke camelCase

#### 6. buildcontext across async gaps (info - 3 issues)
- `add_manual_booking_screen.dart:160`
- `admin_dashboard.dart:126,369`

**solusi:** tambah `mounted` check sebelum setState/navigation

#### 7. dead code (warning - 2 issues)
- `home_screen.dart:431:52` - dead code
- `home_screen.dart:431:55` - dead null-aware expression

**solusi:** hapus dead code atau refactor logic

#### 8. deprecated member use
- banyak `.red`, `.green`, `.blue` dari Color
- `WillPopScope` di `payment_screen.dart:565`

**solusi:** ganti dengan `.withValues()` pattern

#### 9. unused local variables (warning)
- `admin_dashboard.dart:219` - brown10
- `queue_card.dart:280` - isServed

**solusi:** hapus atau gunakan

---

## detailed fixes per file

### 1. lib/main.dart
```
issues: 2 print statements (info)
fix: ganti print dengan logger atau hapus
```

### 2. lib/screens/admin/add_manual_booking_screen.dart
```
issues: 
  - unused import cloud_firestore
  - unused fields: kLightText, _queueService, _barbermanService, _authService
  - buildcontext across async gaps (line 160)
fix:
  - hapus import cloud_firestore
  - hapus atau gunakan fields
  - tambah mounted check
```

### 3. lib/screens/admin/admin_dashboard.dart
```
issues:
  - unused import barberman
  - unused field _currentAdminData
  - naming: _auth_service, _barbershop_service_getBarbershopSafe
  - buildcontext across async gaps (line 126, 369)
  - unused local variable brown10
  - deprecated withOpacity()
fix:
  - hapus import
  - hapus field atau gunakan
  - rename ke camelCase
  - tambah mounted check
  - hapus atau gunakan variable
  - ganti withOpacity dengan withValues()
```

### 4. lib/screens/admin/live_queue_screen.dart
```
issues:
  - naming: _queue_service_stream, _queue_service_isSlotAvailable_impl
  - deprecated withOpacity()
fix:
  - rename ke camelCase
  - ganti withOpacity()
```

### 5. lib/screens/customer/appointment_screen.dart
```
issues:
  - naming: _queue_service_createQueue
  - deprecated withOpacity()
fix:
  - rename ke camelCase
  - ganti withOpacity()
```

### 6. lib/screens/customer/home_screen.dart
```
issues:
  - dead code line 431
  - dead null-aware expression line 431
  - deprecated withOpacity()
fix:
  - hapus dead code
  - ganti withOpacity()
```

### 7. lib/screens/customer/payment_screen.dart
```
issues:
  - naming: _queue_service_createQueue
  - deprecated withOpacity()
  - deprecated WillPopScope
fix:
  - rename ke camelCase
  - ganti withOpacity()
  - ganti WillPopScope dengan PopScope
```

### 8. lib/screens/customer/tabs/barbershop_detail_screen.dart
### 9. lib/screens/customer/tabs/chat_assistant_screen.dart
### 10. lib/screens/customer/tabs/my_bookings_screen.dart
### 11. lib/screens/customer/tabs/profile_screen.dart
### 12. lib/screens/customer/tabs/stylescan_screen.dart
### 13. lib/screens/onboarding_screen.dart
```
issues:
  - deprecated withOpacity() (semua file)
  - deprecated .red, .green, .blue di my_bookings_screen.dart
fix:
  - ganti semua withOpacity() dengan withValues()
  - ganti .red/.green/.blue dengan proper color values
```

### 14. lib/services/auth_service.dart
```
issues:
  - deprecated updateEmail() -> verifyBeforeUpdateEmail()
  - deprecated fetchSignInMethodsForEmail()
fix:
  - ganti method calls
  - pertimbangkan security implications
```

### 15. lib/widgets/admin/queue_card.dart
```
issues:
  - naming: _barbershop_service_getBarbermanSafe
  - deprecated withOpacity()
  - deprecated .red, .green, .blue
  - unused local variable isServed
fix:
  - rename ke camelCase
  - ganti withOpacity()
  - ganti color methods
  - hapus atau gunakan variable
```

---

## prioritas fixes

### hari 1 - CRITICAL (easy wins)
1. [ ] hapus all print statements (5 menit)
2. [ ] hapus all unused imports (5 menit)
3. [ ] hapus all unused fields & variables (10 menit)
4. [ ] ganti all withOpacity() dengan withValues() (15 menit)
5. [ ] ganti WillPopScope dengan PopScope (5 menit)
6. [ ] fix naming convention: camelCase (10 menit)
7. [ ] hapus dead code (5 menit)

### hari 2 - HIGH (requires review)
1. [ ] fix buildcontext across async gaps dengan mounted check (20 menit)
2. [ ] fix deprecated firebase methods (updateEmail, fetchSignInMethodsForEmail) (15 menit)
3. [ ] fix deprecated color methods (.red, .green, .blue) (10 menit)

### hari 3 - MEDIUM (add missing features)
1. [ ] add proper error handling ke async functions (30 menit)
2. [ ] add logging untuk replace print statements (15 menit)
3. [ ] add loading states ke semua async operations (30 menit)

---

## tools yang bisa dipakai

### untuk auto-fix beberapa issues:
```bash
# fix all auto-fixable issues
dart fix --apply

# atau fix spesifik
dart fix lib/screens/admin/add_manual_booking_screen.dart --apply
```

### untuk lint strictness:
```bash
# check dengan strict mode
flutter analyze --fatal-infos
```

---

## next steps

1. update audit report dengan findings ini
2. mulai fix dari priority 1 (hari 1)
3. jalankan flutter analyze setelah setiap batch fix
4. commit changes dengan clear messages
5. track progress di todo list

