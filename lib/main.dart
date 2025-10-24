import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; 

// Import LoginScreen yang sudah Anda buat di Fase 2
import 'package:geges_smartbarber/screens/login_screen.dart'; 

void main() async {
  // Wajib dipanggil sebelum inisialisasi Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  // KONEKSI UTAMA KE FIREBASE
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("--- Firebase connected successfully! ---"); // Pesan konfirmasi
  } catch (e) {
    // Jika gagal, tampilkan error di console
    print("!!! Error initializing Firebase: $e !!!");
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GEGES SmartBarber',
      // Atur Tema Gelap Sesuai Desain
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(primary: Colors.deepPurple), // Tema gelap
        // Tambahkan konfigurasi tema lain sesuai desain 52027.jpg
      ),
      // Ganti HOME ke LoginScreen
      home: const LoginScreen(), 
    );
  }
}