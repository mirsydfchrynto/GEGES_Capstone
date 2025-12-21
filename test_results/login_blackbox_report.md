# BLACK-BOX TESTING – FITUR LOGIN

**Project Name:** Geges Smart Barber – Aplikasi Booking Barbershop & AI Hairstyle Recommendation

**Platform:** Mobile Application (Android – Flutter)

**Feature:** Login (email & password)

**Test Level:** Functional Testing

**Testing Type:** Black-Box Testing

**Technique Used:** Equivalence Partitioning (EP)

**Prepared By:** Marsha

**Reviewed By:** Irsyad

**Date:** 05 Desember 2025

---

## Objective
Pengujian ini memastikan fitur Login bekerja sesuai kebutuhan fungsional: memverifikasi validasi input, perilaku saat kredensial benar/salah, dan navigasi berdasarkan role pengguna.

## Scope
Fitur yang diuji:
- Field `Email`
- Field `Password`
- Tombol `Masuk`

Output yang diharapkan:
- Navigasi ke halaman utama (Home / AdminDashboard) jika login berhasil
- Pesan error atau validasi jika input tidak sesuai atau terjadi kegagalan autentikasi

## Equivalence Partitioning (EP)
| No | Input Field | Equivalence Class | Contoh Input | Expected Result |
|---:|---|---|---|---|
| 1 | Email | Valid & terdaftar | esa@gmail.com | Login berhasil (service returns {success:true, role: ...}) |
| 2 | Email | Valid tapi tidak terdaftar | irsyad@gmail.com | Error: FirebaseAuthException (user-not-found) — UI shows friendly message |
| 3 | Email | Format tidak valid | esa.gmail.com | Error: "Format email salah" (UI validation) |
| 4 | Email | Kosong | (kosong) | Error: "Email wajib diisi" (UI validation) |
| 5 | Password | Benar | 123456789 | Login berhasil |
| 6 | Password | Salah | 1234abcd | Error: FirebaseAuthException (wrong-password) — UI shows friendly message |
| 7 | Password | Kosong | (kosong) | Error: "Password wajib diisi" (UI validation) |
| 8 | Kombinasi | Email valid + password valid | esa@gmail.com / 123456789 | Masuk ke Home atau AdminDashboard (berdasarkan role) |
| 9 | Kombinasi | Salah satu tidak valid | irsyad@gmail.com / 1234abcd | Pesan error sesuai kondisi |

> Catatan: `AuthService.signIn()` mengembalikan `{'success': false, 'message': e.message}` untuk `FirebaseAuthException`, dan `{'success': false,'message':'Data pengguna tidak ditemukan.'}` jika dokumen Firestore pengguna tidak ada.

## Rekomendasi Penyesuaian Dokumen
- Jika Anda ingin menguji pesan error secara presisi (teks persis), sebaiknya `AuthService` memetakan `FirebaseAuthException.code` ke pesan lokal (contoh: 'user-not-found' → 'Email tidak ditemukan.'). Saat ini `AuthService` meneruskan `e.message`.
- Validasi input yang bersifat UI (kosong/format) sebaiknya diuji menggunakan widget/integration tests.

## Rencana Test Case (disesuaikan dengan `AuthService` behavior)
| ID | Skenario Uji | Input | Expected (behavior) |
|---|---|---|---|
| TC-BB-01 | Empty fields | Email='', Password='' | UI validation: show "Email dan Password wajib diisi" (no network call) |
| TC-BB-02 | Invalid email format | Email='esa.gmail.com' | UI validation: show "Format email salah" |
| TC-BB-03 | Email not registered | valid email but not registered | `AuthService` returns success:false with FirebaseAuthException (user-not-found) → UI shows friendly error |
| TC-BB-04 | Wrong password | existing email + wrong password | `AuthService` returns success:false with FirebaseAuthException (wrong-password) → UI shows friendly error |
| TC-BB-05 | Missing Firestore doc | auth ok but no user doc | `AuthService` returns {'success':false,'message':'Data pengguna tidak ditemukan.'} → UI shows that exact message |
| TC-BB-06 | Login success - customer | valid creds (customer) | `AuthService` returns {'success':true,'role':'customer'} → App navigates to HomeScreen |
| TC-BB-07 | Login success - admin | valid creds (admin_owner) | `AuthService` returns {'success':true,'role':'admin_owner'} → App navigates to AdminDashboard |
| TC-BB-08 | Network error / timeout | simulate network failure | `AuthService` returns success:false; UI shows friendly network error |

## Existing Test Coverage
- Unit tests `test/auth_service_test.dart` cover several service-level cases (auth failure, success with role customer/admin, missing Firestore doc). Local run: `flutter test test/auth_service_test.dart` → **All tests passed**.

## Additional Recommended Tests
- Widget / Integration tests for:
  - UI validation behaviors (TC-BB-01, TC-BB-02)
  - Navigation after successful login (TC-BB-06 / TC-BB-07)
  - Display of friendly error messages for network errors

## Suggested Implementation Improvement (optional)
Map `FirebaseAuthException.code` → localized messages inside `AuthService.signIn()` to make black-box assertions on message text deterministic. Example mapping:

- `user-not-found` → `Email tidak ditemukan.`
- `wrong-password` → `Password salah.`
- `invalid-email` → `Format email salah.`
- default → `e.message` (fallback)

## Conclusion
- Dokumen Black-Box ini sudah disesuaikan dengan ekspektasi dan perilaku `AuthService`.
- Unit tests saat ini sudah menguji beberapa kondisi penting dan lulus.
- Rekomendasi: buat widget/integration tests dan/atau tambahkan message-mapping di `AuthService` jika Anda ingin assertion berbasis teks yang konsisten.

---

Jika Anda ingin, saya bisa:
- Update `AuthService.signIn()` untuk menambahkan mapping pesan (bahasa Indonesia), lalu menyesuaikan/menambah unit tests; atau
- Buat widget/integration tests otomatis yang menjalankan skenario black-box pada UI (input + navigation).

Pilih tindakan selanjutnya yang Anda inginkan.