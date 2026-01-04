# Mekanisme API dan Keamanan Data (Panduan Lengkap, Detail & Mendalam)

Keamanan dalam pengembangan perangkat lunak bukan sekadar "tambahan", melainkan jantung dari sistem yang dapat dipercaya. Aplikasi Geges Smart Barber mengimplementasikan standar keamanan kelas dunia untuk melindungi privasi pelanggan dan integritas bisnis pemilik barbershop. Dokumen ini dirancang untuk membimbing pengembang pemula memahami lapisan-lapisan keamanan kami secara mendalam.

---

## 1. Komunikasi Backend: Melampaui REST API Konvensional

Banyak pemula hanya akrab dengan REST API (berbasis JSON/HTTP). Namun, untuk performa maksimal dan fitur real-time, kami menggunakan **Firebase SDK** yang berjalan di atas protokol **gRPC**.

### A. Apa itu gRPC dan Perbedaannya dengan REST?
1.  **Format Data:** REST menggunakan JSON (teks) yang ukurannya besar. gRPC menggunakan *Protocol Buffers* (biner) yang jauh lebih kecil dan hemat kuota.
2.  **Protokol:** gRPC menggunakan HTTP/2 yang memungkinkan pengiriman banyak pesan sekaligus dalam satu koneksi (Multiplexing).
3.  **Real-time:** gRPC mendukung komunikasi dua arah (Streaming). Inilah alasan kenapa status antrean di HP Anda bisa berubah secara otomatis tanpa perlu di-refresh.

### B. Manfaat bagi Pengguna Akhir
*   **Hemat Baterai:** Proses pengiriman data yang efisien membuat CPU HP tidak bekerja terlalu keras.
*   **Akses di Sinyal Lemah:** Aplikasi tetap responsif meskipun pengguna berada di area dengan koneksi internet yang lambat.

---

## 2. Autentikasi Modern dengan Token JWT

Kami tidak menggunakan sistem password yang disimpan secara manual. Kami menggunakan **JSON Web Token (JWT)** yang dikelola oleh Google Firebase Auth.

### A. Anatomi Mendalam Sebuah Token JWT
Setiap token terdiri dari tiga bagian yang dipisahkan oleh tanda titik (.):
1.  **Header:** Berisi jenis token dan algoritma enkripsi (misal: RS256).
2.  **Payload:** Jantung informasi. Berisi data seperti:
    *   `uid`: ID unik pengguna di database.
    *   `email`: Alamat email yang terverifikasi.
    *   `role`: Hak akses (admin_owner atau customer).
    *   `exp`: Waktu kadaluwarsa token (biasanya 1 jam).
3.  **Signature:** Tanda tangan digital dari server Google yang menjamin bahwa isi Payload tidak pernah dimanipulasi.

### B. Alur Kerja Autentikasi (Step-by-Step)
1.  **Langkah 1:** Pengguna memasukkan email dan password.
2.  **Langkah 2:** Firebase memverifikasi data tersebut.
3.  **Langkah 3:** Jika cocok, server Google mengirimkan ID Token (JWT) ke HP.
4.  **Langkah 4:** Setiap kali aplikasi meminta data (misal: ambil riwayat booking), ID Token ini dikirimkan secara otomatis di latar belakang.
5.  **Langkah 5:** Server Firestore mengecek tanda tangan token tersebut. Jika asli, data diberikan.

---

## 3. Keamanan Sisi Client: Sidik Jari Digital (SHA-1)

Satu masalah yang sering membuat pemula bingung adalah "Kenapa Google Login saya error?". Jawabannya biasanya ada di **SHA-1 Fingerprint**.

### A. Apa itu SHA-1?
SHA-1 adalah kode unik (sidik jari) dari komputer atau laptop yang Anda gunakan untuk mengoding. Google hanya mau melayani permintaan login dari aplikasi yang sidik jarinya sudah terdaftar di Firebase Console.

