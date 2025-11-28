import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'package:geges_smartbarber/screens/onboarding_screen.dart';
import 'package:geges_smartbarber/services/notification_service.dart';
import 'package:geges_smartbarber/services/app_navigator.dart';

// ==========================================
// file: lib/main.dart
// deskripsi: entry point aplikasi flutter
// penjelasan:
//   - main() function adalah starting point aplikasi
//   - initialize firebase sebelum app dijalankan
//   - setup intl untuk format tanggal & waktu dalam bahasa indonesia
//   - konfigurasi tema global aplikasi (warna, style, dll)
//   - menjalankan widget tree dari myapp
// ==========================================

void main() async {
  // penjelasan widgetsfutterbinding:
  // - ensureInitialized() memastikan flutter binding sudah siap
  // - harus dijalankan sebelum await firebase initialization
  // - tanpa ini, firebase init bisa failed
  WidgetsFlutterBinding.ensureInitialized();
  
  // penjelasan initializeDateFormatting:
  // - setup locale untuk menampilkan tanggal dalam bahasa indonesia
  // - 'id_ID' adalah kode untuk indonesian locale
  // - ini penting untuk booking date formatting (contoh: "17 Nov 2025" bukan "Nov 17, 2025")
  // - intl package menyediakan formatting utk berbagai bahasa
  await initializeDateFormatting('id_ID', null); 
  
  // penjelasan firebase initialization:
  // - firebase adalah backend service untuk data & authentication
  // - initializeapp() menghubungkan aplikasi dengan firebase project
  // - DefaultFirebaseOptions.currentPlatform = auto-detect platform (ios/android/web)
  // - ini harus dijalankan pertama sebelum akses firestore, auth, storage, dll
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize notification service (FCM) after Firebase is ready
    try {
      await NotificationService.instance.init();
    } catch (_) {
      // non-fatal: continue even if notification init fails
    }
    // firebase initialization berhasil
  } catch (e) {
    // firebase initialization error (akan di-log via crashlytics nanti)
    rethrow;
  }
  
  // penjelasan runApp:
  // - runApp() menjalankan aplikasi flutter
  // - MyApp() adalah root widget dari aplikasi
  // - semua widget di bawah MyApp adalah app tree
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // ========================================
  // warna tema aplikasi
  // ========================================
  // penjelasan constant colors:
  // - colors ini adalah constants yang digunakan di seluruh aplikasi
  // - const berarti nilai tidak bisa diubah
  // - static berarti bisa diakses tanpa instance (MyApp.kBrownAccent)
  // - 0xFFC3A47B adalah hex color code RGB
  //   - FF = tidak transparan (opaque)
  //   - C3A47B = coklat tan color
  static const Color kBrownAccent = Color(0xFFC3A47B);      // warna coklat utama
  static const Color kBlackBackground = Colors.black;        // warna latar aplikasi
  static const Color kDarkGrey = Color(0xFF1E1E1E);          // warna abu-abu gelap untuk cards

  @override
  Widget build(BuildContext context) {
    // penjelasan materialapp:
    // - materialapp adalah root widget dari aplikasi
    // - ini setup material design theme, navigation, locale, dll
    // - title = nama aplikasi (muncul di app switcher / recent apps)
    // - debugShowCheckedModeBanner = true = tampilkan "debug" banner (garis merah)
    //   false = sembunyikan banner (production setting)
    // - theme = style untuk seluruh aplikasi
    // - home = starting screen yang ditampilkan pertama kali
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'GEGES SmartBarber',
      debugShowCheckedModeBanner: false,

      // =====================================================
      // ========== KONFIGURASI TEMA APLIKASI ===========
      // =====================================================
      // penjelasan themedata.dark():
      // - memberikan base theme dark mode
      // - copyWith() mengubah beberapa property dari base theme
      // - ini lebih efisien daripada membuat custom theme dari 0
      theme: ThemeData.dark().copyWith(
        // penjelasan primarycolor:
        // - warna utama yang digunakan untuk button, highlight, icon tertentu
        // - warna ini akan "dominan" di aplikasi
        primaryColor: kBrownAccent,
        
        // penjelasan scaffoldBackgroundColor:
        // - warna default background untuk semua scaffold di aplikasi
        // - scaffold adalah layout dasar dengan appbar, body, bottombar, dll
        // - ini mencegah setiap screen perlu set background color manual
        scaffoldBackgroundColor: kBlackBackground,
        
        // ========== colorScheme ==========
        // penjelasan colorscheme:
        // - mendefinisikan palet warna lengkap yang digunakan di seluruh app
        // - material design menggunakan colorscheme untuk konsistensi warna
        // - setiap color ada kontrasnya (on-color) untuk teks/icon di atasnya
        // - ini memastikan aksesibilitas (text contrast ratio)
        colorScheme: const ColorScheme.dark(
          // primary = warna utama untuk button, highlight, focused state
          primary: kBrownAccent,
          // secondary = warna alternatif untuk accent (tidak banyak dipakai di app ini)
          secondary: kBrownAccent,
          // surface = warna latar untuk card, dialog, dropdown, sheet
          surface: kDarkGrey,
          // onprimary = warna text/icon di atas primary color (harus contrast)
          onPrimary: Colors.black,
          // onsurface = warna text/icon di atas surface (default text color)
          onSurface: Colors.white,
        ),
        
        // ========== elevatedButtonTheme ==========
        // penjelasan elevatedbutton:
        // - elevated button adalah tombol "terangkat" dengan background
        // - ini tombol paling umum digunakan di app
        // - semua elevated button akan menggunakan style dari sini
        // - individual button bisa override style ini dengan styleFrom()
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            // backgroundcolor = warna isi tombol
            backgroundColor: kBrownAccent,
            // foregroundcolor = warna text/icon di dalam tombol
            foregroundColor: Colors.black,
            // shape = bentuk tombol
            shape: RoundedRectangleBorder(
              // borderradius = kelengkungan sudut (12 pixel)
              borderRadius: BorderRadius.circular(12),
            ),
            // padding = jarak antara text dan tepi tombol (inner spacing)
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            // textstyle = style untuk text di dalam tombol
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )
          ),
        ),
        
        // ========== inputDecorationTheme ==========
        // penjelasan input decoration:
        // - theme untuk style textfield (input box) di seluruh aplikasi
        // - filled = background diisi dengan color (jangan transparent)
        // - fillcolor = warna background field
        // - border = garis tepi field (outline)
        // - focusedborder = garis tepi saat field fokus (user sedang ketik)
        inputDecorationTheme: InputDecorationTheme(
          // filled = true = background field diisi dengan warna
          filled: true,
          // fillcolor = warna background field
          fillColor: kDarkGrey,
          // hintstyle = style untuk placeholder text saat field kosong
          hintStyle: TextStyle(color: Colors.grey.shade600),
          // prefixiconcolor = warna icon di sebelah kiri input
          prefixIconColor: Colors.grey.shade600,
          // border = garis tepi saat field tidak fokus
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // tidak ada garis
          ),
          // enabledborder = garis tepi saat field aktif tapi tidak fokus
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          // focusedborder = garis tepi saat user sedang ketik (fokus)
          // ini untuk highlighting field yang sedang diisi
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            // borderSide = garis dengan warna coklat & tebal 1.5
            borderSide: const BorderSide(color: kBrownAccent, width: 1.5),
          ),
        ),

        // ========== appBarTheme ==========
        // penjelasan appbartheme:
        // - theme untuk app bar (header di atas setiap halaman)
        // - backgroundcolor = warna latar app bar
        // - elevation = ketinggian bayangan (drop shadow)
        appBarTheme: const AppBarTheme(
          backgroundColor: kBlackBackground,
          // elevation 0 = tidak ada bayangan
          elevation: 0,
        ),
      ),
      // =====================================================
      // ========== AKHIR KONFIGURASI TEMA ===========
      // =====================================================

      // penjelasan home:
      // - halaman pertama yang ditampilkan saat aplikasi dibuka
      // - OnboardingScreen = layar pengenalan aplikasi untuk user baru
      // - jika user sudah pernah buka, bisa langsung ke LoginScreen
      // - (implementasi bisa menggunakan shared_preferences untuk check)
      home: const OnboardingScreen(), 
    );
  }
}