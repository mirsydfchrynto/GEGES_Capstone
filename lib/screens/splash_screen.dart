import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geges_smartbarber/screens/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Setup Animasi Fade-In
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Latar belakang hitam sesuai tema native
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/ivon_high.png',
                width: 65, // Ukuran lebih kecil & profesional (seperti Shopee/Top Apps)
                height: 65,
              ),
              const SizedBox(height: 24),
              // Opsional: Nama App atau Loading Indicator jika diinginkan
              // Tapi user minta simpel dan elegan, jadi logo saja sudah cukup.
            ],
          ),
        ),
      ),
    );
  }
}
