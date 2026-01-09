import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geges_smartbarber/screens/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Warna Coklat Khas Project
  static const Color kBrownAccent = Color(0xFFC3A47B);

  @override
  void initState() {
    super.initState();

    // Timer untuk navigasi ke halaman berikutnya
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthGate(),
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrownAccent, // Latar belakang coklat sesuai permintaan
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/ivon.png',
              width: 100, // Ukuran logo tetap agar konsisten dengan estimasi native
              height: 100,
            ),
            const SizedBox(height: 24),
            // Opsional: Nama App atau Loading Indicator jika diinginkan
            // Tapi user minta simpel dan elegan, jadi logo saja sudah cukup.
          ],
        ),
      ),
    );
  }
}
