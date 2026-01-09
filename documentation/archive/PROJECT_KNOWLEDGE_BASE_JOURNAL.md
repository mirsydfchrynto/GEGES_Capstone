# KNOWLEDGE BASE JURNAL: GEGES SMART BARBER (ECOSYSTEM)

**Dokumen Referensi Utama untuk RAG (Retrieval-Augmented Generation)**
**Versi:** 1.0.0
**Status:** Live Development / Multi-Platform Integration
**Architectural Constraints:** Firebase Spark Plan (No Functions, No Storage)

---

## BAGIAN 1: OVERVIEW PROYEK & ARSITEKTUR

### 1.1 Definisi Produk
**Geges Smart Barber** adalah platform SaaS (Software as a Service) Multi-Tenant yang dirancang untuk mendigitalisasi operasional bisnis Barbershop. Sistem ini memungkinkan pemilik barbershop (Tenant) untuk bergabung ke dalam ekosistem aplikasi, mengelola antrean, karyawan (Barberman), dan laporan keuangan secara digital.

### 1.2 Topologi Sistem (Cross-Platform)
Sistem ini terdiri dari dua aplikasi klien utama yang terhubung ke satu database pusat:

1.  **Mobile App (Flutter):**
    *   **Target User:** Customer (Pengguna Jasa), Admin Owner (Pemilik Barbershop), Barberman (Karyawan).
    *   **Fungsi Utama:** Booking, Pembayaran, Manajemen Toko (versi Mobile), Pendaftaran Mitra, Menerima Notifikasi.
    *   **Platform:** Android & iOS.

2.  **Web Admin Portal (React + Vite):**
    *   **Target User:** Super Admin (Pemilik Platform Geges).
    *   **Fungsi Utama:** Verifikasi Pendaftaran Tenant, Manajemen Ekosistem, Monitoring Pendapatan Platform.
    *   **Stack:** React, Redux Toolkit, Tailwind CSS, Firebase SDK Web (v9+).

### 1.3 Infrastruktur & Keterbatasan (CRITICAL CONTEXT)
Proyek ini berjalan di atas **Firebase Spark Plan (Gratis)**. Hal ini memaksakan arsitektur unik yang wajib dipahami:
*   **Tanpa Cloud Functions:** Logika backend server-less tidak tersedia. Semua logika bisnis (Business Logic) yang kompleks, seperti pembuatan akun user baru (Provisioning), harus dijalankan di sisi **Client-Side** (Frontend).
*   **Tanpa Firebase Storage:** Penyimpanan file gambar (BLOB) tidak tersedia. Semua media (Foto Profil, Bukti Transfer, Galeri Toko) dikonversi menjadi string **Base64** dan disimpan langsung di dalam dokumen Firestore.
*   **Batas Dokumen:** Karena menggunakan Base64, ukuran dokumen Firestore dijaga agar tidak melebihi 1MB.

---

## BAGIAN 2: STRUKTUR DATABASE (FIRESTORE SCHEMA)

Berikut adalah "Kamus Data" yang menjadi kebenaran mutlak (Source of Truth) bagi sistem ini.

### 2.1 Collection: `users`
Menyimpan data identitas semua tipe pengguna.
*   **Doc ID:** `uid` (dari Firebase Auth).
*   **Fields:**
    *   `name` (String): Nama lengkap.
    *   `email` (String): Email pengguna.
    *   `role` (String): Menentukan hak akses. Nilai valid: `'customer'`, `'admin_owner'`, `'barberman'`, `'super_admin'`.
    *   `phone_number` (String): Nomor telepon.
    *   `barbershop_id` (String): Link ke collection `barbershops`. Wajib ada jika role adalah `admin_owner` atau `barberman`.
    *   `photo_base64` (String): Foto profil dalam Base64.
    *   `favorite_barbershops` (Array of Strings): List ID barbershop yang disukai customer.

### 2.2 Collection: `barbershops`
Menyimpan data entitas bisnis tenant.
*   **Doc ID:** Auto-generated UUID.
*   **Fields:**
    *   `name` (String): Nama branding barbershop.
    *   `address` (String): Alamat fisik (Perhatian: Kode Mobile App lama mungkin menggunakan typo `addres`, sistem Web harus toleran atau konsisten menggunakan `address` sesuai data aktual di DB).
    *   `rating` (Number): Rating rata-rata (e.g., 4.8).
    *   `imageUrl` (String): Base64 gambar utama toko.
    *   `gallery_urls` (Array of Strings): Kumpulan Base64 gambar galeri interior/eksterior.
    *   `services` (Array of Strings): List ID layanan yang disediakan.
    *   `facilities` (Array of Strings): Fasilitas (AC, Wifi, TV).
    *   `isOpen` (Boolean): Status buka/tutup toko.
    *   `open_hour` (Int) & `close_hour` (Int): Jam operasional (0-23).
    *   `weekly_holidays` (Array of Int): Hari libur rutin (0=Senin, 6=Minggu).
    *   `specific_holidays` (Array of Strings): Tanggal libur khusus (YYYY-MM-DD).
    *   `barber_selection_fee` (Int): Biaya tambahan jika customer memilih barberman spesifik.

