import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
// Import halaman Onboarding (sesuai langkah terakhir kita)
import 'package:geges_smartbarber/screens/onboarding_screen.dart'; 

void main() async {
  // Pastikan semua binding siap
  WidgetsFlutterBinding.ensureInitialized();
  
  
  // Inisialisasi format tanggal/waktu Indonesia (untuk AppointmentScreen nanti)
  await initializeDateFormatting('id_ID', null); 
  
  // Inisialisasi Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("--- Firebase connected successfully! ---"); 
  } catch (e) {
    print("!!! Error initializing Firebase: $e !!!");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Definisikan warna tema Coklat Anda di sini (sesuai Figma)
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kBlackBackground = Colors.black;
  static const Color kDarkGrey = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GEGES SmartBarber',
      debugShowCheckedModeBanner: false, // Matikan banner debug

      // --- TEMA APLIKASI (DISESUAIKAN DENGAN FIGMA) ---
      theme: ThemeData.dark().copyWith(
        primaryColor: kBrownAccent, // Warna utama
        scaffoldBackgroundColor: kBlackBackground, // Latar belakang hitam pekat
        
        // Atur ColorScheme
        colorScheme: const ColorScheme.dark(
          primary: kBrownAccent, 
          secondary: kBrownAccent,
          surface: kDarkGrey, // Warna latar 'cards' atau 'input fields'
          onPrimary: Colors.black, // Teks di atas tombol coklat
          onSurface: Colors.white, // Teks utama
        ),
        
        // Tema Tombol (Agar semua ElevatedButton otomatis Coklat)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrownAccent, // Tombol Coklat
            foregroundColor: Colors.black, // Teks Hitam (kontras)
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )
          ),
        ),
        
        // Tema Input Field (agar sesuai desain Login/Register)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kDarkGrey,
          hintStyle: TextStyle(color: Colors.grey.shade600),
          prefixIconColor: Colors.grey.shade600,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kBrownAccent, width: 1.5), // Highlight coklat
          ),
        ),

        // Tema AppBar (jika digunakan)
        appBarTheme: const AppBarTheme(
          backgroundColor: kBlackBackground,
          elevation: 0, // Tanpa bayangan
        ),
      ),
      // --- AKHIR TEMA ---

      // Mulai dari OnboardingScreen (sesuai langkah terakhir Anda)
      home: const OnboardingScreen(), 
    );
  }
}