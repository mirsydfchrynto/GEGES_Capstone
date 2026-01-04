# Analisis Arsitektur Berbasis Keilmuan (Panduan Lengkap, Detail & Akademis)

Dokumen ini menganalisis sistem Geges Smart Barber menggunakan kacamata Rekayasa Perangkat Lunak (Software Engineering) dan Teori Ilmu Komputer. Dokumen ini bertujuan untuk memberikan landasan ilmiah dan akademis di balik setiap keputusan arsitektur yang diambil dalam proyek ini, menjadikannya referensi utama untuk pengembang tingkat lanjut dan presentasi teknis tingkat tinggi.

---

## 1. Prinsip Desain: Implementasi SOLID

Aplikasi ini tidak dibangun secara asal. Kami mengikuti prinsip **SOLID** untuk memastikan kode yang kami tulis memiliki kualitas tinggi, modular, dan mudah dipelihara oleh siapa pun.

### A. Single Responsibility Principle (SRP)
Prinsip ini menyatakan bahwa sebuah class hanya boleh memiliki satu tanggung jawab saja.
*   **Implementasi:** `AuthService` hanya mengurusi autentikasi. Ia tidak boleh tahu cara menghitung harga atau lokasi GPS.
*   **Analisis Ilmiah:** Meminimalkan efek samping (*side effects*) saat kode diubah. Jika terjadi bug pada sistem login, kita bisa yakin bahwa kode pembayaran tidak akan terpengaruh.

### B. Dependency Inversion Principle (DIP)
Modul tingkat tinggi tidak boleh bergantung pada modul tingkat rendah. Keduanya harus bergantung pada abstraksi (Interface).
*   **Implementasi:** UI (Screen) tidak langsung memanggil database Firestore. UI memanggil sebuah layanan abstraksi (`AuthServiceBase`).
*   **Keuntungan:** Jika suatu hari kita ingin mengganti database Firestore dengan PostgreSQL, kita hanya perlu membuat satu file layanan baru yang mengikuti "kontrak" yang sama tanpa harus mengubah ribuan baris kode UI.

---

## 2. Paradigma Data: NoSQL vs SQL

Kami memilih **Cloud Firestore** (NoSQL) sebagai basis data utama. Mengapa bukan MySQL yang lebih umum digunakan pemula?

### A. Skalabilitas Horizontal vs Vertikal
*   **SQL (MySQL/PostgreSQL):** Biasanya diskalakan secara vertikal (menambah RAM/CPU pada satu server). Sulit untuk menangani jutaan user sekaligus secara real-time.
*   **NoSQL (Firestore):** Diskalakan secara horizontal. Data didistribusikan ke ribuan server Google di seluruh dunia secara otomatis.

### B. Denormalisasi dan Performa (Big O Notation)
Dalam SQL, kita diajarkan normalisasi untuk menghindari duplikasi data. Namun, operasi JOIN pada SQL sangat lambat saat data sudah jutaan.
*   **Teknik:** Kami melakukan **Denormalisasi**. Kami menyimpan data yang sering dibaca secara bersamaan dalam satu dokumen.
*   **Analisis:** Kita mendapatkan data dalam waktu **O(1)** (Konstan). Aplikasi terasa sangat responsif karena tidak ada proses pencarian tabel silang yang memakan waktu CPU server.

---

## 3. Teorema CAP dan Transaksi ACID

Dalam sistem terdistribusi, ada dua teori besar yang menjadi pedoman kami:

### A. Teorema CAP (Consistency, Availability, Partition Tolerance)
Firestore adalah sistem yang mengutamakan **CP** (Consistency & Partition Tolerance).
*   **Artinya:** Sistem menjamin bahwa data yang dilihat oleh Admin dan Pelanggan selalu sama (Konsisten), bahkan jika ada gangguan kecil di jaringan internet. Hal ini sangat krusial agar tidak terjadi tabrakan jadwal booking antara dua pelanggan berbeda.