### 2.3 Collection: `tenants` (Pendaftaran)
Menyimpan formulir pendaftaran calon mitra yang masuk via Mobile App.
*   **Fields:**
    *   `business_name` (String): Nama usaha yang didaftarkan.
    *   `owner_uid` (String): UID dari user Customer yang mendaftar.
    *   `owner_email` (String): Email pendaftar.
    *   `package_id` (String): Paket langganan yang dipilih.
    *   `status` (String): Flow status -> `'draft'` -> `'awaiting_payment'` -> `'waiting_proof'` -> `'active'` (Verified) / `'rejected'`.
    *   `document_base64` (String): Foto KTP/Identitas pendaftar.
    *   `payment` (Map):
        *   `method`: `'manual'`
        *   `payment_proof_base64`: Gambar bukti transfer (Base64).
        *   `verificationStatus`: `'pending'` atau `'verified'`.

### 2.4 Collection: `queues` (Booking System)
Menyimpan transaksi pemesanan layanan.
*   **Fields:**
    *   `customer_id`, `barberman_id`, `barbershop_id` (Refs).
    *   `status` (String): `'waiting'` (menunggu konfirmasi), `'booked'` (terkonfirmasi), `'ongoing'` (sedang dipangkas), `'served'` (selesai), `'cancelled'`.
    *   `booking_time` (Timestamp): Jadwal pangkas.
    *   `estimated_duration` (Int): Durasi pengerjaan dalam menit.
    *   `total_price` (Int): Harga total layanan.
    *   `order_id` (String): Kode unik pesanan.

### 2.5 Collection: `notifications`
Sistem komunikasi satu arah dari System/Admin ke User.
*   **Fields:**
    *   `user_id` (String): Target penerima notifikasi.
    *   `title` (String).
    *   `body` (String).
    *   `delivered` (Boolean): Status baca/terima.
    *   `created_at` (Timestamp).

---

## BAGIAN 3: ALUR BISNIS UTAMA (BUSINESS LOGIC FLOWS)

### 3.1 Flow Registrasi Mitra (Tenant Provisioning)
Ini adalah alur paling kompleks yang menjembatani Mobile App dan Web Portal.

1.  **Inisiasi (Mobile):** User Customer login di Mobile App, masuk menu "Mitra", mengisi form, dan upload bukti bayar. Data tersimpan di collection `tenants` dengan status `waiting_proof`.
2.  **Verifikasi (Web Super Admin):** Super Admin login ke Web Portal. Sistem menampilkan list data `tenants` yang statusnya `waiting_proof`.
3.  **Eksekusi Approval (Client-Side Logic di Web):**
    *   Saat tombol "Approve" diklik, React App melakukan validasi data.
    *   **Pembuatan Akun Auth:** React App menginisialisasi *Secondary Firebase App Instance* untuk membuat user baru (Email pendaftar + Password acak) tanpa me-logout Super Admin.
    *   **Provisioning Firestore:** React App melakukan *batch write*:
        *   Membuat dokumen `barbershops` baru.
        *   Membuat dokumen `users` baru (Role: `admin_owner`) yang terhubung ke shop baru.
        *   Mengupdate dokumen `tenants` menjadi `active`.
    *   **Pengiriman Kredensial:** React App membuat dokumen di `notifications` yang ditujukan ke `owner_uid` (Customer asli). Isi notifikasi: "Selamat, Barbershop Anda aktif. Login Admin: [Email] | Password: [PasswordAcak]".
4.  **Akses Pemilik (Mobile):** User Customer menerima notifikasi, melihat kredensial, lalu Logout dan Login ulang menggunakan akun Admin Owner baru tersebut untuk mengakses Dashboard Mitra.

### 3.2 Flow Booking & Fairness Algorithm
Sistem antrean tidak hanya "siapa cepat dia dapat", tapi menggunakan algoritma keadilan (Fairness) untuk Barberman.