### B. Tutorial Menyiapkan SHA-1:
1.  Buka terminal di komputer Anda.
2.  Jalankan perintah: `./gradlew signingReport` (untuk Android).
3.  Cari baris yang bertuliskan `SHA1`.
4.  Daftarkan kode tersebut di Project Settings di Firebase Console.
5.  Download ulang file `google-services.json` dan pasang di proyek Anda.

---

## 4. Keamanan Sisi Server: Firestore Security Rules

Keamanan di HP saja tidak cukup, karena kode di HP bisa dibongkar. Pertahanan terakhir adalah **Security Rules** yang berjalan langsung di server Google.

### A. Bedah Aturan Keamanan Kami
```javascript
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Aturan untuk profil Pengguna
    match /users/{userId} {
      // Siapa saja boleh baca profil dasar (untuk cari barber)
      allow read: if request.auth != null;
      // Hanya pemilik akun yang boleh mengubah data pribadinya
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // Aturan untuk Antrean (Queues)
    match /queues/{queueId} {
      // Pelanggan boleh membuat booking
      allow create: if request.auth != null;
      // Hanya Admin yang boleh mengubah status antrean menjadi 'Selesai'
      allow update: if request.auth != null && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin_owner';
    }
  }
}
```

---

## 5. Daftar Kode Kesalahan (Error Codes) untuk Pemula

Agar Anda tidak bingung saat aplikasi error, berikut daftar kode umum dari Firebase:

*   **`user-not-found`**: Email yang dimasukkan belum terdaftar.
*   **`wrong-password`**: Password salah.
*   **`invalid-email`**: Format penulisan email salah (misal: lupa pakai @).
*   **`email-already-in-use`**: Email sudah dipakai orang lain.
*   **`weak-password`**: Password terlalu pendek atau mudah ditebak.
*   **`too-many-requests`**: Terlalu banyak percobaan gagal (Security block).
*   **`requires-recent-login`**: Anda harus logout dan login lagi sebelum melakukan aksi sensitif.
*   **`network-request-failed`**: Internet Anda sedang bermasalah.

---

## 6. Firebase App Check: Anti-Hacker & Anti-Bot

Ini adalah lapisan keamanan paling mutakhir. App Check memastikan bahwa hanya aplikasi "Geges Smart Barber" yang asli yang bisa berbicara dengan server.
*   **Play Integrity (Android):** Mengecek apakah aplikasi di-install dari Play Store dan HP-nya tidak di-root.
*   **App Attest (iOS):** Fitur serupa dari Apple untuk menjamin keaslian aplikasi.
*   **Hasilnya:** Jika seseorang mencoba membobol database kita menggunakan script Python atau aplikasi bajakan, server akan langsung memblokirnya karena mereka tidak punya "Sertifikat App Check" yang sah.

---

## 7. Penyimpanan Aman: Hardware Encryption

Data sensitif seperti Token Sesi tidak disimpan di memori biasa. Kami menggunakan library `flutter_secure_storage`.
1.  **Android Keystore:** Menggunakan chip keamanan khusus di dalam prosesor HP untuk mengenkripsi data.
2.  **iOS Keychain:** Sistem brankas digital milik Apple yang sangat aman.
3.  **Keuntungan:** Meskipun HP Anda dicolok ke komputer lain dan file-nya dicoba dibongkar, data Anda tetap tidak bisa dibaca karena dikunci secara hardware.

---

## 8. Mengamankan API Keys (Keamanan Repository)

Sangat penting untuk tidak membocorkan kunci rahasia di internet (GitHub):
1.  Gunakan file `.gitignore` untuk menyembunyikan file sensitif.
2.  Gunakan `firebase_options.dart` yang sudah di-generate otomatis.
3.  Jangan pernah membagikan file `google-services.json` kepada orang yang tidak dikenal.
4.  Gunakan Environment Variables jika aplikasi Anda sangat besar dan kompleks.

---

## 9. Penutup

Keamanan di Geges Smart Barber adalah sistem yang berlapis. Dari enkripsi di level chip HP, komunikasi data biner yang cepat, hingga aturan "Satpam" di server Google. Dengan sistem ini, kami menjamin kenyamanan dan keamanan bagi seluruh pengguna aplikasi.