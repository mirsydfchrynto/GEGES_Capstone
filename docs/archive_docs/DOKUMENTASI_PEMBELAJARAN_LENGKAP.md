# 🎓 PANDUAN BELAJAR & DOKUMENTASI LENGKAP: GEGES SMART BARBER

Halo! Selamat datang di dokumentasi pembelajaran proyek **Geges Smart Barber**. File ini dibuat khusus untuk membantu kamu memahami aplikasi ini dari level pemula sampai tingkat lanjut. Kita akan bedah aplikasi ini sampai ke akar-akarnya!

---

## 1. 🧩 PEMAHAMAN KODE & ALUR APLIKASI

### A. Arsitektur Proyek (The "Skeleton")
Aplikasi ini menggunakan struktur folder yang rapi dan terorganisir. Kita menggunakan pola **MVVM (Model-View-ViewModel)** yang dipisahkan dengan **Services Layer**.

*   **`lib/models/`**: Berisi "cetakan" data. Contohnya `queue.dart` untuk data antrean, `barberman.dart` untuk data tukang cukur. Folder ini adalah fondasi. Setiap data yang keluar-masuk database harus lewat model ini agar aman (Type-Safe).
*   **`lib/services/`**: Inilah "Otak" aplikasi. Semua fungsi yang berhubungan dengan Database (Firestore) ada di sini.
    *   `queue_service.dart`: Mengatur logika booking, pembatalan, dan pembayaran.
    *   `barberman_service.dart`: Mengatur data barber, jadwal libur, dan performa.
    *   `notification_service.dart`: Mengurus notifikasi push agar HP user bunyi saat status pesanan berubah.
    *   `network_service.dart`: Mendeteksi jika user kehilangan sinyal internet.
*   **`lib/viewmodels/`**: Jembatan antara UI dan Data. Dia yang menyiapkan data agar siap ditampilkan di layar. Misalnya, mengubah angka ribuan jadi format Rupiah (Rp10.000).
*   **`lib/screens/`**: Berisi UI (User Interface). Folder ini dibagi-bagi lagi berdasarkan peran (Role): `admin/`, `tenant/`, `customer/`.
*   **`lib/widgets/`**: Komponen kecil yang dipakai berulang kali, seperti tombol custom, kartu (card) pesanan, atau loading spinner.
*   **`lib/main.dart`**: Pintu masuk aplikasi. Di sini kita setup tema (hitam & emas), Sentry (untuk lacak error), dan Firebase.

### B. Alur Utama (The "User Journey")
Gimana sih aplikasi ini bekerja? Mari kita ikuti langkah-langkahnya:

1.  **Inisialisasi**: Saat app dibuka, `main.dart` akan mengecek koneksi internet dan status login. Jika ada booking yang sudah kadaluarsa (lupa bayar), sistem otomatis membatalkannya di background (`_checkAndCancelExpiredForCurrentUser`).
2.  **Pencarian & Booking**:
    *   User memilih Barbershop.
    *   User memilih Barberman (atau pilih "Siapa Saja" untuk algoritma otomatis).
    *   User memilih Layanan (Cukur, Cuci, dll).
    *   Sistem mengecek ketersediaan slot di `QueueService.isSlotAvailable`. Dia akan cek apakah barber tersebut sedang libur, cuti, atau sudah ada janji lain di jam yang berdekatan.
3.  **Proses Pembayaran**:
    *   Setelah booking, statusnya menjadi `waiting`. Admin akan menerima notifikasi.
    *   Admin menyetujui, status jadi `awaiting_payment`. User diberi waktu (misal 15 menit) untuk bayar.
    *   User upload bukti bayar (Base64 Image langsung ke Firestore).
    *   Admin verifikasi bukti bayar -> Status jadi `booked`. Jadwal terkunci!
4.  **Pelaksanaan**:
    *   User datang -> Admin klik "Mulai" -> Status `ongoing`.
    *   Selesai -> Admin klik "Selesai" -> Status `served`.
    *   Sistem mencatat statistik jumlah cukuran barber tersebut untuk pembagian kerja yang adil.

---

## 2. 🧠 ANALISIS ALGORITMA CERDAS (Deep Dive)

Aplikasi ini disebut "Smart" karena memiliki beberapa logika otomatis:

### A. Algoritma Pembagian Kerja Adil (Fair Assignment)
Fungsi: `getFairAvailableBarberman` di `QueueService`.
*   **Masalah**: Kadang ada satu tukang cukur yang kecapean karena dapet customer terus, sementara yang lain nganggur.
*   **Solusi**: Jika user memilih opsi "Siapa Saja", sistem akan mencari barber yang:
    1. Sedang aktif dan masuk kerja hari ini.
    2. Sedang tidak melayani customer di jam tersebut.
    3. **PENTING**: Sistem memilih barber dengan jumlah cukuran (`monthly_haircut_count`) paling sedikit di bulan ini.
*   **Hasil**: Beban kerja terbagi rata, pendapatan barber lebih adil.

### B. Validasi Slot Waktu (Anti-Collision)
Fungsi: `isSlotAvailable`.
Sistem akan membuat "blokade" waktu. Jika Anda booking jam 10:00 dengan durasi 30 menit, maka sistem otomatis mengunci waktu 10:00 sampai 10:40 (ada tambahan buffer 10 menit untuk istirahat/bersih-bersih). Orang lain tidak bisa masuk di celah waktu tersebut.

---

## 3. 📊 SKEMA DATABASE (Firestore Structure)

Penting untuk memahami bagaimana data disimpan di Firebase:

1.  **`users`**:
    *   `uid`: ID unik dari Firebase Auth.
    *   `role`: 'customer', 'admin', atau 'superadmin'.
    *   `isSuspended`: Untuk memblokir user nakal.
2.  **`barbershops`**:
    *   `name`, `address`, `open_hour`, `close_hour`.
    *   `payment_window_minutes`: Berapa lama user boleh telat bayar sebelum batal otomatis.
3.  **`barbermen`**:
    *   `barbershop_id`: Menghubungkan barber ke tokonya.
    *   `offDays`: List hari libur (senin, selasa, dll).
    *   `onLeave`: Status cuti darurat.
4.  **`queues` (Antrean)**:
    *   `customer_id`, `barberman_id`, `service_ids`.
    *   `status`: 'waiting', 'awaiting_payment', 'booked', 'ongoing', 'served', 'cancelled', 'cancellation_requested'.
    *   `payment_proof_base64`: String gambar bukti bayar.

---

## 4. 🏆 KELENGKAPAN APLIKASI 100%

### 🌟 Fitur Untuk Customer (User)
*   **Smart Booking**: Sistem cerdas yang mencegah tabrakan jadwal.
*   **History Transaksi**: Pantau semua pesanan (Aktif, Selesai, Dibatalkan).
*   **Refund System**: Jika batal, user bisa minta refund (dipotong biaya admin 10% otomatis).
*   **Real-time Notifications**: Notifikasi push via Firestore stream.
*   **Dark Mode Premium**: Desain mewah dengan aksen emas (Gold) dan hitam pekat.
*   **Multi-language**: Dukungan Bahasa Indonesia dan Inggris (i18n).

### 💈 Fitur Untuk Pemilik Barber (Tenant)
*   **Manajemen Barber**: Tambah/Hapus barber, atur hari libur mingguan, atau libur mendadak (Specific Off Days).
*   **Manajemen Layanan**: Atur daftar harga dan durasi tiap layanan (Service Duration-based booking).
*   **Dashboard Antrean**: Real-time monitor untuk melihat siapa yang sedang dicukur.
*   **Laporan Performa**: Statistik kinerja tim barber.

---

## 5. 🧪 TESTING & STABILITAS (Quality Assurance)

Aplikasi ini sudah dites sangat ketat untuk memastikan tidak ada bug.

### A. Statistik Test
*   **Total Test**: 180+ Test Cases.
*   **Pass Rate**: 100%.

### B. Jenis Test
1.  **Unit Test**: Mengetes fungsi matematika (Misal: Rumus refund 90%).
2.  **Widget Test**: Mengetes UI (Misal: Tombol 'Submit' harus disable kalau input kosong).
3.  **Integration Test**: Simulasi robot yang menjalankan aplikasi dari login sampai selesai booking.

---

## 6. 📱 PANDUAN DEMO (Usage Guide)

### Skenario A: Pendaftaran Barbershop Baru (Tenant)
1.  User Login -> Pergi ke Profil -> Klik "Buka Barbershop Saya".
2.  Isi data toko, upload foto, isi jumlah barber.
3.  Setelah kirim, Admin harus menyetujui di Web Dashboard.
4.  Setelah disetujui, User tersebut berubah rolenya menjadi **Admin Barber**.

### Skenario B: Booking Customer
1.  Pilih Barbershop di halaman utama.
2.  Klik "Pesan Sekarang".
3.  Pilih layanan (Misal: Haircut & Shaving).
4.  Pilih Barber (Coba pilih yang sedang libur, pasti dilarang sistem).
5.  Pilih jam (Hanya jam operasional yang muncul).
6.  Klik "Book Now".

---

## 7. 🛠️ TECH STACK (Teknologi yang Dipakai)

Temanmu mungkin tanya, "Pake library apa aja?". Jawabannya:
*   **Flutter (Dart)**: Framework utama.
*   **Firebase Core/Auth**: Untuk login (Email & Google).
*   **Cloud Firestore**: Database NoSQL real-time.
*   **Provider**: State Management (Untuk mengatur aliran data di aplikasi).
*   **Sentry**: Error monitoring (Kalau app crash, dev dapet email).
*   **Firebase App Check**: Security guard (Mencegah akses dari HP yang di-root/emulator ilegal).
*   **Intl**: Untuk format tanggal dan mata uang Rupiah.

---

## 8. ❓ FAQ & TROUBLESHOOTING

**Q: Kenapa booking saya tiba-tiba batal?**
A: Sistem memiliki `Auto-Cancel`. Jika Admin tidak konfirmasi dalam waktu tertentu, atau User tidak upload bukti bayar dalam 15 menit, sistem akan membatalkannya demi memberi slot ke orang lain.

**Q: Gambar bukti bayar kok nggak muncul di database?**
A: Pastikan ukuran gambar tidak terlalu besar. Kita menggunakan Base64, jika terlalu besar Firestore bisa menolak karena limit 1MB per dokumen.

**Q: Gimana cara ganti warna tema?**
A: Buka `lib/main.dart`, cari bagian `ThemeData`. Ubah `kBrownAccent` ke warna lain.

---

## 9. 🏁 KESIMPULAN

Proyek ini adalah contoh implementasi **Digital Transformation** pada bisnis tradisional (Barbershop). Dengan sistem antrean cerdas, kita menghilangkan budaya "nunggu lama di kursi sofa" menjadi "datang tepat waktu saat giliran tiba".

---
*Dibuat dengan ❤️ untuk Masa Depan Industri Barbershop Indonesia.*
*Versi Dokumen: 1.1 (Januari 2026)*
