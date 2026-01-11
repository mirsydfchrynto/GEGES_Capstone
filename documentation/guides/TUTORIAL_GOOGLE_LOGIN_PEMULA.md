PANDUAN PRAKTIS: IMPLEMENTASI GOOGLE LOGIN DARI AWAL (VERSI LENGKAP & DETAIL)

Halo. Hari ini kita akan belajar cara memasang fitur Google Login di aplikasi Flutter kamu. Panduan ini dibuat terarah, langsung ke intinya, dan sangat mudah diikuti bahkan jika kamu baru pertama kali mencoba.

Ikuti urutan langkah di bawah ini dengan sangat teliti. Jangan melompati satu langkah pun!

--------------------------------------------------------------------------------
LANGKAH 1: MENYIAPKAN BAHAN (PUBSPEC.YAML)

Pertama, kita harus memberi tahu Flutter bahwa kita butuh bantuan plugin Google dan Firebase.
1. Buka file pubspec.yaml di folder utama proyek kamu.
2. Cari bagian dependencies dan pastikan baris berikut sudah ada:

dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.4.0
  firebase_auth: ^5.2.1
  cloud_firestore: ^5.4.2
  google_sign_in: ^6.2.1

3. Perhatikan penulisan spasi. Pastikan sejajar dengan paket lainnya (biasanya menjorok 2 spasi dari kata dependencies).
4. Setelah menambahkannya, simpan file tersebut (Ctrl + S).
5. Buka terminal di VS Code atau Android Studio, lalu ketik perintah:
   flutter pub get
   Ini gunanya untuk mendownload semua bahan yang kita butuhkan tadi.

--------------------------------------------------------------------------------
LANGKAH 2: AKTIFKAN GOOGLE LOGIN DI FIREBASE CONSOLE

Sekarang kita atur izin di sisi server (Firebase). Tanpa ini, Google tidak akan mau membagi data penggunanya ke aplikasi kita karena dianggap tidak dikenal.

1. Buka website: console.firebase.google.com
2. Masuk menggunakan akun Gmail kamu.
3. Pilih proyek kamu: geges-smartbarber.
4. Di bilah menu sebelah kiri, cari menu Build dan klik Authentication.
5. Klik tab Sign-in method di bagian atas layar.
6. Klik tombol Add new provider.
7. Pilih Google dari daftar yang muncul.
8. Geser tombol Enable menjadi aktif (warna biru).
9. Pada bagian Project support email, klik kotak pilihan dan pilih email kamu.
10. Klik tombol Save yang berwarna biru.

Langkah ini wajib dilakukan sekali saja per proyek. Jika tidak, setiap kali user mencoba login, mereka akan mendapatkan pesan error "Developer Error" atau "Sign in failed".

--------------------------------------------------------------------------------
LANGKAH 3: MENDAFTARKAN SIDIK JARI APLIKASI (SHA-1)

Google butuh bukti bahwa aplikasi yang berjalan di laptopmu adalah aplikasi resmi milikmu. Bukti itu disebut kode SHA-1. Ini adalah bagian paling krusial.

Cara mendapatkan kode SHA-1 di komputer kamu:
1. Buka terminal di folder proyek kamu.
2. Masuk ke folder android dengan mengetik perintah: cd android
3. Jalankan perintah ini untuk memunculkan sidik jari digital:
   Jika kamu pakai Windows: gradlew signingReport
   Jika kamu pakai Mac atau Linux: ./gradlew signingReport
4. Tunggu beberapa detik sampai banyak tulisan berhenti muncul di layar hitam.
5. Scroll (gulir) ke atas pelan-pelan.
6. Cari blok teks yang bertuliskan Variant: debug.
7. Di bawahnya, cari tulisan SHA1: diikuti deretan angka dan huruf (Contoh: 7E:26:92:EF:82...).
8. Sorot (blok) kode tersebut dengan teliti, lalu Copy (Ctrl + C).

