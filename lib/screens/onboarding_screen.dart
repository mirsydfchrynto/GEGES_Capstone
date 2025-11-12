import 'package:flutter/material.dart';
import 'package:geges_smartbarber/screens/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  // Data untuk 3 halaman (sesuai Figma Anda)
  final List<Map<String, String>> _onboardingData = [
    {
      "image": "assets/images/onboarding_clock.png", // Path dari Langkah 1
      "title": "Say Goodbye to Long Waits",
      "subtitle": "Book your spot in advance with GEGES and arrive just in time for your haircut."
    },
    {
      "image": "assets/images/onboarding_pin.png", // Path dari Langkah 1
      "title": "Find Nearby Barbers",
      "subtitle": "Discover the best barbershops in your area with ratings and reviews from real customers."
    },
    {
      "image": "assets/images/onboarding_bot.png", // Path dari Langkah 1
      "title": "Smart Assistant",
      "subtitle": "Get personalized recommendations and instant booking help through our AI chatbot."
    }
  ];

  // Warna Coklat/Tan dari desain Anda
  static const Color kBrownAccent = Color(0xFFC3A47B);
  
  // Fungsi untuk pindah ke Login (Versi Sederhana)
  void _navigateToLogin() {
    // Nanti kita akan tambahkan 'shared_preferences' di sini
    // Untuk saat ini, kita hanya pindah halaman
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Latar hitam pekat
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Konten Halaman (PageView)
            PageView.builder(
              controller: _pageController,
              itemCount: _onboardingData.length,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemBuilder: (context, index) {
                return _buildPageContent(_onboardingData[index]);
              },
            ),
            
            // 2. Tombol "Skip" (Sesuai Desain)
            Positioned(
              top: 10.0,
              right: 24.0,
              child: TextButton(
                onPressed: _navigateToLogin, // Skip langsung ke Login
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
            
            // 3. Kontrol Navigasi (Dots dan Tombol Next)
            Positioned(
              bottom: 40.0,
              left: 24.0,
              right: 24.0,
              child: Column(
                children: [
                  // Indikator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildPageIndicator(),
                  ),
                  const SizedBox(height: 40.0),
                  
                  // Tombol Next / Get Started
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _onboardingData.length - 1) {
                          // Halaman terakhir, navigasi ke Login
                          _navigateToLogin();
                        } else {
                          // Pindah ke halaman berikutnya
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrownAccent, // Warna Coklat
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: Text(
                        // Ganti teks di halaman terakhir
                        _currentPage == _onboardingData.length - 1 
                            ? 'Get Started' 
                            : 'Next',
                        style: const TextStyle(
                          color: Colors.black, // Font hitam di tombol
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget untuk konten di tengah (Icon, Title, Subtitle)
  Widget _buildPageContent(Map<String, String> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Lingkaran Ikon (Sesuai Desain)
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade900.withOpacity(0.5), // Lingkaran abu-abu transparan
              shape: BoxShape.circle,
            ),
            // Gunakan Image.asset untuk menampilkan ikon dari Figma
            child: Padding(
              padding: const EdgeInsets.all(40.0), // Sesuaikan ukuran ikon
              child: Image.asset(
                data['image']!,
                color: kBrownAccent, // Beri warna coklat pada ikon
              ),
            ),
          ),
          const SizedBox(height: 60.0),
          // Judul
          Text(
            data['title']!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16.0),
          // Subjudul
          Text(
            data['subtitle']!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5, // Jarak antar baris
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk membuat 3 dots indikator
  List<Widget> _buildPageIndicator() {
    List<Widget> list = [];
    for (int i = 0; i < _onboardingData.length; i++) {
      list.add(i == _currentPage ? _indicator(true) : _indicator(false));
    }
    return list;
  }

  // Widget untuk 1 dot
  Widget _indicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 6.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0, // Dot aktif lebih panjang
      decoration: BoxDecoration(
        color: isActive ? kBrownAccent : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}