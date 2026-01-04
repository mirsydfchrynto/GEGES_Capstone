# PANDUAN TEKNIS LENGKAP ARSITEKTUR & PENGEMBANGAN
**Geges Smart Barber Mobile Application**

Dokumen ini merangkum seluruh aspek teknis, arsitektur, keamanan, dan alur kerja kode aplikasi dalam satu panduan terpadu. Ditulis untuk pengembang pemula hingga menengah agar memahami *bagaimana* dan *mengapa* kode ditulis demikian.

---

## BAB 1: ARSITEKTUR APLIKASI (LAYERED ARCHITECTURE)

Aplikasi ini menggunakan pola arsitektur **Separation of Concerns (SoC)** yang memisahkan kode berdasarkan tanggung jawabnya menjadi tiga lapisan utama. Tujuannya adalah agar kode mudah dibaca, dites, dan dimodifikasi tanpa merusak bagian lain.

### 1. Presentation Layer (Tampilan UI)
Lapisan ini bertanggung jawab sepenuhnya untuk merender antarmuka pengguna dan menangkap input (tap, scroll, ketik). Lapisan ini **tidak boleh** mengandung logika bisnis yang rumit atau memanggil database secara langsung.

*   **Lokasi Code:** `lib/screens/` dan `lib/widgets/`
*   **Contoh Implementasi:** `lib/screens/customer/home_screen.dart`
    *   File ini hanya mendefinisikan layout (Row, Column), warna, dan tipografi.
    *   Ketika butuh data barbershop, UI akan memanggil `BarbershopService`. UI hanya menerima hasil akhir untuk ditampilkan.

### 2. Service Layer (Logika Bisnis)
Ini adalah "otak" aplikasi. Lapisan ini menjembatani antara UI dan Database. Semua aturan bisnis, validasi, dan pengolahan data terjadi di sini.

*   **Lokasi Code:** `lib/services/`
*   **Contoh Implementasi:** `lib/services/auth_service.dart`
    *   Melakukan validasi email/password.
    *   Berkomunikasi dengan Firebase Auth.
    *   Menangani error (misal: password salah) dan menerjemahkannya menjadi pesan yang bisa dimengerti UI.

### 3. Data Layer (Model Data)
Lapisan ini mendefinisikan struktur data (Schema) agar tipe data konsisten di seluruh aplikasi (Type-Safe). Mengubah data mentah (JSON/Map) menjadi Objek Dart.

*   **Lokasi Code:** `lib/models/`
*   **Contoh Implementasi:** `lib/models/user_data.dart`
    *   Mengubah `Map<String, dynamic>` dari Firestore menjadi objek `UserData`.
    *   Memastikan field krusial seperti `uid`, `role`, dan `email` selalu ada.

---

## BAB 2: MANAJEMEN STATE & REAL-TIME (REACTIVE)

Aplikasi ini bersifat **Event-Driven** dan **Reactive**. Artinya, tampilan akan berubah secara otomatis saat data di server berubah, tanpa perlu pengguna menekan tombol refresh.

### 1. Konsep Stream & StreamBuilder
Kami memanfaatkan fitur `Stream` dari Dart dan Firestore. Stream adalah aliran data yang terus mengalir (seperti pipa air), bukan data statis yang diambil sekali (seperti mengambil ember).

*   **Implementasi:** `StreamBuilder` (Widget)
    *   Widget ini "mendengarkan" (listen) perubahan pada Stream.
    *   Setiap kali ada perubahan data di server (misal: antrean bertambah), Stream mengirim sinyal.
    *   `StreamBuilder` otomatis menjalankan fungsi `build()` ulang untuk memperbarui tampilan.

*   **Contoh Code:** `lib/screens/customer/my_bookings_screen_improved.dart`
    ```dart
    StreamBuilder<List<DocumentSnapshot>>(
      stream: _antiDupService.streamCustomerBookingsFiltered(...), // Pipa data
      builder: (context, snapshot) {
        if (snapshot.hasData) {
           // Otomatis render ulang list saat booking baru masuk
           return ListView(...);
        }
      }
    )
    ```

### 2. Keuntungan Pendekatan Ini
*   **Real-time UX:** Pengguna langsung tahu jika status booking berubah dari 'waiting' ke 'confirmed'.
*   **Efisiensi:** Tidak perlu melakukan *Polling* (meminta data tiap detik) yang memboroskan baterai dan kuota.

