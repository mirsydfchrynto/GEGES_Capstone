# PEMBELAJARAN FLUTTER: UI INTERAKTIF & NAVIGASI
# Fokus: Komponen Antarmuka, Animasi, dan Alur Pengguna
# Proyek: Geges Smart Barber

================================================================================
I. FILOSOFI UI DI GEGES SMART BARBER
================================================================================
Aplikasi ini mengusung tema "Premium Dark Gold". Pembelajaran utama di sini 
adalah bagaimana konsistensi desain dijaga melalui `ThemeData` di `main.dart`.

1. THEME DATA (Global Styling)
   - Belajar cara mengatur warna `primaryColor` dan `scaffoldBackgroundColor` 
     di satu tempat sehingga seluruh aplikasi memiliki nuansa yang sama.
   - Mengatur `AppBarTheme` untuk memberikan tampilan navigasi yang bersih.

================================================================================
II. KOMPONEN UI INTERAKTIF (WIDGETS)
================================================================================
Belajar cara membuat komponen yang merespon aksi pengguna:

1. TOMBOL KUSTOM (ElevatedButton & OutlinedButton)
   - Perhatikan `ElevatedButtonThemeData`. Kita belajar cara memberikan 
     `borderRadius` yang melengkung dan `padding` yang nyaman disentuh.
   - Penggunaan `InkWell` untuk memberikan efek riak air (ripple effect) saat 
     komponen ditekan.

2. INPUT FORM (TextFormField)
   - Belajar menggunakan `InputDecoration` untuk membuat border emas saat 
     fokus (focusedBorder).
   - Implementasi validasi input: Memastikan email memiliki '@' dan password 
     tidak kosong sebelum data dikirim ke Firebase.

3. FEEDBACK PENGGUNA
   - CircularProgressIndicator: Memberikan tanda visual bahwa sistem sedang 
     bekerja (loading).
   - SnackBar: Memberikan notifikasi singkat di bawah layar jika login gagal 
     atau pendaftaran berhasil.

================================================================================
III. NAVIGASI MENDALAM (ROUTING)
================================================================================
Aplikasi ini menggunakan sistem navigasi terpusat untuk memudahkan pengelolaan 
alur (user flow):

1. NAVIGATOR KEY
   - Kita menggunakan `GlobalKey<NavigatorState>`. Belajar cara berpindah 
     halaman dari dalam 'Service' tanpa membutuhkan variabel `context`.

2. JENIS PERPINDAHAN HALAMAN
   - Navigator.push: Membuka halaman baru (misal: Daftar Barbershop).
   - Navigator.pop: Kembali ke halaman sebelumnya (misal: Tombol Back).
   - Navigator.pushReplacement: Menghapus halaman lama (misal: Dari Login ke 
     Dashboard agar user tidak bisa 'back' ke halaman login lagi).

================================================================================
IV. ANIMASI DAN TRANSISI HALAMAN
================================================================================
Salah satu nilai jual aplikasi ini adalah kehalusan animasinya:

1. ANIMASI GLOW (SplashScreen)
   - Belajar menggunakan `AnimationController` dan `Tween`.
   - Konsep `AnimatedBuilder`: Cara mengupdate satu bagian kecil UI tanpa 
     merender ulang seluruh layar untuk performa maksimal.

2. CUSTOM PAGE TRANSITIONS (FadeTransition)
   - Kita tidak menggunakan perpindahan halaman standar yang membosankan.
   - Belajar cara menggunakan `PageRouteBuilder` untuk memberikan efek 
     'Fade In' atau 'Slide' saat berpindah layar (lihat screens/intro).

================================================================================
V. LAYOUTING STRATEGY (RESPONSIVITAS)
================================================================================
Bagaimana UI Geges Smart Barber tetap rapi di berbagai ukuran layar?

1. FLEXIBLE & EXPANDED
   - Belajar cara membagi ruang dalam `Row` atau `Column` agar widget tidak 
     'overflow' (keluar layar).

2. STACK WIDGET
   - Digunakan di Dashboard dan Splash Screen. Belajar cara menumpuk logo di 
     atas background gradient secara presisi menggunakan `Positioned`.

3. PADDING & MARGIN
   - Belajar standarisasi jarak (misal: 16px atau 24px) agar desain terlihat 
     profesional dan seimbang.

================================================================================
VI. STATEFUL INTERACTION (SETSTATE)
================================================================================
Belajar cara memperbarui UI berdasarkan interaksi lokal:

- Saat user mengetik di kolom pencarian, kita memanggil `setState()`.
- Flutter akan menjalankan ulang fungsi `build()` untuk menampilkan hasil 
  pencarian terbaru secara instan.

================================================================================
VII. BEST PRACTICES (TIPS UNTUK DEVELOPER)
================================================================================
1. KOMPONEN TERPISAH: Jika sebuah widget sudah lebih dari 100 baris, pecahlah 
   menjadi widget kecil di folder `widgets/`.
2. HINDARI HARDCODED: Jangan menulis teks langsung di UI, gunakan sistem 
   Localization (l10n).
3. OPTIMASI GAMBAR: Gunakan `cached_network_image` untuk menampilkan foto dari 
   internet agar lebih cepat dan hemat kuota user.

================================================================================
"UI yang baik adalah yang tidak perlu dijelaskan. Navigasi yang baik adalah 
yang tidak membuat user tersesat."
================================================================================
EOF