Cara mendaftarkan kode tersebut ke Firebase:
1. Di website Firebase, klik ikon Gerigi (Project Settings) di pojok kiri atas.
2. Pilih menu Project settings.
3. Scroll ke bawah sampai bagian Your apps.
4. Pilih ikon Android (biasanya ada nama paket seperti com.example.geges_smartbarber).
5. Klik tombol Add fingerprint.
6. Paste kode SHA-1 yang tadi kamu copy ke dalam kotak yang tersedia.
7. Klik Save.

--------------------------------------------------------------------------------
LANGKAH 4: KONFIGURASI FILE (GOOGLE-SERVICES.JSON)

Aplikasi kamu butuh file "surat izin" agar bisa mengenali database Firebase.
1. Masih di halaman Project Settings tadi, cari tombol download bertuliskan google-services.json.
2. Klik tombol tersebut dan simpan filenya di komputermu.
3. Buka folder proyek kamu melalui File Explorer atau VS Code.
4. Pindahkan file tersebut ke lokasi berikut:
   android -> app -> (taruh di sini)
   Jangan menaruhnya di folder android saja, harus masuk ke dalam folder app.
   Pastikan namanya persis google-services.json (tidak ada angka 1 atau 2 di belakangnya).

--------------------------------------------------------------------------------
LANGKAH 5: MENGINISIALISASI FIREBASE DI MAIN.DART

Sebelum fitur login bisa dipakai, aplikasi harus menyalakan mesin Firebase saat pertama kali dibuka.
1. Buka file lib/main.dart.
2. Pastikan fungsi main kamu terlihat seperti ini:

void main() async {
  // Pastikan widget Flutter sudah siap
  WidgetsFlutterBinding.ensureInitialized();
  
  // Nyalakan mesin Firebase
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

Jangan lupa tambahkan import di bagian paling atas agar Flutter mengenal perintah Firebase:
import 'package:firebase_core/firebase_core.dart';

--------------------------------------------------------------------------------
LANGKAH 6: MENULIS LOGIKA LOGIN (AUTH_SERVICE.DART)

Sekarang kita buat fungsinya. Buka file lib/services/auth_service.dart.
Kita akan membuat fungsi yang melakukan proses "Salaman" antara aplikasi, Google, dan Firebase.

Future<Map<String, dynamic>> signInWithGoogle() async {
  try {
    // 1. Munculkan jendela pilih akun Google di layar HP
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    
    // Jika user menekan tombol 'kembali' atau membatalkan, kita berhenti di sini
    if (googleUser == null) {
      return {'success': false, 'message': 'Login dibatalkan oleh pengguna.'};
    }

    // 2. Ambil detail tiket (autentikasi) dari akun yang dipilih
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // 3. Buat paket kredensial (tiket khusus) untuk dikirim ke Firebase
    // accessToken adalah kunci untuk akses data, idToken adalah identitas user
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // 4. Tukarkan tiket tersebut ke Firebase agar user dianggap resmi masuk
    final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user != null) {
      // 5. Simpan atau perbarui data user ke database Firestore
      // Ini agar kita punya catatan siapa saja pelanggan kita di database
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': user.displayName,
        'email': user.email,
        'role': 'customer', // secara otomatis menjadi pelanggan
        'last_login': FieldValue.serverTimestamp(),
        'photo_url': user.photoURL, // ambil foto profil dari Google
      }, SetOptions(merge: true)); // gunakan merge agar data lain tidak terhapus

      return {'success': true, 'role': 'customer'};
    }
    
    return {'success': false, 'message': 'Gagal mengambil data pengguna.'};
  } catch (e) {
    // Jika ada error, kirim pesan errornya agar kita bisa tahu masalahnya
    return {'success': false, 'message': 'Terjadi kesalahan: $e'};
  }
}

--------------------------------------------------------------------------------
LANGKAH 7: MEMBUAT TOMBOL LOGIN DI LAYAR (UI)

Agar user bisa mencoba, kita buatkan tombol yang cantik di halaman login.
Gunakan widget ini di dalam file login_screen.dart kamu:

