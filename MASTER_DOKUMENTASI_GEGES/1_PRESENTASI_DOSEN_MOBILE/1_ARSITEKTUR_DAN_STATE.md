# Arsitektur dan Manajemen State (Panduan Lengkap, Detail & Terstruktur)

Aplikasi Geges Smart Barber dibangun dengan standar industri yang tinggi. Dokumen ini dirancang khusus untuk pengembang pemula agar dapat memahami setiap sudut dari struktur aplikasi ini secara mendalam. Kami tidak hanya memberi tahu *apa* yang dilakukan, tapi juga *mengapa* itu dilakukan. Memahami dasar ini akan membuat Anda tidak hanya menjadi tukang ketik kode, tapi menjadi seorang Arsitek Perangkat Lunak yang handal.

---

## 1. Filosofi Arsitektur Layered (N-Tier)

Dalam dunia pengembangan perangkat lunak modern, kita tidak boleh menaruh semua logika dalam satu tempat. Jika semua kode ditaruh di satu file, aplikasi akan mustahil untuk dikelola, dikembangkan, atau diperbaiki saat terjadi kesalahan. Kami menggunakan **Layered Architecture** untuk memecah kerumitan tersebut.

### A. Presentation Layer (Antarmuka & Pengalaman Pengguna)
Ini adalah lapisan teratas yang berinteraksi langsung dengan panca indera dan jari pengguna.
*   **Lokasi Folder:** `lib/screens/` dan `lib/widgets/`
*   **Tanggung Jawab Utama:**
    *   Mengatur tata letak visual (Grid, List, Column, Row).
    *   Menangani transisi dan animasi antar halaman.
    *   Menampilkan umpan balik visual (dialog, snackbar, loading spinner).
*   **Detail Teknis:**
    Setiap file di sini biasanya merupakan sebuah `StatelessWidget` atau `StatefulWidget`. Kita memisahkan folder `admin/`, `customer/`, dan `auth/` untuk memastikan logika hak akses tidak tercampur secara tidak sengaja.
*   **Contoh Kasus:**
    Saat tombol "Booking" diklik, halaman ini tidak memiliki kode untuk menyimpan ke database. Ia hanya memanggil fungsi `QueueService().createBooking()`.

### B. Service Layer (Pusat Logika & Otak Aplikasi)
Lapisan ini adalah tempat di mana semua "perhitungan" dan keputusan dilakukan.
*   **Lokasi Folder:** `lib/services/`
*   **Tanggung Jawab Utama:**
    *   Validasi input (Memastikan email valid dan password memenuhi syarat).
    *   Komunikasi eksternal dengan Firebase (Firestore, Auth, Cloud Messaging).
    *   Perhitungan bisnis (Menghitung durasi layanan, total biaya, dan pajak).
*   **Kenapa Harus Dipisah?**
    Bayangkan jika suatu hari Anda ingin membuat versi website atau desktop dari aplikasi ini. Jika logikanya sudah dipisah di `Service Layer`, Anda tinggal memakai ulang file tersebut tanpa menulis ulang satu baris pun logika bisnisnya. Ini adalah konsep *Reusability*.

### C. Data/Model Layer (Cetak Biru Data)
Tanpa Model, data dari database hanya akan berupa teks mentah (JSON) yang sulit dikelola.
*   **Lokasi Folder:** `lib/models/`
*   **Tanggung Jawab Utama:**
    *   Memberikan identitas dan tipe data pada informasi.
    *   Memastikan keamanan tipe (Type-Safety) agar aplikasi tidak crash karena kesalahan format data.
*   **Contoh Kode Model (`barberman.dart`):**
    ```dart
    class Barberman {
      final String id;
      final String name;
      final bool isActive;
      final int monthlyHaircutCount;

      Barberman({
        required this.id, 
        required this.name, 
        this.isActive = true,
        this.monthlyHaircutCount = 0,
      });

      // Fungsi untuk mengubah data Firestore menjadi objek Dart
      factory Barberman.fromFirestore(DocumentSnapshot doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Barberman(
          id: doc.id,
          name: data['name'] ?? 'Barber',
          isActive: data['isActive'] ?? true,
          monthlyHaircutCount: data['monthly_haircut_count'] ?? 0,
        );
      }
    }
    ```

