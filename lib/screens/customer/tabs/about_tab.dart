import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';

class AboutTab extends StatelessWidget {
  final Barbershop shop;

  const AboutTab({super.key, required this.shop});

  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Location ---
          const Text(
            'Location',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined, color: kBrownAccent, size: 28),
            title: Text(
              shop.addres,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const Divider(color: Colors.white12),

          // --- Working Hours ---
          const SizedBox(height: 16),
          const Text(
            'Working Hours',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time_outlined, color: kBrownAccent, size: 28),
            title: Text(
              'Mon - Sun (${shop.openHour}:00 - ${shop.closeHour}:00)',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const Divider(color: Colors.white12),

          // --- Facilities ---
          if (shop.facilities.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Facilities',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: shop.facilities.map((f) => _buildFacilityBadge(f)).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
          ],

          // --- Gallery / Album ---
          if (shop.galleryUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Barbershop Album',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shop.galleryUrls.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final img = shop.galleryUrls[index];
                return GestureDetector(
                  onTap: () => _showImagePreview(context, img),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(base64Decode(img), fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFacilityBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBrownAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: kBrownAccent, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, String base64) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.memory(base64Decode(base64))),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}