Widget buildGoogleButton(BuildContext context) {
  return OutlinedButton(
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: () async {
      // Panggil fungsi login yang sudah kita buat tadi
      final result = await AuthService().signInWithGoogle();

      if (result['success']) {
        // Jika sukses, bawa user ke halaman Dashboard (Home)
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // Jika gagal, beritahu user masalahnya apa melalui SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    },
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.login, color: Colors.black), 
        SizedBox(width: 12),
        Text(
          'Masuk dengan Google',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

--------------------------------------------------------------------------------
LANGKAH 8: MENGECEK SESI (AUTO-LOGIN)

Seorang murid yang pintar akan bertanya: "Bagaimana jika user sudah pernah login?"
Kita tidak ingin user login terus-menerus setiap kali buka aplikasi.

Di file main.dart, kamu bisa mengecek status login user:

Widget startScreen = const LoginScreen();
if (FirebaseAuth.instance.currentUser != null) {
  startScreen = const HomeScreen();
}

Ini akan membuat user langsung masuk ke Home jika mereka belum logout.

--------------------------------------------------------------------------------
LANGKAH 9: CARA KELUAR (LOGOUT)

Jangan lupa berikan cara untuk keluar agar user merasa aman.
Tambahkan fungsi ini di AuthService kamu:

Future<void> logOut() async {
  // Keluar dari Firebase
  await FirebaseAuth.instance.signOut();
  // Keluar dari sesi Google (agar saat login lagi, user bisa pilih akun lain)
  await GoogleSignIn().signOut();
}

--------------------------------------------------------------------------------
LANGKAH 10: CHECKLIST VERIFIKASI FINAL

Sebelum kamu menjalankan aplikasi, pastikan checklist ini sudah tercentang:
- [ ] Firebase Core, Auth, Firestore, dan Google Sign In ada di pubspec.yaml.
- [ ] Provider Google di Firebase Console sudah "Enabled".
- [ ] Email Support sudah dipilih di Firebase Console.
- [ ] Kode SHA-1 dari laptopmu sudah didaftarkan di Project Settings.
- [ ] File google-services.json sudah berada di folder android/app/.
- [ ] Firebase.initializeApp() sudah dipanggil di fungsi main().

--------------------------------------------------------------------------------
SOLUSI JIKA TERJADI ERROR (PENYELAMAT MURID)

Masalah: Muncul pesan "Developer Error" atau jendela pilih email langsung tertutup.
Diagnosa: Ini biasanya karena kode SHA-1 kamu belum didaftarkan di Firebase atau kamu menggunakan laptop yang berbeda dengan saat mendaftarkan SHA-1 tadi.
Solusi: Ulangi Langkah 3. Pastikan tidak ada spasi yang tertinggal saat copy-paste kode SHA-1.

Masalah: Error saat menjalankan 'flutter pub get'.
Diagnosa: Biasanya karena masalah koneksi internet atau ada salah ketik (typo) di file pubspec.yaml.
Solusi: Periksa kembali penulisan nama paket dan versinya. Pastikan barisnya lurus dan tidak menjorok ke dalam terlalu banyak.

Masalah: Data user tidak muncul di database Firestore.
Diagnosa: Mungkin kamu belum mengaktifkan database Firestore di website Firebase.
Solusi: Buka website Firebase, klik menu Firestore Database di sebelah kiri, lalu klik tombol Create Database. Pilih mode "Start in test mode" agar bisa langsung dicoba tanpa aturan rumit.

--------------------------------------------------------------------------------
PENUTUP

Itulah cara lengkap dan terarah untuk memasang Google Login. Memang terlihat panjang, tapi jika kamu mengikutinya satu per satu tanpa terburu-buru, pasti berhasil.

Tips dari saya: Jangan pernah menghafal kodingannya. Cukup pahami alurnya:
1. Daftar di Firebase (Dapatkan Izin).
2. Daftar di HP/Laptop (Dapatkan Identitas SHA-1).
3. Hubungkan dengan Kode (Buat Fungsinya).

Selamat mencoba dan selamat berkarya dengan aplikasi barumu! Jika ada error, baca pesan errornya baik-baik, biasanya di sana sudah ada petunjuk solusinya. Jangan menyerah, setiap programmer hebat dulunya adalah pemula yang berani menghadapi error. Terima kasih sudah mengikuti panduan ini sampai selesai. Semoga sukses!
