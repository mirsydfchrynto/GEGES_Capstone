
# geges_smartbarber

> status: sedang dalam tahap pengembangan (work-in-progress)

project ini masih dalam tahap pengembangan. beberapa konfigurasi backend
(mis. file firebase / pengaturan cloud) mungkin tidak disertakan di repo.
tim yang ingin clone untuk pengembangan lokal silakan ikuti bagian
"quick clone untuk tim" di bawah agar bisa menjalankan aplikasi dengan
benar.

simple, friendly, and well-documented flutter app untuk mengelola pemesanan
di barbershop (proyek capstone). readme ini dibuat agar pemula bisa cepat
memahami apa yang aplikasi ini lakukan, cara menjalankannya, dan bagaimana
kontribusi.

## ringkasan singkat

geges_smartbarber adalah aplikasi mobile berbasis flutter yang
memfasilitasi:

- pendaftaran dan autentikasi pengguna (email/password dan oauth)
- onboarding pengguna baru
- pencarian dan pemesanan layanan di barbershop
- manajemen antrean dan booking (untuk customer dan admin)
- integrasi dengan firebase (auth, firestore, storage)

proyek ini dibuat sebagai contoh implementasi pola arsitektur sederhana
dan integrasi layanan firebase untuk kebutuhan capstone / demo.

## fitur utama

- auth: register, login, lupa password, verifikasi email
- onboarding: pageview carousel
- booking: pilih layanan, pilih jadwal, upload bukti pembayaran (opsional)
- admin: dashboard untuk melihat antrean/booking
- realtime updates dengan firestore

## struktur proyek (singkat)

folder utama:

- `lib/` : semua kode sumber dart
	- `screens/` : layar aplikasi (auth, customer, admin, tabs)
	- `services/` : lapisan yang berkomunikasi dengan firebase
	- `models/` : kelas model data (user, booking, barbershop, dll.)
	- `widgets/` : komponen widget yang dipakai ulang
- `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` : platform
- `pubspec.yaml` : daftar dependensi dan asset
- `firebase_options.dart` : konfigurasi firebase yang digenerate (jika ada)

untuk pemahaman lebih mendalam lihat file-file dokumentasi di root
(mis. `DOKUMENTASI_ARCHITECTURE_LENGKAP.md`, `DOKUMENTASI_*` lain).

## persyaratan (prerequisites)

pastiin anda sudah menginstall hal-hal berikut sebelum menjalankan project:

- flutter sdk (disarankan versi stabil terbaru)
- android studio / sdk tools (untuk emulator android)
- xcode (untuk build di macos / ios)
- java jdk (untuk gradle)
- firebase account dan project (untuk fitur backend)
- node & npm (opsional, untuk firebase cli / flutterfire)

catatan: perintah terminal di README ini menggunakan `zsh` (shell default
anda adalah zsh). jika memakai bash langkahnya sama.

## cara clone & jalankan (singkat)

1. clone repository

```zsh
git clone https://github.com/mirsydfchrynto/GEGES_Capstone.git
cd geges_smartbarber
```

2. ambil dependensi

```zsh
flutter pub get
```

3. siapkan konfigurasi firebase

- jika repository sudah berisi `firebase_options.dart` dan file konfigurasi
	platform (`android/app/google-services.json` atau `ios/Runner/GoogleService-Info.plist`),
	Anda bisa langsung ke langkah berikutnya.
- jika belum, ikuti bagian "setup firebase" di bawah.

### quick clone untuk tim (development)

untuk anggota tim yang hanya ingin clone dan menjalankan versi development
lokal dengan cepat ikuti langkah ini:

```zsh
# clone repo
git clone https://github.com/mirsydfchrynto/GEGES_Capstone.git
cd geges_smartbarber

# pastikan menggunakan branch yang benar (biasanya `main` atau minta branch dev)
git fetch
git checkout main

# ambil dependensi
flutter pub get

# jika belum ada konfigurasi firebase di repo, minta file berikut dari pemilik:
# - android/app/google-services.json
# - ios/Runner/GoogleService-Info.plist
# letakkan file di path yang sesuai sebelum menjalankan aplikasi

# jika repo menyertakan flutterfire config, firebase_options.dart biasanya sudah ada
# jika tidak ada, jalankan (jika anda punya akses project firebase):
# dart pub global activate flutterfire_cli
# flutterfire configure

# jalankan app (emulator atau device)
flutter run
```

catatan penting untuk tim:

