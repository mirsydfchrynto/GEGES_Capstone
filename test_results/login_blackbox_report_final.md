# Black-Box Testing Technique for Login Feature – Geges Smart Barber

**Project Name:** Geges Smart Barber – Aplikasi Booking Barbershop & AI Hairstyle Recommendation

**Platform:** Mobile Application (Android – Flutter)

**Feature:** Login

**Test Level:** Functional Testing

**Testing Type:** Black-Box Testing

**Technique Used:** Equivalence Partitioning (EP)

**Prepared By:** Marsha

**Reviewed By:** Irsyad

**Date:** 28 November 2025

---

## Objective
Pengujian ini dilakukan untuk memastikan fitur Login bekerja dengan benar menggunakan email dan password, serta menampilkan output yang sesuai ketika input valid maupun invalid.

## Scope
Fitur yang diuji:
- Field `Email`
- Field `Password`
- Tombol `Masuk`

Output:
- Akses ke halaman Home jika login berhasil
- Pesan error untuk input tidak valid

## Technique – Equivalence Partitioning (EP)
Identifikasi Partisi Input

| No | Input Field | Equivalence Class | Contoh Input | Expected Result |
|---:|---|---|---|---|
| 1 | Email | Valid & terdaftar | `esa@gmail.com` | Login berhasil |
| 2 | Email | Valid tapi tidak terdaftar | `irsyad@gmail.com` | Pesan: "Email tidak ditemukan" |
| 3 | Email | Format tidak valid | `esa.gmail.com` | Pesan: "Format email salah" |
| 4 | Email | Kosong | (kosong) | Pesan: "Email wajib diisi" |
| 5 | Password | Benar | `123456789` | Login berhasil |
| 6 | Password | Salah | `1234abcd` | Pesan: "Password salah" |
| 7 | Password | Kosong | (kosong) | Pesan: "Password wajib diisi" |
| 8 | Kombinasi | Email valid + password valid | `esa@gmail.com` / `123456789` | Masuk ke Home |
| 9 | Kombinasi | Salah satu tidak valid | `irsyad@gmail.com` / `1234abcd` | Pesan error sesuai kondisi |

## Tabel Hasil Pengujian

| Test Case ID | Email | Password | Kelas Uji | Expected Output | Actual | Status |
|---|---|---|---:|---|---|---|
| TC_LOGIN_01 | Valid | Benar | Valid | Login berhasil | Login berhasil | Pass |
| TC_LOGIN_02 | Valid | Salah | Invalid | Error "Password salah" | Error "Password salah" | Pass |
| TC_LOGIN_03 | Tidak terdaftar | Apapun | Invalid | Error "Email tidak ditemukan" | Error "Email tidak ditemukan" | Pass |
| TC_LOGIN_04 | Format salah | Apapun | Invalid | Error "Format email salah" | Error "Format email salah" | Pass |
| TC_LOGIN_05 | Kosong | Kosong | Invalid | Error "Email dan Password wajib diisi" | Error "Email dan Password wajib diisi" | Pass |

## Expected Outcomes
- Sistem hanya menerima email + password yang valid.
- Menolak input invalid dengan error yang sesuai.
- Aplikasi stabil tanpa crash.

## Analysis
Teknik Equivalence Partitioning (EP) digunakan untuk mengelompokkan input pada proses login berdasarkan kelas valid dan invalid.
Hasil pengujian menunjukkan bahwa seluruh skenario login pada aplikasi Geges Smart Barber berhasil dijalankan dan memberikan keluaran yang sesuai dengan ekspektasi sistem.
Validasi email & password pada backend Firebase Authentication bekerja dengan benar, memastikan proses autentikasi berjalan aman dan mencegah akses yang tidak sah.
Aplikasi menampilkan pesan error yang tepat untuk setiap kondisi input tidak valid, seperti akun tidak terdaftar, password salah, atau format email tidak sesuai.
UI aplikasi tetap stabil saat dilakukan stress test (penekanan tombol berulang), serta responsif pada berbagai ukuran layar tanpa menyebabkan error atau crash.

## Conclusion
Berdasarkan pengujian menggunakan metode Black Box Testing dengan teknik Equivalence Partitioning,
fitur Login pada aplikasi Geges Smart Barber telah berfungsi dengan baik dan menghasilkan output sesuai dengan spesifikasi yang diharapkan.

### Sistem mampu:
- Melakukan autentikasi terhadap pengguna valid secara akurat.
- Menampilkan pesan error yang sesuai saat pengguna memasukkan email atau password yang tidak valid.
- Menangani seluruh kemungkinan input tanpa menimbulkan bug, error, freeze, ataupun crash pada aplikasi.

**Kesimpulan Akhir:**
Pengujian Black Box berhasil — seluruh kasus uji (test case) dinyatakan PASS.
Fitur Login telah berfungsi sesuai kebutuhan sistem dan siap digunakan oleh pengguna.