1.  **Pemilihan Barber:** Saat customer booking, jika mereka tidak memilih barberman spesifik ("Any Barber"), sistem akan menjalankan logika:
    *   Cek barberman yang `isActive` dan tidak `onLeave`.
    *   Cek barberman yang tidak libur (Off Days).
    *   Cek ketersediaan slot waktu (tidak bentrok dengan `queues` lain).
    *   **Fairness Rule:** Dari kandidat yang tersedia, pilih barberman dengan `monthlyHaircutCount` terendah. Ini memastikan pembagian kerja yang rata.
2.  **Anti-Duplikasi:** Sistem menggunakan `booking_anti_duplicate_service.dart` (di Mobile) atau logika `where` query untuk memastikan satu user tidak memiliki 2 booking aktif di jam yang sama, dan satu barberman tidak menerima 2 klien di jam yang sama.

### 3.3 Flow Pembayaran (Manual Transfer)
Mengingat ini sistem rintisan:
*   Pembayaran dilakukan via transfer manual.
*   Bukti bayar difoto -> dikompresi -> diubah ke Base64 -> diupload ke Firestore.
*   Admin Barbershop (di Mobile) atau Super Admin (di Web) memverifikasi bukti tersebut secara visual untuk mengubah status transaksi.

---

## BAGIAN 4: DETAIL FITUR PER PLATFORM

### 4.1 Fitur Aplikasi Mobile (Flutter)
*   **Customer Side:**
    *   Pencarian Barbershop (Search & Filter).
    *   Sistem Favorit (Bookmark Barbershop).
    *   Booking Real-time (Pilih Layanan, Pilih Barber, Pilih Jam).
    *   Riwayat Booking & Review/Rating.
*   **Tenant/Admin Side:**
    *   Manajemen Toko (Update jam buka, fasilitas, foto).
    *   Manajemen Layanan (Tambah/Hapus layanan & harga).
    *   Manajemen Karyawan (CRUD Barberman, Atur Jadwal Libur/Cuti).
    *   Laporan Keuangan Sederhana (Rekap Booking).
    *   Scan QR Code (Future Plan) untuk verifikasi kedatangan.

### 4.2 Fitur Web Portal (React Super Admin)
*   **Dashboard:** Statistik makro (Total Tenants, Revenue Platform).
*   **Inbox Pendaftaran:** Viewer canggih untuk memeriksa validitas dokumen foto (Base64) dan bukti bayar calon mitra.
*   **Tenant Management:** List semua barbershop aktif, kemampuan untuk *Suspend* toko yang melanggar aturan.
*   **User Management:** Reset password admin tenant (jika diminta).

---

## BAGIAN 5: KEAMANAN & ATURAN SISTEM (SECURITY RULES)

### 5.1 Role-Based Access Control (RBAC)
Meskipun `firestore.rules` saat ini mungkin diset longgar (`allow read, write: if true`) untuk fase pengembangan cepat, logika aplikasi memberlakukan batasan keras:
*   **Super Admin:** Akses mutlak ke semua collection. Hanya bisa login di Web Portal.
*   **Admin Owner:** Hanya bisa Read/Write dokumen `barbershops`, `barbermen`, `services`, dan `queues` yang memiliki `barbershop_id` milik mereka sendiri.
*   **Customer:** Hanya bisa Read data publik Barbershop dan Write ke `queues` milik sendiri.

### 5.2 Penanganan Edge Cases
*   **Firestore Limit:** Aplikasi membatasi ukuran gambar sebelum di-encode ke Base64 (biasanya di-resize ke max 800x800px atau kompresi 70%) agar tidak menabrak batas 1MB dokumen Firestore.
*   **Koneksi Lambat:** Menggunakan `Redux Persist` (Web) dan `Hive/SharedPrefs` (Mobile) untuk menyimpan sesi user agar tidak perlu login berulang kali.

---

## BAGIAN 6: CATATAN INTEGRASI PENTING

*   **Typo Warisan:** Perhatikan field `addres` vs `address`. Kode lama mungkin menulis `addres`, namun standarisasi baru mengarah ke `address`. Sistem pembaca (Reader) harus menangani kedua kemungkinan field tersebut agar tidak *null safety error*.
*   **Date Format:** Semua tanggal disimpan sebagai `Firestore Timestamp`. Konversi ke `DateTime` (Dart) atau `Date` (JS) wajib dilakukan di sisi klien.
*   **Notifikasi:** Notifikasi di Mobile App murni berbasis "Pull" (Mendengarkan perubahan di collection `notifications`), bukan Push Notification (FCM) penuh, untuk menghemat biaya dan kompleksitas di Spark Plan.

---
*Akhir dari Dokumen Jurnal Knowledge Base.*
