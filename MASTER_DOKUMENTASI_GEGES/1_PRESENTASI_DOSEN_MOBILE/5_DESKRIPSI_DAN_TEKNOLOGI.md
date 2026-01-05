# Deskripsi Lengkap Aplikasi dan Implementasi Teknologi
**Geges Smart Barber - Professional Barber Booking & Management System**

Dokumen ini disusun sebagai panduan komprehensif untuk mempresentasikan aspek fungsional, arsitektural, dan teknis aplikasi kepada dosen penguji.

---

## 1. Visi dan Deskripsi Fungsional
Geges Smart Barber adalah solusi digital *all-in-one* untuk industri barbershop. Aplikasi ini dirancang untuk menyelesaikan masalah klasik seperti antrean yang tidak teratur, kesulitan mencari barbershop terdekat, dan ketidakadilan dalam pembagian kerja karyawan.

### Fitur Utama:
*   **Real-time Live Queue:** Pelanggan dapat memantau posisi antrean mereka secara langsung dari smartphone.
*   **Fair Workload Assignment:** Algoritma cerdas yang membagi tugas kepada barberman secara adil berdasarkan riwayat kinerja bulanan.
*   **Style Scan AI:** Menggunakan teknologi deteksi wajah untuk merekomendasikan gaya rambut yang sesuai.
*   **Integrated Payment & Refund:** Sistem pembayaran digital yang mendukung pembatalan dan pengembalian dana otomatis.

---

## 2. Arsitektur Perangkat Lunak (Software Architecture)
Kami menerapkan **Layered Architecture** (Arsitektur Berlapis) untuk menjaga kebersihan kode (*Clean Code*) dan kemudahan pemeliharaan:

1.  **Presentation Layer (UI):** Terletak di `lib/screens` dan `lib/widgets`. Berfungsi menangkap interaksi pengguna. Menggunakan pola *Reactive UI* di mana tampilan otomatis diperbarui saat data di server berubah.
2.  **Service Layer (Business Logic):** Terletak di `lib/services`. Berfungsi sebagai jembatan yang mengolah data mentah menjadi informasi berguna. Di sinilah semua aturan bisnis (seperti perhitungan harga dan validasi antrean) berada.
3.  **Data Layer (Models):** Terletak di `lib/models`. Berfungsi mendefinisikan struktur data (Schema) agar aplikasi memiliki tipe data yang kuat (*Strongly Typed*), mencegah error *null pointer*.

---

## 3. Implementasi Library dan Framework
Aplikasi ini dibangun menggunakan **Flutter SDK** dengan library pendukung sebagai berikut:

| Library / Plugin | Fungsi Utama | Lokasi Penerapan |
| :--- | :--- | :--- |
| **cloud_firestore** | Database NoSQL Real-time | `lib/services/queue_service.dart` (Manajemen antrean). |
| **firebase_auth** | Autentikasi & Keamanan | `lib/services/auth_service.dart` (Login & Token JWT). |
| **google_sign_in** | Autentikasi Google | `lib/screens/login_screen.dart` (Akses akun Google). |
| **flutter_secure_storage** | Enkripsi Hardware | `lib/services/session_service.dart` (Brankas Sesi). |
| **geolocator** | Penentuan Lokasi GPS | `lib/services/location_service.dart` (Cari barber terdekat). |
| **cached_network_image** | Optimasi Aset Visual | `lib/widgets/barber_card.dart` (Menampilkan foto). |
| **firebase_messaging** | Push Notifications | `lib/services/notification_service.dart` (Pengingat). |
| **intl** | Format Standar Lokal | `lib/utils/formatters.dart` (Rupiah & Tanggal Indo). |

---

## 4. Metode dan Algoritma Utama
Aplikasi ini mengimplementasikan beberapa metode teknis tingkat lanjut:

### A. Algoritma Fair Assignment (Penugasan Adil)
*   **Metode:** *Least-Workload Priority*.
*   **Penerapan:** Saat booking dilakukan, sistem melakukan filter terhadap barberman yang aktif dan tidak sedang cuti. Jika ada lebih dari satu pilihan, sistem memilih barberman dengan variabel `monthly_haircut_count` terkecil.
*   **Tujuan:** Mencegah kecemburuan antar karyawan dan memastikan pendapatan merata.

### B. Reactive Data Stream
*   **Metode:** *Observer Pattern* via Firestore Snapshots.
*   **Penerapan:** Menggunakan widget `StreamBuilder` di hampir semua halaman antrean.
*   **Tujuan:** UI diperbarui secara instan (< 1 detik) tanpa perlu user melakukan refresh manual, meningkatkan pengalaman pengguna secara signifikan.

### C. Stateless Token Authentication
*   **Metode:** JWT (JSON Web Token).
*   **Penerapan:** Token ID diperoleh dari Firebase Auth dan diverifikasi oleh *Firestore Security Rules* di sisi server.
*   **Tujuan:** Menjamin keamanan data tanpa membebani memori server (stateless).

---

## 5. Ringkasan Teknis untuk Presentasi
*   **Platform:** Android & iOS (Cross-platform).
*   **Database:** Cloud Firestore (NoSQL Document-oriented).
*   **Security:** JWT, SSL/TLS Pinning, Hardware Key Storage.
*   **Backend Logic:** Serverless (Firebase Cloud Functions & SDK).
*   **Data Consistency:** Transaksi database menggunakan atomicity untuk mencegah *double booking*.
*   **Real-time Auditing:** Implementasi log sistem (`debugPrint`) pada setiap operasi sukses (Auth, Booking, Storage) untuk transparansi proses data saat debugging.