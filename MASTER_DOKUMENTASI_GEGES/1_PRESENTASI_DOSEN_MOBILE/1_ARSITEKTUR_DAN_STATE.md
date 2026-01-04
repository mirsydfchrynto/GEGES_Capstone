# Arsitektur dan Manajemen State (Panduan Pemula)

Dokumen ini menjelaskan struktur "otak" dan "tubuh" aplikasi Geges Smart Barber. Kami menggunakan pendekatan yang rapi agar kode mudah dibaca, diperbaiki, dan dikembangkan.

---

## 1. Arsitektur Layered (Susunan Lapisan Kode)

Bayangkan aplikasi ini seperti restoran. Ada pembagian tugas yang jelas: pelayan (UI), koki (Logic), dan gudang bahan (Data).

### A. Presentation Layer (Pelayan / Tampilan)
**Apa itu?**
Bagian yang dilihat dan disentuh oleh pengguna. Isinya adalah halaman (Screens) dan tombol-tombol (Widgets). Tugasnya hanya menampilkan data dan menerima input (klik, ketik), tidak boleh mikir berat (logika rumit).

**Dimana kodenya?**
*   Folder: `lib/screens/` dan `lib/widgets/`
*   **Contoh:** `lib/screens/customer/home_screen.dart`
    *   File ini mengatur tampilan beranda, menampilkan daftar barbershop, tapi tidak mengambil data sendiri dari database. Dia minta tolong ke "Service".

### B. Service Layer (Koki / Logika Bisnis)
**Apa itu?**
Bagian yang "berpikir". Dia menerima pesanan dari UI, memprosesnya (misal: hitung harga, cek kuota, validasi password), lalu mengambil atau menyimpan data.

**Dimana kodenya?**
*   Folder: `lib/services/`
*   **Contoh:** `lib/services/auth_service.dart`
    *   Di sini ada fungsi `signIn()` yang mengecek apakah email/password benar ke Firebase.
*   **Contoh:** `lib/services/queue_service.dart`
    *   Mengatur algoritma antrean, siapa barberman yang kosong, dsb.

### C. Data Layer (Gudang / Model Data)
**Apa itu?**
Bagian yang mendefinisikan "bentuk" data. Agar kita tidak salah tulis (misal: salah ketik nama field 'nama' jadi 'name'), kita buat cetakannya (Class).

**Dimana kodenya?**
*   Folder: `lib/models/`
*   **Contoh:** `lib/models/user_data.dart`
    *   Class `UserData` memastikan setiap user punya `uid`, `name`, `role`, dll.
    *   Ada fungsi `fromFirestore()` untuk mengubah data mentah dari database menjadi objek yang aman dipakai di aplikasi.

---

## 2. Manajemen State (Pengaturan Data Real-time)

Bagaimana aplikasi tahu kalau data berubah (misal: antrean maju)? Kita pakai konsep **Reactive Programming**.

### StreamBuilder (Si Pemantau)
**Apa itu?**
Bayangkan `StreamBuilder` itu seperti CCTV. Dia melototi data di database terus-menerus. Kalau data di database berubah, dia langsung teriak ke layar "Update woi!" dan layar berubah otomatis tanpa perlu kita refresh manual (tarik layar).

**Dimana kodenya?**
*   **Contoh:** `lib/screens/customer/my_bookings_screen_improved.dart` (baris 46)
    ```dart
    StreamBuilder<List<DocumentSnapshot>>(
      stream: _antiDupService.streamCustomerBookingsFiltered(...),
      builder: (context, snapshot) {
        // Kalau data baru loading, tampilkan putar-putar
        if (snapshot.connectionState == ConnectionState.waiting) return Loading();
        
        // Kalau data masuk, tampilkan list
        return ListView(...);
      }
    )
    ```

### Kenapa pakai ini?
Agar User Experience (UX) bagus. Pengguna tidak perlu tekan tombol refresh berkali-kali untuk tahu giliran potong rambutnya sudah dekat atau belum.

---

## 3. Eksekusi Asinkronus (Async/Await)

**Apa itu?**
Aplikasi tidak boleh macet (hang) saat mengambil data dari internet yang mungkin lambat. Kita pakai `async` (asinkronus).

**Cara kerjanya:**
Saat aplikasi minta data ke server, dia tidak diam menunggu (blocking). Dia lanjut mengerjakan hal lain (seperti merespon sentuhan tombol). Nanti kalau data datang (`await`), baru dia proses.

**Contoh di `lib/services/auth_service.dart`:**
```dart
Future<Map<String, dynamic>> signIn(...) async {
  // Aplikasi jalan terus sambil nunggu server balas
  final userCredential = await _auth.signInWithEmailAndPassword(...); 
  // Setelah server balas, baru baris ini jalan
  return ...;
}
```
Ini menjaga aplikasi tetap berjalan mulus di 60 FPS (Frame Per Second).