- beberapa file konfigurasi firebase mungkin tidak dimasukkan ke repo publik.
	minta file `google-services.json` / `GoogleService-Info.plist` dari
	pemilik repo bila perlu.
- jangan commit file berisi kredensial atau secrets ke branch publik.
- jika tim menggunakan branch development terpisah, buat branch lokal dan
	jadikan remote `main` sebagai sumber utama untuk merge.

4. jalankan di emulator / device

```zsh
flutter run
```

atau pilih device tertentu:

```zsh
flutter devices
flutter run -d <device_id>
```

5. build release (android)

```zsh
flutter build apk --release
```

atau untuk ios (macos required):

```zsh
flutter build ios --release
```

## setup firebase (panduan singkat)

project menggunakan firebase (auth + firestore + storage). langkah umum:

1. buat project baru di console.firebase.google.com
2. tambahkan aplikasi android (package name sesuai `android/app/src/main/AndroidManifest.xml`)
	 - unduh `google-services.json` dan letakkan di `android/app/`
3. tambahkan aplikasi ios (bundle id sesuai `ios/Runner/`)
	 - unduh `GoogleService-Info.plist` dan letakkan di `ios/Runner/`
4. (opsional tapi direkomendasikan) gunakan FlutterFire CLI untuk generate
	 `firebase_options.dart`:

```zsh
dart pub global activate flutterfire_cli
flutterfire configure
```

	 - perintah di atas akan membantu menghubungkan project flutter ke
		 project firebase dan membuat `firebase_options.dart` otomatis.

5. jangan commit file-file sensitif atau kunci api jika ada. biasanya
	 `google-services.json` dan `GoogleService-Info.plist` aman untuk
	 disimpan, tapi ikuti kebijakan tim/proyek anda.

6. pastikan package `firebase_core`, `firebase_auth`, `cloud_firestore`,
	 `firebase_storage` dan plugin lain yang dipakai ada di `pubspec.yaml`.

## environment variables / secrets

- project ini tidak memerlukan variabel environment khusus di repo,
	tetapi pastikan file konfigurasi firebase sudah benar untuk setiap
	platform.
- jangan memasukkan kredensial rahasia ke dalam repo publik.

## menjalankan test

```zsh
flutter test
```

untuk menjalankan widget tests (jika ada), gunakan command di atas.

## tips debugging & troubleshooting cepat

- jika build gagal di android karena gradle/sdk:
	- jalankan `flutter doctor -v` dan perbaiki masalah yang dilaporkan
	- buka project di android studio untuk melihat error gradle detail
- jika error firebase initialization:
	- pastikan `google-services.json` di `android/app/`
	- pastikan `firebase_options.dart` cocok dengan project anda
	- cek versi plugin firebase di `pubspec.yaml`
- jika masalah permission saat menjalankan di emulator/device:
	- cek permission runtime pada settings device
	- untuk kamera/storage, pastikan permission diminta di code
- jika runtime error null-safety:
	- periksa apakah API mengembalikan nilai null dan tangani dengan null checks

## style & kontribusi (singkat)

kami menyambut kontribusi kecil! langkah sederhana:

1. fork repository
2. buat branch baru: `git checkout -b feat/nama-fitur`
3. buat perubahan kecil dan commit dengan pesan jelas
4. push ke fork dan buka pull request ke `main`

tips code style:

- ikuti konvensi dart & flutter (dartfmt, analyzer)
- tulis komentar yang membantu (di proyek ini banyak dokumentasi)

## keamanan & privasi

- jangan commit data pengguna atau kunci rahasia ke repo publik
- jika menyimpan gambar atau file user di firebase storage, pastikan
	rules storage dan security rules firestore sudah dikonfigurasi

## referensi & dokumentasi internal

- dokumentasi lebih detil ada di file `DOKUMENTASI_*.md` di root repo.
	baca `DOKUMENTASI_INDEX.md` untuk navigasi cepat.
- untuk panduan flutter: https://docs.flutter.dev/
- untuk panduan firebase: https://firebase.google.com/docs

## lisensi

project ini belum mengandung lisensi khusus di repo. jika Anda ingin
mem-publish, tambahkan file `LICENSE` (mis. mit, apache-2.0) sesuai
keperluan.

---

butuh bantuan tambahan? beri tahu saya bagian mana yang ingin
diperluas: setup firebase step-by-step dengan screenshot, contoh
env template, atau petunjuk contribution lebih spesifik. saya bisa
menambahkan bagian itu.

