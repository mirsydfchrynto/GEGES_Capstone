// NAMA FILE: lib/screens/customer/barbershop_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
// Import Halaman Tujuan (Booking)
import 'package:geges_smartbarber/screens/customer/appointment_screen.dart';
// Import 3 Tab
import 'package:geges_smartbarber/screens/customer/tabs/about_tab.dart';
import 'package:geges_smartbarber/screens/customer/tabs/services_tab.dart';
import 'package:geges_smartbarber/screens/customer/tabs/review_tab.dart';

// --- IMPORT BARU ---
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
// ------------------

class BarbershopDetailScreen extends StatefulWidget {
  final Barbershop barbershop;
  const BarbershopDetailScreen({super.key, required this.barbershop});

  @override
  State<BarbershopDetailScreen> createState() => _BarbershopDetailScreenState();
}

class _BarbershopDetailScreenState extends State<BarbershopDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Warna Tema (sesuai main.dart)
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);
  static const Color kSurface = Colors.black; // Menambahkan warna surface

  // --- BARU: State untuk data dinamis ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  int _reviewCount = 0;
  bool _isLoadingReviews = true;

  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  // ---------------------------------

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // --- BARU: Panggil fungsi untuk mengambil data dinamis ---
    _fetchReviewCount();
    _checkIfFavorite();
    // ----------------------------------------------------
  }

  // --- BARU: Fungsi ambil data jumlah review ---
  Future<void> _fetchReviewCount() async {
    try {
      // Gunakan .count() agar lebih efisien (tidak perlu download semua dokumen)
      final snapshot = await _firestore
          .collection('reviews')
          .where('barbershopId', isEqualTo: widget.barbershop.id)
          .count()
          .get();

      if (mounted) {
        setState(() {
          _reviewCount = snapshot.count!;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching review count: $e");
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
          _reviewCount = 0; // Default jika error
        });
      }
    }
  }

  // --- BARU: Fungsi cek status favorit ---
  Future<void> _checkIfFavorite() async {
    if (_userId == null) {
      if (mounted) setState(() => _isLoadingFavorite = false);
      return;
    }
    try {
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        // Asumsi Anda menyimpan favorit dalam array 'favoriteBarbershops'
        final favorites = List<String>.from(
          userDoc.data()?['favoriteBarbershops'] ?? [],
        );
        if (mounted) {
          setState(() {
            _isFavorite = favorites.contains(widget.barbershop.id);
            _isLoadingFavorite = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingFavorite = false);
      }
    } catch (e) {
      debugPrint("Error checking favorite: $e");
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  // --- BARU: Fungsi untuk toggle favorit ---
  Future<void> _toggleFavorite() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan login untuk menambah favorit.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_isLoadingFavorite) return; // Mencegah double-tap

    setState(() {
      _isLoadingFavorite = true; // Mulai loading
    });

    final docRef = _firestore.collection('users').doc(_userId);

    try {
      if (_isFavorite) {
        // Hapus dari favorit
        await docRef.update({
          'favoriteBarbershops': FieldValue.arrayRemove([widget.barbershop.id]),
        });
        if (mounted) setState(() => _isFavorite = false);
        _showSnackbar('Dihapus dari favorit', Colors.grey);
      } else {
        // Tambah ke favorit
        await docRef.update({
          'favoriteBarbershops': FieldValue.arrayUnion([widget.barbershop.id]),
        });
        if (mounted) {
          setState(() => _isFavorite = true);
        }
        _showSnackbar('Ditambahkan ke favorit', kBrownAccent);
      }
    } catch (e) {
      debugPrint("Error toggling favorite: $e");
      _showSnackbar('Gagal mengubah favorit', Colors.redAccent);
      // Opsional: Balikkan state jika gagal
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingFavorite = false); // Selesai loading
      }
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ------------------------------------------

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Navigasi ke halaman booking
  void _goToAppointment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentScreen(barbershop: widget.barbershop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface, // Menggunakan warna kSurface
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // 1. AppBar yang bisa collapse (SliverAppBar)
            SliverAppBar(
              expandedHeight: 300.0,
              floating: false,
              pinned: true,
              backgroundColor: kDarkGrey,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),

              // --- Tombol Favorite (DISESUAIKAN) ---
              actions: [
                _isLoadingFavorite
                    ? const Padding(
                        // Tampilkan loading kecil
                        padding: EdgeInsets.all(18.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.redAccent : Colors.white,
                        ),
                        onPressed: _toggleFavorite, // Panggil fungsi toggle
                      ),
              ],
              // ---------------------------------

              // --- Gambar Latar (DISESUAIKAN) ---
              flexibleSpace: FlexibleSpaceBar(
                background: CachedNetworkImage(
                  imageUrl: widget.barbershop.imageUrl,
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: 0.3), // Overlay gelap
                  colorBlendMode: BlendMode.darken,
                  placeholder: (context, url) => Container(color: kDarkGrey),
                  errorWidget: (context, url, error) => Container(
                    color: kDarkGrey,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: kBrownAccent,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
              // ---------------------------------

              // 2. TabBar (Menempel di bawah AppBar)
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: kBrownAccent,
                indicatorWeight: 3.0,
                labelColor: kBrownAccent,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'About'),
                  Tab(text: 'Services'),
                  Tab(text: 'Review'),
                ],
              ),
            ),
          ];
        },

        // 3. Konten (Body) dari Tab yang dipilih
        body: TabBarView(
          controller: _tabController,
          children: [
            AboutTab(shop: widget.barbershop),
            ServicesTab(shop: widget.barbershop),
            ReviewTab(shop: widget.barbershop),
          ],
        ),
      ),

      // 4. Tombol "Book Now" (Floating di bawah)
      bottomNavigationBar: _buildStickyFooter(context),
    );
  }

  // Widget untuk Footer (Info Barbershop & Tombol Book Now)
  Widget _buildStickyFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0)
          .copyWith(
            bottom:
                MediaQuery.of(context).padding.bottom +
                16.0, // Padding aman area bawah HP
          ),
      decoration: const BoxDecoration(
        color: kDarkGrey,
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Info Kiri (Sesuai Desain)
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Agar tinggi container pas
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.barbershop.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: kBrownAccent, size: 16),
                    const SizedBox(width: 4),
                    // --- Teks Review (DISESUAIKAN) ---
                    Text(
                      _isLoadingReviews
                          ? "${widget.barbershop.rating} (Loading...)"
                          : "${widget.barbershop.rating} ($_reviewCount Reviews)",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    // ---------------------------------
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16), // Beri jarak
          // Tombol Kanan
          ElevatedButton(
            onPressed: _goToAppointment, // Navigasi ke Halaman Booking
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: const Text('Book Now'),
          ),
        ],
      ),
    );
  }
}
