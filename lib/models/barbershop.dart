import 'package:cloud_firestore/cloud_firestore.dart';

class Barbershop {
  final String id;
  final String name;
  final String addres; // DIBIARKAN: Sesuai permintaan (asumsi typo di DB)
  final double rating;
  final String imageUrl;
  final List<String> services; // service ids
  final int openHour;  // jam buka dalam integer 0-23 (mis. 9)
  final int closeHour; // jam tutup dalam integer 0-23 (mis. 21)
  final bool isOpen; // NEW: Status buka/tutup toko

  Barbershop({
    required this.id,
    required this.name,
    required this.addres,
    required this.rating,
    required this.imageUrl,
    required this.services,
    required this.openHour,
    required this.closeHour,
    required this.isOpen, // NEW
  });

  factory Barbershop.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // Helper untuk mem-parsing jam buka/tutup (int atau string)
    int parseHour(dynamic value, int fallback) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is String) {
        if (value.contains(':')) {
          return int.tryParse(value.split(':').first) ?? fallback;
        }
        return int.tryParse(value) ?? fallback;
      }
      return fallback;
    }
    
    // Mengambil dari 'address' yang benar ATAU 'addres' yang salah
    final String addressValue = (data['address'] ?? data['addres'] ?? 'Alamat Tidak Diketahui') as String;

    return Barbershop(
      id: doc.id,
      name: data['name'] ?? 'Nama Barbershop',
      addres: addressValue, // Menggunakan 'addres' di sini
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      imageUrl: data['imageUrl'] ??
          'https://cdn-icons-png.flaticon.com/512/706/706830.png',
      services: (data['services'] is List)
          ? List<String>.from(data['services'])
          : <String>[],
      openHour: parseHour(data['open_hour'] ?? data['openHour'], 9),
      closeHour: parseHour(data['close_hour'] ?? data['closeHour'], 21),
      isOpen: data['isOpen'] as bool? ?? false, // NEW: Default false
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'addres': addres, // Menggunakan 'addres' di JSON
      'rating': rating,
      'imageUrl': imageUrl,
      'services': services,
      'open_hour': openHour,
      'close_hour': closeHour,
      'isOpen': isOpen, // NEW
    };
  }
}