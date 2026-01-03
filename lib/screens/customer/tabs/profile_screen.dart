import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geges_smartbarber/screens/customer/tabs/favorite_barbershops_screen.dart';
import 'package:geges_smartbarber/screens/customer/app_rating_screen.dart';
import 'package:geges_smartbarber/services/auth_service.dart';

// --- IMPORT DARI ITERASI SEBELUMNYA ---
import '../../../models/user_data.dart'; // Model UserData yang sudah kita buat
import '../edit_profile_screen.dart'; // EditProfileScreen yang sudah kita buat

// Pastikan path import ke screens lain ini sudah benar di project Anda
import '../../login_screen.dart';
import 'my_bookings_screen.dart'; // Akan digunakan sebagai History Screen
import 'package:geges_smartbarber/screens/tenant/tenant_registration_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Theme colors, disesuaikan agar 100% sesuai desain
  static const Color kBrownAccent = Color(0xFFB9976E); // Emas/coklat
  static const Color kSurface = Color(0xFF1B1B1B); // Background utama
  static const Color kCardColor = Color(0xFF2C2C2C); // Background kartu
  static const Color kRedDanger = Color(0xFFDC3545); // Merah untuk logout
  static const Color kTextGrey = Color(0xFFB0B0B0); // Teks abu-abu
  static const Color kTextBlack = Color(
    0xFF1B1B1B,
  ); // Teks hitam untuk tombol emas

  final AuthService _authService = AuthService();

  UserData _currentUser = UserData(
    uid: FirebaseAuth.instance.currentUser?.uid ?? 'guest_uid',
    name: "Loading...", 
    role: "customer",
  );
  String _userEmail = "..."; 

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await _authService.getUserById(user.uid);
      if (mounted && userData != null) {
        setState(() {
          _currentUser = userData;
          _userEmail = user.email ?? "";
        });
      }
    }
  }

  void _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _goToEditProfile() async {
    final updatedUser = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(currentUser: _currentUser),
      ),
    );

    if (updatedUser != null && updatedUser is UserData) {
      setState(() {
        _currentUser = updatedUser;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: kBrownAccent,
        backgroundColor: kCardColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),

              // --- MENU UTAMA ---
              _buildMenuCard(
                title: 'History',
                icon: Icons.history,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyBookingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildMenuCard(
                title: 'Favorite Barbers',
                icon: Icons.favorite_border,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoriteBarbershopsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // --- MENU RATING ---
              _buildMenuCard(
                title: 'Rating Aplikasi',
                icon: Icons.star_outline,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AppRatingScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildMenuCard(
                title: 'Terms of Service',
                icon: Icons.description_outlined,
                onTap: () {
                  Navigator.of(context).pushNamed('/legal/terms');
                },
              ),

              const SizedBox(height: 20),

              // --- TOMBOL LOGOUT ---
              ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kRedDanger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Log Out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              // --- PROMO CARD ---
              _buildBarbershopPromoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: kBrownAccent.withValues(alpha: 0.2),
            backgroundImage: _currentUser.photoBase64 != null
                ? MemoryImage(base64Decode(_currentUser.photoBase64!))
                : null,
            child: _currentUser.photoBase64 == null
                ? Icon(Icons.person, size: 30, color: kBrownAccent)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _userEmail,
                  style: TextStyle(color: kTextGrey, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Tombol Settings/Edit Profile
          IconButton(
            onPressed: _goToEditProfile,
            icon: Icon(Icons.settings, color: kTextGrey, size: 24),
          ),
        ],
      ),
    );
  }

  // ... (Widget _buildMenuCard dan _buildBarbershopPromoCard tetap sama) ...

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: kTextGrey, size: 24),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: kTextGrey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildBarbershopPromoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grow Your Barbershop with us',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join out network of Profesional Barbers',
            style: TextStyle(color: kTextGrey, fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to tenant registration screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TenantRegistrationScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrownAccent,
                foregroundColor: kTextBlack,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Register my Barbershop',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
