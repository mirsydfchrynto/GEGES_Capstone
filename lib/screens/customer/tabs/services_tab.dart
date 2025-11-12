// [ANDA BISA COPY PASTE MULAI DARI SINI]
// NAMA FILE: lib/screens/customer/tabs/services_tab.dart

import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:intl/intl.dart'; // Untuk format harga

class ServicesTab extends StatelessWidget {
  final Barbershop shop;
  // Format Rupiah (sesuai main.dart)
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0); 
  
  ServicesTab({super.key, required this.shop});

  // Data dummy untuk Services (karena di model Barbershop kita cuma simpan List<String>)
  // Nanti ini akan diganti dengan _barbershopService.getAllServices()
  final List<Map<String, dynamic>> _dummyServices = [
    {'name': 'Haircut', 'price': 40000, 'duration': '30 Min'},
    {'name': 'Shaving', 'price': 25000, 'duration': '20 Min'},
    {'name': 'Coloring', 'price': 150000, 'duration': '60 Min'},
    {'name': 'Hair Spa', 'price': 80000, 'duration': '45 Min'},
    {'name': 'Trim', 'price': 20000, 'duration': '15 Min'},
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24.0),
      itemCount: _dummyServices.length,
      itemBuilder: (context, index) {
        final service = _dummyServices[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E), // kDarkGrey
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['name'] as String, 
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service['duration'] as String,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              Text(
                _currencyFormat.format(service['price']),
                style: const TextStyle(color: Color(0xFFC3A47B), fontSize: 16, fontWeight: FontWeight.bold),
              )
            ],
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 16),
    );
  }
}
// [ANDA BISA COPY PASTE SAMPAI SINI]