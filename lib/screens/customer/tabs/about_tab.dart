// [ANDA BISA COPY PASTE MULAI DARI SINI]
// NAMA FILE: lib/screens/customer/tabs/about_tab.dart
import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';

class AboutTab extends StatelessWidget {
  // Ambil data Barbershop yang sudah ada
  final Barbershop shop;

  const AboutTab({super.key, required this.shop});

  // Warna Tema (sesuai main.dart)
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Bagian 1: Location (Sesuai about.png) ---
          const Text(
            'Location',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Placeholder Peta
          // Container(
          //   height: 150,
          //   decoration: BoxDecoration(
          //     color: kDarkGrey,
          //     borderRadius: BorderRadius.circular(15),
          //     image: const DecorationImage(
          //       // Placeholder peta (ganti dengan Google Maps nanti)
          //       image: NetworkImage('https://placehold.co/600x400/1E1E1E/6B6B6B?text=Map+Placeholder'),
          //       fit: BoxFit.cover,
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 16),
          // Alamat
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.location_on_outlined,
              color: kBrownAccent,
              size: 28,
            ),
            title: Text(
              shop.addres, // Ambil alamat dari data Barbershop
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const Divider(color: Colors.white12),

          // --- Bagian 2: Working Hours (Sesuai about.png) ---
          const SizedBox(height: 16),
          const Text(
            'Working Hours',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.access_time_outlined,
              color: kBrownAccent,
              size: 28,
            ),
            title: const Text(
              'Mon - Sun (09:00 AM - 21:00 PM)', // Data dummy sesuai desain
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const Divider(color: Colors.white12),

          // --- Bagian 3: Facilities (Sesuai about.png) ---
          const SizedBox(height: 16),
          const Text(
            'Facilities',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Grid 3x2
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true, // Wajib di dalam SingleChildScrollView
            physics:
                const NeverScrollableScrollPhysics(), // Wajib di dalam SingleChildScrollView
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildFacilityChip(Icons.wifi, 'Wifi'),
              _buildFacilityChip(Icons.ac_unit, 'AC'),
              _buildFacilityChip(Icons.local_parking, 'Car Park'),
              _buildFacilityChip(Icons.smoke_free, 'No Smoking'),
              _buildFacilityChip(Icons.chair, 'Waiting Area'),
              _buildFacilityChip(Icons.power, 'Charging'),
            ],
          ),
        ],
      ),
    );
  }

  // Widget helper untuk chip Fasilitas
  Widget _buildFacilityChip(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: kBrownAccent, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// [ANDA BISA COPY PASTE SAMPAI SINI]