### B. Transaksi ACID (Atomicity, Consistency, Isolation, Durability)
Untuk fitur sensitif seperti pembayaran, kami menggunakan **Firestore Transactions**.
*   **Atomicity:** Transaksi sukses 100% atau gagal 100%. Tidak akan pernah terjadi saldo pelanggan berkurang tetapi status booking tetap "Belum Bayar".
*   **Durability:** Sekali transaksi tercatat, data tersebut aman di server Google meskipun terjadi kegagalan sistem pada perangkat pengguna.

---

## 4. Analisis Algoritma Fair Assignment (Penugasan Adil)

Fitur utama kami adalah algoritma penugasan otomatis barberman. Ini adalah implementasi dari teori optimasi sumber daya manusia.

### Logika Matematika Algoritma:
Sistem menghitung kelayakan setiap barberman berdasarkan beberapa variabel:
1.  **Status Check:** Menyeleksi barberman yang sedang bertugas (`isActive`).
2.  **Temporal Validation:** Mengecek irisan waktu booking. Jika barberman A punya jadwal jam 10-11, sistem akan menghapus namanya dari kandidat untuk booking di jam tersebut.
3.  **Workload Balancing:** Jika terdapat lebih dari satu kandidat, sistem akan memilih barberman dengan jumlah pekerjaan (`monthly_haircut_count`) terkecil.

**Justifikasi Akademis:** Algoritma ini bertujuan untuk meminimalkan deviasi beban kerja antar karyawan. Secara psikologi industri, ini mencegah kelelahan karyawan (*burnout*) dan memastikan keadilan pendapatan bagi seluruh staf.

---

## 5. Strategi Pengujian: Testing Pyramid

Kami memastikan keandalan sistem melalui tiga lapisan pengujian:
1.  **Unit Testing (60%):** Menguji fungsi-fungsi logika bisnis terkecil (seperti perhitungan pajak).
2.  **Widget Testing (30%):** Memastikan komponen UI (seperti tombol) muncul dan berfungsi sesuai desain.
3.  **Integration Testing (10%):** Robot mensimulasikan user asli dari mulai buka aplikasi, login, hingga berhasil melakukan booking. Ini memastikan semua sistem (Frontend, Backend, Database) bekerja selaras.

---

## 6. Kompleksitas Algoritma (Big O Analysis)

Kami memperhatikan efisiensi kode untuk menjaga FPS tetap stabil:
*   **Pencarian Barbershop:** Menggunakan indeks Firestore dengan kompleksitas **O(log n)**. Sangat cepat bahkan jika ada 1 juta barbershop.
*   **Rendering List:** Menggunakan `ListView.builder` dengan kompleksitas memori **O(1)** karena hanya merender apa yang tampil di layar.
*   **Sorting:** Menggunakan algoritma QuickSort bawaan Dart dengan rata-rata **O(n log n)** untuk mengurutkan daftar barbershop terdekat.

---

## 7. Metrik Performa yang Diukur

Kami memantau beberapa metrik kunci untuk menjaga kualitas aplikasi:
1.  **Time to First Paint (TTFP):** Waktu yang dibutuhkan sampai layar pertama muncul. Target kami < 1 detik.
2.  **Frame Drop Rate:** Jumlah frame yang hilang saat animasi. Target kami 0% untuk menjaga kemulusan.
3.  **API Latency:** Waktu respon dari server Google. Target kami < 200ms.
4.  **Crash-free Sessions:** Persentase sesi yang tidak mengalami error fatal. Target kami > 99.9%.

---

## 8. Skalabilitas Masa Depan

Arsitektur ini disiapkan untuk perkembangan jangka panjang:
*   **Multi-tenant Architecture:** Sistem sudah mendukung ribuan cabang barbershop yang berbeda dalam satu aplikasi tanpa risiko data tertukar (Data Isolation).
*   **Micro-services Ready:** Jika fitur AI 'Style Scan' berkembang pesat, kita bisa memindahkannya ke server terpisah tanpa harus merombak seluruh aplikasi mobile.

---

## 9. Penutup: Engineering Excellence

Geges Smart Barber bukan sekadar aplikasi komersial, melainkan hasil dari penerapan disiplin ilmu komputer yang ketat. Dengan menggabungkan prinsip SOLID, teori database terdistribusi, dan algoritma penugasan yang cerdas, kami menciptakan sistem yang kokoh, aman, dan siap menghadapi tantangan industri digital di masa depan.