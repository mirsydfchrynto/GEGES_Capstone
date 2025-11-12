import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Import model Barbershop dan screen Detail Anda yang sudah ada
import 'package:geges_smartbarber/models/barbershop.dart'; 
import 'package:geges_smartbarber/screens/customer/tabs/barbershop_detail_screen.dart'; 

class FavoriteBarbershopsScreen extends StatefulWidget {
  const FavoriteBarbershopsScreen({super.key});

  @override
  State<FavoriteBarbershopsScreen> createState() => _FavoriteBarbershopsScreenState();
}

class _FavoriteBarbershopsScreenState extends State<FavoriteBarbershopsScreen> {
  // Theme colors
  static const Color kBrownAccent = Color(0xFFB9976E); 
  static const Color kSurface = Color(0xFF1B1B1B); 
  static const Color kCardColor = Color(0xFF2C2C2C); 
  static const Color kTextGrey = Color(0xFFB0B0B0); 
  static const Color kRedDanger = Color(0xFFDC3545); 
  static const Color kTextBlack = Color(0xFF1B1B1B); 

  // Data dummy (ganti dengan FutureBuilder/StreamBuilder untuk data Firestore)
  final List<Barbershop> _favoriteBarbershops = [
    Barbershop(
      id: 'febrian_id_1',
      name: 'Febrian Barbershop',
      addres: 'Mejasem Barat, Tegal',
      imageUrl: 'https://images.unsplash.com/photo-1621607567117-91f7c006c9a3?q=80&w=300&h=180&fit=crop',
      rating: 4.8,
      openHour: 9,
      closeHour: 21,
      services: ['Haircut', 'Shave'],
      isOpen: true,
    ),
    Barbershop(
      id: 'doels_id_2',
      name: 'Doels Barbershop',
      addres: 'Slawi, Tegal',
      imageUrl: 'https://images.unsplash.com/photo-1600880292203-757bb62b2baf?q=80&w=300&h=180&fit=crop',
      rating: 4.5,
      openHour: 10,
      closeHour: 22,
      services: ['Haircut', 'Coloring'],
      isOpen: false,
    ),
  ];

  // Fungsi placeholder untuk menghapus dari favorit
  void _removeFromFavorites(Barbershop shop) {
    setState(() {
      _favoriteBarbershops.removeWhere((s) => s.id == shop.id);
    });
    // Di sini Anda akan menambahkan logika untuk menghapus dari Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${shop.name} dihapus dari favorit.'),
        backgroundColor: kBrownAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Favorite Barbershop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), 
      ),
      body: _favoriteBarbershops.isEmpty
          ? Center(
              child: Text(
                'Belum ada barbershop favorit.',
                style: TextStyle(color: kTextGrey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _favoriteBarbershops.length,
              itemBuilder: (context, index) {
                return _buildBarbershopCard(_favoriteBarbershops[index]);
              },
            ),
    );
  }

  Widget _buildBarbershopCard(Barbershop shop) {
    // GestureDetector hanya digunakan untuk navigasi ke detail
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
             onTap: () {
                // Navigasi ke detail barbershop
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BarbershopDetailScreen(barbershop: shop),
                  ),
                );
              },
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: CachedNetworkImage(
                imageUrl: shop.imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: kSurface, child: const Center(child: Icon(Icons.storefront, color: Colors.white54, size: 48))),
                errorWidget: (context, url, error) => Container(color: kSurface, child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48))),
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
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Tombol untuk menghapus dari favorit
                    IconButton(
                      icon: const Icon(Icons.favorite, color: kRedDanger, size: 28),
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
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      " (133)", // Jumlah review (placeholder)
                      style: TextStyle(color: kTextGrey, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                       // Navigasi ke detail (untuk booking)
                       Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BarbershopDetailScreen(barbershop: shop),
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
                      'Book Now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
}