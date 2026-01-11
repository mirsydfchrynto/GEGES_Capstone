# PEMBELAJARAN FLUTTER: KONEKSI REAL API & DATA
# Fokus: Integrasi Backend, Asynchronous Programming, dan Pemrosesan Data
# Proyek: Geges Smart Barber

================================================================================
I. APA ITU API DALAM KONTEKS FLUTTER?
================================================================================
API (Application Programming Interface) adalah "jembatan" yang menghubungkan 
aplikasi Flutter Anda dengan server atau database di internet. Di proyek ini, 
kita mempelajari dua jenis interaksi data utama:

1. CLOUD FIRESTORE (Real-time API): Menggunakan SDK khusus dari Google untuk 
   sinkronisasi data instan.
2. REST API / HTTP: Menggunakan paket `http` atau `dio` untuk mengirim 
   permintaan ke server melalui protokol internet standar.

================================================================================
II. ASYNCHRONOUS PROGRAMMING (FUTURE & ASYNC/AWAIT)
================================================================================
Karena mengambil data dari internet butuh waktu (milidetik hingga detik), 
kita tidak boleh mengunci tampilan (freeze). Kita belajar:

1. FUTURE: Sebuah janji bahwa data akan datang di masa depan.
2. ASYNC/AWAIT: Cara menulis kode "menunggu" data tanpa membuat aplikasi hang.
   
Contoh dari `AuthService`:
```dart
Future<void> signIn(String email, String password) async {
  // Tunggu hasil dari server Firebase
  await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
}
```

================================================================================
III. MODEL DATA & SERIALISASI (MAP KE OBJECT)
================================================================================
Data dari API biasanya datang dalam format JSON atau Map. Kita belajar cara 
mengubahnya menjadi Class Dart (Object) agar mudah dikelola:

1. FROMMAP / FROMJSON: Fungsi untuk mengubah "bahasa server" menjadi "bahasa 
   Dart".
2. TOMAP / TOJSON: Fungsi untuk mengubah data input user menjadi format yang 
   dimengerti server sebelum dikirim.

Contoh di folder `lib/models/`:
- `BarberModel.fromMap(data)` mengubah dokumen database menjadi objek Barber.

================================================================================
IV. REAL-TIME DATA STREAMING (STREAMBUILDER)
================================================================================
Geges Smart Barber sangat bergantung pada data yang berubah-ubah (seperti 
nomor antrean). Kita belajar konsep STREAM:

- API tidak hanya memberikan data sekali (Future), tapi mengalirkan data terus 
  menerus (Stream).
- `StreamBuilder`: Widget yang otomatis update UI saat ada perubahan di server 
  tanpa user perlu melakukan "pull to refresh".

================================================================================
V. PENANGANAN ERROR & STATUS CODE
================================================================================
API tidak selalu berhasil. Kita belajar cara menangani kegagalan:

1. TRY-CATCH BLOCK: Menangkap error jaringan atau password salah.
2. STATUS CODES: 
   - 200: Sukses.
   - 401/403: Masalah izin/autentikasi.
   - 404: Data tidak ditemukan.
   - 500: Server sedang bermasalah.

================================================================================
VI. KEAMANAN API (API KEYS & APP CHECK)
================================================================================
Bagaimana cara mencegah orang jahat menembak API kita?

1. FIREBASE APP CHECK: Memastikan hanya aplikasi yang di-build resmi yang 
   bisa memanggil API.
2. AUTH TOKENS: Setiap request membawa identitas unik (UID) pengguna yang 
   sudah login.

================================================================================
VII. TOOLS YANG DIGUNAKAN DI PROYEK INI
================================================================================
1. HTTP & DIO: Untuk mengirim request manual (misal: Sentry log, API Email).
2. CLOUD_FIRESTORE: API database utama.
3. FIREBASE_MESSAGING: API untuk mengirim notifikasi push ke handphone.

================================================================================
VIII. TIPS BEKERJA DENGAN REAL API
================================================================================
1. LOADING STATES: Selalu tampilkan indikator loading agar user tahu aplikasi 
   sedang mengambil data.
2. OFFLINE HANDLING: Gunakan `connectivity_plus` untuk mendeteksi jika user 
   kehilangan sinyal (lihat `widgets/offline_screen.dart`).
3. CACHING: Gunakan `cached_network_image` agar gambar yang sudah pernah 
   didownload tidak perlu didownload ulang (hemat kuota).

================================================================================
"Data adalah darah dari sebuah aplikasi. API adalah pembuluhnya."
================================================================================
EOF
