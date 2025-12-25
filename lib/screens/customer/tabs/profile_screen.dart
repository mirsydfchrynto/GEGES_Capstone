// lib/screens/customer/tabs/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geges_smartbarber/screens/customer/tabs/favorite_barbershops_screen.dart';

// --- IMPORT DARI ITERASI SEBELUMNYA ---
import '../../../models/user_data.dart'; // Model UserData yang sudah kita buat
import '../edit_profile_screen.dart'; // EditProfileScreen yang sudah kita buat

// Pastikan path import ke screens lain ini sudah benar di project Anda
import '../../login_screen.dart';
import 'my_bookings_screen.dart'; // Akan digunakan sebagai History Screen
import 'package:geges_smartbarber/utils/links.dart';
// Saya asumsikan ini adalah FavoriteBarbersScreen (bukan barbershop)

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

  // --- MENGGUNAKAN MODEL USERDATA YANG SUDAH KITA BUAT ---
  UserData _currentUser = UserData(
    uid: FirebaseAuth.instance.currentUser?.uid ?? 'guest_uid',
    name: "Tegar Nugraha", // Placeholder awal
    role: "customer",
  );
  String _userEmail = "tegar.nugraha@example.com"; // Placeholder
  String? _userPhotoUrl; // Placeholder

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Ambil data dari Firebase Authentication & simulasikan pengambilan UserData
      // Di aplikasi nyata, Anda akan fetch UserData.fromFirestore(doc) di sini
      setState(() {
        _currentUser = UserData(
          uid: user.uid,
          name: user.displayName ?? "anonymous",
          role: _currentUser
              .role, // Pertahankan role yang ada (atau fetch dari Firestore)
        );
        _userEmail = user.email ?? "Edit Profile";
        _userPhotoUrl = user.photoURL;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // Navigasi ke LoginScreen dan hapus semua rute sebelumnya
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // Fungsi baru untuk navigasi ke Edit Profile
  void _goToEditProfile() async {
    // Navigasi ke EditProfileScreen dan tunggu hasilnya
    final updatedUser = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(currentUser: _currentUser),
      ),
    );

    // Jika data UserData yang diperbarui dikembalikan, update state lokal
    if (updatedUser != null && updatedUser is UserData) {
      setState(() {
        _currentUser = updatedUser;
        // Asumsi email/photoUrl tidak berubah dari EditProfileScreen
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
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),

            // --- MENU UTAMA ---
            _buildMenuCard(
              title: 'History', // <--- DIGANTI DARI 'My Bookings' KE 'History'
              icon: Icons.history, // Menggunakan ikon history yang lebih sesuai
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
                // Ganti dengan FavoriteBarbersScreen (jika Anda menggunakan nama itu)

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FavoriteBarbershopsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // --- MENU BANTUAN ---
            _buildMenuCard(
              title: 'Help Centers',
              icon: Icons.help_outline,
              onTap: () {
                Links.openUrl(Links.helpCenter);
              },
            ),
            const SizedBox(height: 12),
            _buildMenuCard(
              title: 'Terms of Service',
              icon: Icons.description_outlined,
              onTap: () {
                Links.openUrl(Links.termsOfService);
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
            // Menggunakan CachedNetworkImage untuk foto profil dari URL (jika ada)
            backgroundImage:
                _userPhotoUrl != null && _userPhotoUrl!.startsWith('http')
                ? CachedNetworkImageProvider(_userPhotoUrl!)
                : null,
            child: (_userPhotoUrl == null || !_userPhotoUrl!.startsWith('http'))
                ? Icon(Icons.person, size: 30, color: kBrownAccent)
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser.name, // Menggunakan data dari state/UserData
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
            onPressed:
                _goToEditProfile, // Panggil fungsi navigasi ke EditProfileScreen
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
                // Open barbershop registration page
                Links.openUrl(Links.barbershopRegister);
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