---

## 2. Bedah Struktur Folder Proyek (Roadmap untuk Pemula)

Sebagai pengembang, Anda harus mengenali peta proyek Anda:
1.  **`android/` & `ios/`:** Berisi file konfigurasi asli untuk masing-masing OS. Di sini kita mengatur izin GPS, Kamera, dan integrasi Google Login di level sistem.
2.  **`assets/`:** Rumah bagi aset visual.
    *   `assets/images/`: Foto logo dan ilustrasi.
    *   `assets/fonts/`: Font kustom (jika ada).
3.  **`lib/`:** Pusat aktivitas pengembangan Dart.
    *   `lib/l10n/`: File untuk fitur multi-bahasa.
    *   `lib/utils/`: Berisi alat bantu seperti `currency_formatter.dart`.
    *   `lib/widgets/`: Komponen UI yang sering dipakai berulang (Reusable Components).
4.  **`test/`:** Kumpulan kode pengujian otomatis untuk menjaga kualitas aplikasi.
5.  **`pubspec.yaml`:** Manifest proyek yang berisi daftar library pihak ketiga (dependencies) dan pengaturan aset.

---

## 3. Manajemen State: Kekuatan Reaktif (Stream & Provider)

State adalah kondisi aplikasi pada detik ini juga. Manajemen state adalah cara kita memberitahu layar untuk berubah saat data berubah.

### A. Konsep Stream (Analogi Sinyal Radio)
Aplikasi booking yang modern haruslah **Real-time**. Jika status antrean Anda berubah, layar harus segera berubah tanpa Anda refresh.
*   **Stream:** Siaran radio yang terus mengirimkan data terbaru dari server.
*   **StreamBuilder:** Pesawat radio di HP Anda yang mendengarkan siaran tersebut dan mengubah suaranya (tampilannya) secara instan.

### B. Contoh Implementasi Lanjut
```dart
StreamBuilder<List<Queue>>(
  stream: _queueService.streamQueuesForCustomer(currentUserId),
  builder: (context, snapshot) {
    // Tahap 1: Menunggu data (Loading)
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Tahap 2: Penanganan Error (Gagal koneksi)
    if (snapshot.hasError) {
      return Center(child: Text("Gagal mengambil data: ${snapshot.error}"));
    }
    
    // Tahap 3: Data Kosong
    if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return const Center(child: Text("Anda belum memiliki jadwal booking."));
    }
    
    // Tahap 4: Menampilkan Data (Berhasil)
    final bookings = snapshot.data!;
    return ListView.builder(
      itemCount: bookings.length,
      itemBuilder: (context, index) => BookingCard(booking: bookings[index]),
    );
  },
)
```

---

## 4. Daftar Lengkap Layanan (Services)

Aplikasi ini memiliki banyak "Service" yang bekerja di balik layar. Berikut daftar lengkapnya untuk referensi Anda:

1.  **`AuthService`**: Menangani pintu masuk aplikasi (Login, Register, Logout).
2.  **`QueueService`**: Jantung dari aplikasi antrean. Mengatur siapa barber yang kosong.
3.  **`ServiceService`**: Mengelola daftar jenis potongan rambut (Layanan) dan harganya.
4.  **`BarbershopService`**: Mengelola informasi lokasi dan jam operasional outlet.
5.  **`NotificationService`**: Mengirimkan pengingat ke HP user agar tidak telat datang.
6.  **`LocationService`**: Mencari tahu di mana posisi user agar bisa merekomendasikan cabang terdekat.
7.  **`StyleScanService`**: Berkomunikasi dengan AI untuk fitur deteksi gaya rambut.
8.  **`RatingService`**: Mengelola ulasan dan bintang yang diberikan pelanggan.
9.  **`TenantService`**: Mengelola data pemilik barbershop yang bergabung di platform.
10. **`SessionService`**: Mengelola data login yang tersimpan di HP agar user tidak perlu login berulang kali.

