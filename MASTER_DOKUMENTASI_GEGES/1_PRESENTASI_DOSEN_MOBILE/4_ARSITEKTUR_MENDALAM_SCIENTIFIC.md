# Analisis Arsitektur Berbasis Keilmuan (Deep Dive)

Dokumen ini untuk level lanjut. Menjelaskan **teori ilmiah/akademis** di balik keputusan teknis yang kita ambil. Cocok untuk bahan skripsi atau presentasi dosen.

---

## 1. Separation of Concerns (SoC)
**Teori:** Sebuah sistem harus memisahkan tanggung jawab. Jangan campur aduk logika database dengan logika tampilan.
**Implementasi:** Kita menerapkan **N-Tier Architecture**.
1.  **Presentation Tier:** `lib/screens` (UI).
2.  **Logic Tier:** `lib/services` (Business Rules).
3.  **Data Tier:** `Firebase Cloud Firestore` (Database).

**Manfaat:** Jika kita mau ganti database (misal dari Firebase ke MySQL), kita cukup ubah file di `lib/services/` saja. Tampilan UI di `lib/screens/` tidak perlu diubah sama sekali.

---

## 2. Observer Pattern (Pola Pengamat)
**Teori:** Pola desain di mana sebuah objek (Subject) menyimpan daftar tanggungan (Observers) dan memberitahu mereka secara otomatis setiap ada perubahan status.

**Implementasi Nyata:**
*   **Subject:** Database Firestore (`QueueService` yang memantau collection 'queues').
*   **Observer:** `StreamBuilder` di `lib/screens/customer/my_bookings_screen_improved.dart`.

**Analisis:**
Aplikasi ini **Event-Driven**. Bukan aplikasi yang aktif bertanya ("Ada data baru gak?"), tapi aplikasi yang pasif menunggu notifikasi ("Eh, ada data baru nih!"). Ini jauh lebih efisien daripada teknik *Polling* (tanya terus-menerus tiap 1 detik) yang boros bandwidth dan baterai.

---

## 3. NoSQL & Denormalisasi Data
**Teori:** Dalam database NoSQL (seperti Firestore), kita sering melakukan **Denormalisasi** (sengaja menduplikasi data) demi kecepatan baca (Read Performance).

**Implementasi:**
Lihat `UserData` di `lib/models/user_data.dart`.
Kita mungkin menyimpan `nama_barbershop` langsung di dokumen `booking`, padahal `nama_barbershop` juga ada di dokumen `barbershop`.

**Kenapa?**
Agar saat kita mau menampilkan "Riwayat Booking", kita cukup ambil 1 dokumen booking saja sudah ada nama barbershop-nya. Tidak perlu melakukan *Join Query* yang berat dan lambat di database NoSQL.
*   **Trade-off:** Data storage sedikit lebih besar, tapi aplikasi **jauh lebih cepat** saat dibuka user.

---

## 4. Algoritma Fair Assignment (Logika Antrean)
**Lokasi:** `lib/services/queue_service.dart` -> `getFairAvailableBarberman`.

Sistem tidak menunjuk barberman secara acak. Ada algoritmanya:
1.  Cari barberman yang `isActive` (masuk kerja).
2.  Cek apakah dia sedang `onLeave` (cuti) atau `offDay` (libur rutin).
3.  Bandingkan `monthly_haircut_count` (jumlah potong rambut bulan ini).
4.  Pilih barberman yang **paling sedikit** pekerjaannya bulan ini.

**Tujuannya:** Pemerataan pendapatan dan beban kerja antar karyawan (Keadilan).
