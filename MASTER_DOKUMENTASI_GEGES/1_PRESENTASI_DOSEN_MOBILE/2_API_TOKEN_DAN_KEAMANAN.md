# Mekanisme API dan Keamanan Data (Panduan Pemula)

Dokumen ini menjelaskan bagaimana aplikasi "mengobrol" dengan server secara aman agar data pengguna tidak dicuri.

---

## 1. Komunikasi Backend (Cara Ngobrol)

Aplikasi ini tidak menggunakan REST API biasa (yang pakai URL panjang), tapi menggunakan **Firebase SDK**.

**Apa bedanya?**
*   **Lebih Cepat:** Menggunakan protokol gRPC (di atas HTTP/2) yang lebih ngebut daripada HTTP biasa.
*   **Real-time:** Bisa membuka koneksi terus-menerus (socket) untuk fitur live chat atau antrean live.

**Dimana kodenya?**
Di seluruh folder `lib/services/`.
Contoh di `lib/services/queue_service.dart`, kita memanggil `_firestore.collection('queues').doc(id).snapshots()`. Ini langsung membuka saluran komunikasi khusus ke server Google.

---

## 2. Autentikasi & Token (Satpam Digital)

Kita menggunakan sistem **JWT (JSON Web Token)**. Bayangkan Token ini seperti "Kartu Identitas Sementara".

### Alur Kerja (Flow):
1.  **Login:** User memasukkan email & password di `lib/screens/login_screen.dart`.
2.  **Dapat Token:** Jika benar, Firebase memberi **ID Token**.
    *   Lihat kode: `lib/services/auth_service.dart` di dalam fungsi `signIn()`:
        ```dart
        final token = await current.getIdToken();
        ```
3.  **Disimpan:** Token ini disimpan di HP pengguna (biar kalau tutup aplikasi, pas buka lagi masih login).
4.  **Dipakai:** Setiap kali aplikasi minta data (misal: ambil profil), Token ini ikut dikirim secara otomatis oleh Firebase SDK. Server mengecek: "Ini token asli atau palsu?".

---

## 3. Keamanan Penyimpanan (Secure Storage)

Jangan pernah simpan password atau token di file teks biasa! Hacker gampang mencurinya. Kita simpan di "Brankas Besi" milik HP.

**Teknologi yang dipakai:**
*   **Android:** Android Keystore (Enkripsi hardware).
*   **iOS:** Keychain Services.

**Dimana kodenya?**
Aplikasi menggunakan library `flutter_secure_storage` yang dibungkus di `SessionService` (atau sejenisnya).
*   Cek `lib/services/auth_service.dart`:
    ```dart
    await SessionService().saveSession(uid: uid, idToken: token);
    ```
Ini memastikan kalau HP hilang dan dibongkar file-nya, data login pengguna tetap tidak bisa dibaca.

---

## 4. Keamanan di Database (Firestore Rules)

Selain di aplikasi, kita juga pasang satpam di Server.
File: `firestore.rules` (di root folder project).

**Contoh Aturan:**
*   Hanya "admin" yang boleh mengedit data Barbershop.
*   User biasa hanya boleh baca jadwal, tapi tidak boleh hapus jadwal orang lain.
*   *Catatan: Saat pengembangan (Development), rules mungkin dilonggarkan, tapi saat rilis (Production) harus diperketat.*
