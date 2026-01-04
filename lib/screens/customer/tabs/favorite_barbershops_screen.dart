import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore

// Import model Barbershop dan screen Detail Anda yang sudah ada
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/screens/customer/tabs/barbershop_detail_screen.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

class FavoriteBarbershopsScreen extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final String? testUserId;

  const FavoriteBarbershopsScreen({
    super.key,
    this.firestore,
    this.testUserId,
  });

  @override
  State<FavoriteBarbershopsScreen> createState() =>
      _FavoriteBarbershopsScreenState();
}

class _FavoriteBarbershopsScreenState extends State<FavoriteBarbershopsScreen> {
  // Theme colors
  static const Color kBrownAccent = Color(0xFFB9976E);
  static const Color kSurface = Color(0xFF1B1B1B);
  static const Color kCardColor = Color(0xFF2C2C2C);
  static const Color kTextGrey = Color(0xFFB0B0B0);
  static const Color kRedDanger = Color(0xFFDC3545);
  static const Color kTextBlack = Color(0xFF1B1B1B);

  late final BarbershopService _barbershopService;
  late final String? _userId;

  List<Barbershop> _favoriteBarbershops = [];
  bool _isLoading = true;
  Map<String, String> _serviceNames = {};

  @override
  void initState() {
    super.initState();
    _barbershopService = BarbershopService(firestore: widget.firestore);
    _userId = widget.testUserId ?? FirebaseAuth.instance.currentUser?.uid;
    _loadFavorites();
    _fetchServiceNames();
  }

  Future<void> _fetchServiceNames() async {
    try {
      final services = await _barbershopService.getAllServices();
      if (mounted) {
        setState(() {
          _serviceNames = {for (var s in services) s.id: s.name};
        });
      }
    } catch (e) {
      debugPrint("Error fetching service names: $e");
    }
  }

  Future<void> _loadFavorites() async {
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final results = await _barbershopService.getFavoriteBarbershops(_userId);
    if (mounted) {
      setState(() {
        _favoriteBarbershops = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromFavorites(Barbershop shop) async {
    if (_userId == null) return;

    try {
      await _barbershopService.toggleFavorite(_userId, shop.id);
      
      setState(() {
        _favoriteBarbershops.removeWhere((s) => s.id == shop.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${shop.name} dihapus dari favorit.'),
            backgroundColor: kBrownAccent,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghapus dari favorit.'),
            backgroundColor: kRedDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text(
          'Favorite Barbershop',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: kBrownAccent),
            )
          : _favoriteBarbershops.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, color: kTextGrey, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada barbershop favorit.',
                        style: TextStyle(color: kTextGrey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  color: kBrownAccent,
                  backgroundColor: kCardColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _favoriteBarbershops.length,
                    itemBuilder: (context, index) {
                      return _buildBarbershopCard(_favoriteBarbershops[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildBarbershopCard(Barbershop shop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              // Navigasi ke detail barbershop dan tunggu hasil (jika ada update favorit di sana)
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BarbershopDetailScreen(barbershop: shop),
                ),
              );
              _loadFavorites(); // Refresh list saat kembali
            },
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: CachedNetworkImage(
                imageUrl: shop.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: kSurface,
                  child: const Center(
                    child: CircularProgressIndicator(color: kBrownAccent, strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: kSurface,
                  child: const Center(
                    child: Icon(
                      Icons.storefront,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        shop.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.favorite,
                        color: kRedDanger,
                        size: 28,
                      ),
                      onPressed: () => _removeFromFavorites(shop),
                      tooltip: 'Hapus dari Favorit',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  shop.addres,
                  style: TextStyle(color: kTextGrey, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: kBrownAccent, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      shop.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: shop.services
                      .where((s) => _serviceNames.containsKey(s))
                      .map((s) => _buildTagChip(s))
                      .toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BarbershopDetailScreen(barbershop: shop),
                        ),
                      ).then((_) => _loadFavorites());
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
                      'Book Now',
                      style: TextStyle(
                        fontSize: 16,
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
    );
  }

  Widget _buildTagChip(String serviceId) {
    final label = _serviceNames[serviceId] ?? serviceId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
