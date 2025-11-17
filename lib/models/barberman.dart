// lib/models/barberman.dart
// dokumentasi: model untuk data barber (tukang potong rambut)

import 'package:cloud_firestore/cloud_firestore.dart';

// penjelasan class barberman:
// - merepresentasikan satu barber (tukang potong rambut)
// - menyimpan info: nama, barbershop, rating, durasi potong rata-rata, dll
// - avgduration penting untuk estimasi waktu booking dan forecasting
// - rating penting untuk rekomendasi barber terbaik
class Barberman {
  // penjelasan property:
  final String id;                  // id unik barber (dari firebase)
  final String name;                // nama barber (contoh: "andi")
  final String barbershopId;        // id barbershop tempat barber bekerja
  final String? imageUrl;           // url foto barber (nullable, bisa tidak ada)
  final double avgDuration;         // rata-rata durasi potong (menit)
  final double rating;              // rating barber (0.0 - 5.0)
  final bool isActive;              // apakah barber sedang aktif/bisa dipesan

  // penjelasan constructor:
  // - imageurl nullable (boleh null)
  // - sisanya required (harus diberikan)
  Barberman({
    required this.id,
    required this.name,
    required this.barbershopId,
    this.imageUrl,
    required this.avgDuration,
    required this.rating,
    required this.isActive,
  });

  // penjelasan factory barberman.fromfirestore:
  // - convert firebase document menjadi object barberman
  // - doc.data() ?? {} = ambil data atau gunakan map kosong jika null
  factory Barberman.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // penjelasan avgduration parsing:
    // - penting untuk slot booking dan estimasi waktu
    // - coba field 'avg_duration' dulu, jika tidak ada coba 'avgDuration'
    // - jika keduanya tidak ada, default 30 menit
    final avgDur = (data['avg_duration'] as num?)?.toDouble() ??
        (data['avgDuration'] as num?)?.toDouble() ??
        30.0;

    return Barberman(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? 'Barberman Tidak Dikenal',
      // ambil barbershop_id (snake_case) atau barbershopId (camelCase)
      barbershopId: data['barbershop_id'] as String? ?? data['barbershopId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      avgDuration: avgDur,
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  // penjelasan method tojson:
  // - convert object menjadi map untuk simpan ke firebase
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'barbershop_id': barbershopId,
      'imageUrl': imageUrl,
      'avg_duration': avgDuration,
      'rating': rating,
      'isActive': isActive,
    };
  }
}