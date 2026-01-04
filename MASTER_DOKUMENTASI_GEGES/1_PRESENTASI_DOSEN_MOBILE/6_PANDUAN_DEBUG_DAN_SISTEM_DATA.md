# Panduan Teknis: Debugging, API, Token, dan Keamanan Data
**Navigasi Sistem Data untuk Pengembang Geges Smart Barber**

Dokumen ini menjelaskan asal-usul, fungsi, dan cara kerja data di balik layar aplikasi, serta panduan untuk melakukan debugging secara efektif.

---

## 1. Arsitektur Komunikasi (API & Firebase)
Aplikasi ini tidak menggunakan API REST konvensional dengan endpoint URL (seperti `https://api.example.com`). Sebagai gantinya, kami menggunakan **Firebase SDK** yang berkomunikasi melalui protokol biner **gRPC**.

*   **Asal-Usul:** Disediakan oleh Google Cloud Platform untuk sinkronisasi data real-time.
*   **Fungsi:** Menghubungkan aplikasi langsung ke database Firestore secara asinkronus (Async).
*   **Lokasi Implementasi:**
    *   Folder: `lib/services/`
    *   File Kunci: `queue_service.dart`, `barbershop_service.dart`.
*   **Cara Debug API:**
    1.  Gunakan **Debug Console** di editor Anda (VS Code/Android Studio).
    2.  Semua aktivitas data Firestore akan memicu log jika terjadi error (contoh: `FirebaseException`).
    3.  Buka **Firestore Console** di browser untuk melihat data yang masuk secara langsung.

---

## 2. Mekanisme Token (JWT)
Token adalah "KTP Digital" yang menjamin bahwa permintaan data benar-benar berasal dari pengguna yang sah.

*   **Asal-Usul:** Diterbitkan oleh **Firebase Auth** setelah pengguna berhasil melewati verifikasi email atau Google Login.
*   **Fungsi:** Digunakan sebagai header otorisasi otomatis setiap kali aplikasi membaca atau menulis ke database. Tanpa token ini, server Google akan memberikan error `Permission Denied`.
*   **Alur Kerja:**
    1.  User Login -> Dapat ID Token (JWT).
    2.  Setiap Request -> Token dikirim ke Server.
    3.  Server Google memvalidasi tanda tangan digital pada token tersebut.
*   **Cara Debug Token:**
    Cek di file `lib/services/auth_service.dart`. Anda dapat mencetak token ke konsol untuk keperluan verifikasi:
    ```dart
    final token = await user.getIdToken();
    print("TOKEN DEBUG: $token");
    ```

---

## 3. Secure Storage (Brankas Sesi)
Kita tidak boleh menyimpan informasi sensitif (seperti UID user) di tempat yang mudah diakses seperti `SharedPreferences`.

*   **Asal-Usul:** Menggunakan library `flutter_secure_storage`.
*   **Fungsi:** Menyimpan `UID` dan data sesi penting lainnya di dalam **Android Keystore** atau **iOS Keychain**. Ini adalah area memori terenkripsi hardware yang tidak bisa diintip oleh aplikasi lain.
*   **Lokasi Kode:**
    *   File: `lib/services/session_service.dart`
    *   Fungsi: `saveSession()`, `getUid()`, `clearSession()`.
*   **Penerapan Debug:**
    Jika user tiba-tiba logout sendiri, cek apakah `getUid()` mengembalikan nilai null di file ini.

---

## 4. Alur Data dan State (Bagaimana Data Bergerak)
Untuk mempermudah debugging, pahami alur data berikut:

1.  **Trigger:** User menekan tombol (misal: "Booking").
2.  **Logic:** Screen memanggil fungsi di `QueueService`.
3.  **Auth Check:** `QueueService` mengecek UID dari `AuthService` atau `SessionService`.
4.  **Network:** Firebase SDK mengirimkan data ke Cloud Firestore.
5.  **Reactive Update:** Firestore mengirim balik sinyal ke `StreamBuilder` di UI.
6.  **Update UI:** Layar berubah secara otomatis tanpa pindah halaman.

---

## 5. Panduan Praktis Debugging untuk Pemula
1.  **Cek Konsol:** Selalu perhatikan tab "Debug Console". Jika ada tulisan merah, baca baris pertama untuk mengetahui jenis errornya.
2.  **Gunakan Breakpoints:** Klik di sebelah nomor baris kodingan untuk menghentikan aplikasi di titik tersebut dan memeriksa isi variabel.
3.  **Firestore Simulator:** Di Firebase Console, gunakan "Rules Playground" untuk mengetes apakah aturan keamanan (Rules) Anda memblokir data secara tidak sengaja.
4.  **Inspect UI:** Gunakan **Flutter Inspector** (ikon kaca pembesar) untuk melihat struktur widget jika tampilan berantakan atau tidak muncul.

---

**Kesimpulan:**
Semua data di aplikasi ini terpusat pada **Firebase SDK** sebagai pengantar, **Token JWT** sebagai pengaman, dan **Secure Storage** sebagai penyimpan identitas tetap di perangkat.