---

## 5. Standar Penulisan Kode (Clean Code Guidelines)

Agar kode kita profesional dan mudah dibaca orang lain:
1.  **Descriptive Naming:** Jangan gunakan nama variabel singkat seperti `x`. Gunakan `totalBookingPrice`.
2.  **Small Functions:** Sebuah fungsi sebaiknya tidak lebih dari 30 baris. Jika lebih, pecahlah menjadi dua fungsi.
3.  **No Magic Numbers:** Jangan tulis `15000` langsung di UI. Masukkan ke dalam variabel atau konstanta seperti `double serviceTax = 15000;`.
4.  **Comments (Why, not What):** Jangan beri komentar "Ini fungsi login". Beri komentar "Kenapa kita perlu re-autentikasi di sini".

---

## 6. Tutorial Singkat: Menambah Halaman Baru

Bagi Anda yang ingin bereksperimen, ikuti langkah ini:
1.  **Buat Model:** Tambahkan file di `lib/models/nama_fitur.dart`.
2.  **Buat Service:** Tambahkan fungsi pengambilan data di `lib/services/nama_fitur_service.dart`.
3.  **Buat Screen:** Buat `StatefulWidget` di `lib/screens/nama_fitur_screen.dart`.
4.  **Hubungkan:** Panggil service dari screen menggunakan `FutureBuilder`.
5.  **Daftarkan Route:** Tambahkan halaman baru Anda di sistem navigasi utama.

---

## 7. Pertanyaan Umum Pemula (FAQ & Troubleshooting)

**T: Kenapa saya harus pakai Model? Capek buatnya.**
J: Tanpa model, Anda akan sering typo menulis nama field (misal: `name` vs `nama`). Dengan model, editor (VS Code/Android Studio) akan memberitahu jika Anda salah ketik. Ini menghemat waktu debugging berjam-jam.

**T: Apa bedanya `Future` dan `Stream`?**
J: `Future` adalah janji satu kali (seperti memesan pizza). `Stream` adalah aliran data (seperti berlangganan koran atau nonton siaran langsung).

**T: Kenapa aplikasi saya lag saat transisi halaman?**
J: Biasanya karena Anda melakukan proses berat (seperti memproses gambar) tepat di saat transisi sedang berjalan. Pindahkan proses tersebut menggunakan `compute()` atau jalankan setelah transisi selesai.

---

## 8. Glosarium Istilah IT (Kamus Pintar)

*   **Hot Reload:** Mengupdate tampilan tanpa harus mengulang dari awal (magic!).
*   **Dependency Injection:** Memberikan sebuah layanan ke bagian yang membutuhkannya secara otomatis.
*   **Build Context:** "KTP" widget yang menyimpan lokasinya di pohon aplikasi.
*   **Boilerplate:** Kode berulang yang membosankan tapi wajib ada.
*   **SDK (Software Development Kit):** Kotak peralatan yang kita pakai untuk membangun aplikasi.
*   **Repo (Repository):** Tempat penyimpanan kode online seperti GitHub.
*   **Bug:** Kesalahan koding yang membuat aplikasi tidak berjalan normal.
*   **Middleware:** Kode yang berjalan di tengah-tengah proses untuk pengecekan keamanan.
*   **Refactoring:** Mengatur ulang kode agar lebih rapi tanpa mengubah fungsinya.

---

## 9. Penutup

Arsitektur aplikasi Geges Smart Barber adalah perwujudan dari disiplin ilmu komputer yang matang. Dengan struktur yang rapi, tim pengembang dapat bekerja secara paralel tanpa saling mengganggu. Teruslah belajar dan jangan berhenti bereksperimen, karena dunia pengembangan mobile selalu berubah dengan sangat cepat.
