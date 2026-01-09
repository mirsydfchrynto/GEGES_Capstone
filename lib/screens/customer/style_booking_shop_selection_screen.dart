import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/screens/customer/appointment_screen.dart';
import 'package:geges_smartbarber/widgets/app_image.dart';

class StyleBookingShopSelectionScreen extends StatefulWidget {
  final String styleNote;
  
  const StyleBookingShopSelectionScreen({super.key, required this.styleNote});

  @override
  State<StyleBookingShopSelectionScreen> createState() => _StyleBookingShopSelectionScreenState();
}

class _StyleBookingShopSelectionScreenState extends State<StyleBookingShopSelectionScreen> {
  final BarbershopService _barbershopService = BarbershopService();
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);
  static const Color kSurface = Colors.black;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text("Pilih Barbershop", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Barbershop>>(
        future: _barbershopService.getAllBarbershops(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kBrownAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Gagal memuat data: ${snapshot.error}", style: const TextStyle(color: Colors.white54)));
          }
          final shops = snapshot.data ?? [];
          if (shops.isEmpty) {
            return const Center(child: Text("Tidak ada barbershop tersedia.", style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shop = shops[index];
              return _buildShopCard(shop);
            },
          );
        },
      ),
    );
  }

  Widget _buildShopCard(Barbershop shop) {
    return GestureDetector(
      onTap: shop.isOpen 
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppointmentScreen(
                  barbershop: shop,
                  initialStyleNote: widget.styleNote,
                ),
              ),
            )
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20.0),
        decoration: BoxDecoration(
          color: kDarkGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: AppImage(
                  imageUrl: shop.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: const Icon(Icons.store, color: Colors.white24, size: 50),
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!shop.isOpen)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: const Text(
                            "TUTUP",
                            style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    shop.addres,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.content_cut, color: kBrownAccent, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        "Booking dengan gaya ini",
                        style: TextStyle(color: kBrownAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
