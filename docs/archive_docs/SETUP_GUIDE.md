# 🚀 Panduan Setup Terbaik: 100% Berhasil (Full Ecosystem)

Panduan ini dirancang untuk memastikan Anda dapat melakukan clone dan menjalankan seluruh ekosistem **Geges Smart Barber** (Mobile App + Web Admin + Backend) dengan lancar dari awal sampai akhir.

---

## 📋 Prasyarat Sistem

Pastikan perangkat Anda sudah terinstall:
- **Flutter SDK**: Versi stabil terbaru (min 3.24.x)
- **Node.js**: Versi LTS (untuk Firebase CLI & Scripts)
- **Firebase CLI**: `npm install -g firebase-tools`
- **Java JDK**: Versi 17 (untuk Android Gradle)
- **Git**: Untuk clone repository

---

## 🛠 Langkah 1: Clone Repository

Buka terminal dan jalankan perintah berikut:

```bash
git clone https://github.com/mirsydfchrynto/GEGES_Capstone.git
cd GEGES_Capstone
```

---

## 📂 Langkah 2: Setup Flutter (Mobile App)

1.  **Ambil dependensi:**
    ```bash
    flutter pub get
    ```

2.  **Konfigurasi Keystore (Android):**
    Aplikasi ini menggunakan Firebase App Check. Pastikan SHA-1 debug Anda terdaftar di Firebase Console.
    SHA-1 untuk debug keystore standar: `7E:26:92:EF:82:DE:61:58:7B:1A:1A:B5:70:05:C0:74:19:2E:B1:BF`.

3.  **Konfigurasi Firebase:**
    Jika file `lib/firebase_options.dart` belum ada, jalankan:
    ```bash
    flutterfire configure --project=geges-smartbarber-project
    ```
    *Pilih platform: android, ios, web.*

---

## 🔥 Langkah 3: Setup Firebase (Backend & Rules)

1.  **Login ke Firebase:**
    ```bash
    firebase login
    ```

2.  **Inisialisasi Project:**
    ```bash
    firebase use geges-smartbarber-project
    ```

3.  **Deploy Rules (Firestore & Storage):**
    Proyek ini menggunakan aturan yang sangat longgar untuk tahap pengembangan:
    ```bash
    firebase deploy --only firestore:rules,storage:rules
    ```
    *Catatan: Firestore rules diatur ke `allow read, write: if true;` sesuai spesifikasi proyek ini.*

4.  **Deploy Firestore Indexes:**
    Penting agar fitur filter antrean (QueueService) berjalan:
    ```bash
    firebase deploy --only firestore:indexes
    ```

---

## 🌐 Langkah 4: Setup Web Admin Dashboard

Dashboard admin berada di folder `web_admin` (jika ada) atau dikelola secara terpisah. Jika Anda menjalankan dari repository ini untuk web:

1.  Aktifkan dukungan web: `flutter config --enable-web`
2.  Jalankan aplikasi di browser:
    ```bash
    flutter run -d chrome
    ```

---

## 🧪 Langkah 5: Seeding Data (Sangat Penting)

Aplikasi akan kosong tanpa data awal. Gunakan script yang sudah disediakan untuk mengisi data dummy (Barbershop, Barberman, Services).

1.  Masuk ke folder scripts:
    ```bash
    cd scripts/seeder_node
    npm install
    ```
2.  Jalankan migrasi dan seeder:
    ```bash
    node migrate_barbershop_structure.js
    # Ikuti instruksi di terminal untuk scripts lainnya di folder /scripts
    ```

---

## 🚀 Langkah 6: Menjalankan Aplikasi

Kembali ke root directory dan jalankan aplikasi:

```bash
flutter run
```

---

## ✅ Verifikasi Setup (Testing)

Untuk memastikan semuanya terinstall dengan benar, jalankan suite testing lengkap (180+ tests):

```bash
flutter test
```

Jika semua tes **Passed**, berarti setup Anda 100% sempurna!

---

## 🆘 Troubleshooting

- **Error "No Firebase App":** Pastikan `Firebase.initializeApp()` dipanggil di `main.dart` dan `firebase_options.dart` sudah benar.
- **Data Tidak Muncul:** Cek apakah `firestore.indexes.json` sudah di-deploy.
- **Login Gagal:** Pastikan Email/Password Auth sudah diaktifkan di Firebase Console.
- **App Check Error:** Jika menggunakan emulator, pastikan Debug Token sudah dimasukkan ke Firebase Console.

---

**Selamat Mengembangkan!** ✂️📱