---

## BAB 3: KEAMANAN DATA & AUTENTIKASI

Keamanan diterapkan berlapis, mulai dari Sisi Client (Aplikasi) hingga Sisi Server (Firebase).

### 1. Autentikasi dengan Firebase Auth
Sistem login tidak menyimpan password pengguna di database kita (rawan), melainkan menggunakan provider aman Google Identity Platform.

*   **Flow Login:**
    1.  User input Email/Pass.
    2.  `AuthService` kirim ke Firebase.
    3.  Firebase membalas dengan **ID Token (JWT)**.

### 2. Token Management (JWT)
JSON Web Token (JWT) digunakan sebagai tiket akses digital.
*   **Verifikasi:** Setiap request ke database menyertakan token ini.
*   **Validasi:** Server memverifikasi tanda tangan digital token untuk memastikan request berasal dari user asli, bukan hacker.

### 3. Secure Storage (Penyimpanan Aman di HP)
Data sensitif seperti Token Sesi tidak boleh disimpan di `SharedPreferences` biasa (mudah dibaca jika HP di-root).

*   **Teknologi:** `flutter_secure_storage`
    *   **Android:** Menggunakan enkripsi **AES** dalam **Android Keystore System**.
    *   **iOS:** Menggunakan **Keychain Services**.
*   **Implementasi:** `lib/services/session_service.dart`.

### 4. Firestore Security Rules
Pengamanan terakhir ada di server. File `firestore.rules` mengatur siapa boleh baca/tulis apa.
*   **Aturan:** "Hanya user dengan `uid` yang sama yang boleh mengedit profilnya."
*   **Aturan:** "Hanya role `admin_owner` yang boleh mengubah data Barbershop."

---

## BAB 4: SIKLUS HIDUP (LIFECYCLE) & PERFORMA

Memahami lifecycle sangat penting untuk mencegah **Memory Leak** (aplikasi semakin berat lama-lama).

### 1. StatefulWidget Lifecycle
*   **initState()**: Dipanggil 1x saat halaman dibuka. Tempat inisialisasi data, langganan Stream, atau timer.
    *   *Contoh:* Mulai load data lokasi GPS di `HomeScreen`.
*   **build()**: Dipanggil berkali-kali saat UI perlu digambar ulang. Jangan taruh proses berat di sini!
*   **dispose()**: Dipanggil saat halaman ditutup. **Wajib** menutup semua koneksi (Stream, Controller, Timer) di sini.
    *   *Contoh Code (`home_screen.dart`):*
        ```dart
        @override
        void dispose() {
          _searchController.dispose(); // Hapus listener text input
          _debounce?.cancel();         // Matikan timer pencarian
          super.dispose();
        }
        ```

### 2. Optimasi Rendering
*   **ListView.builder:** Teknik *Lazy Loading*. Hanya merender item yang terlihat di layar. Jika ada 1000 data, yang dirender hanya 5-6 yang muat di layar HP. Hemat RAM.
*   **Const Constructors:** Menandai widget statis dengan `const` (misal: `const SizedBox(height: 20)`). Ini memberitahu Flutter bahwa widget ini tidak perlu digambar ulang (rebuild), meningkatkan FPS.

---

## BAB 5: LOGIKA BISNIS UTAMA (STUDI KASUS)

Salah satu logika terpenting adalah sistem antrean dan pemilihan barberman.

### Algoritma Fair Assignment
Terletak di `lib/services/queue_service.dart`, fungsi `getFairAvailableBarberman`.
Sistem tidak memilih barberman secara acak, melainkan menggunakan algoritma prioritas:

1.  **Filter Aktif:** Ambil semua barberman yang statusnya `isActive: true`.
2.  **Filter Jadwal:** Buang barberman yang sedang cuti (`onLeave`) atau libur hari ini (`offDays`).
3.  **Cek Slot Waktu:** Pastikan barberman tidak punya booking lain di jam yang sama (overlap check).
4.  **Load Balancing:** Dari kandidat yang tersisa, pilih barberman dengan `monthly_haircut_count` **terendah**.

**Tujuan:** Memastikan pembagian kerja yang adil (Fairness) antar karyawan secara otomatis.

---

Dokumen ini disusun sebagai referensi teknis utama untuk pengembangan dan pemeliharaan aplikasi Geges Smart Barber.
