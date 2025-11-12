// lib/models/barberman.dart (VERSI LENGKAP UNTUK AI FORECASTING)

import 'package:cloud_firestore/cloud_firestore.dart';

class Barberman {
  final String id;
  final String name;
  final String barbershopId; // ID Barbershop tempat ia bekerja
  final String? imageUrl;     
  final double avgDuration;   // <--- PENTING untuk AI Time Series
  final double rating;        // <--- PENTING untuk AI
  final bool isActive;        // Status aktif (bisa dipesan)

  Barberman({
    required this.id,
    required this.name,
    required this.barbershopId,
    this.imageUrl,
    required this.avgDuration,
    required this.rating,
    required this.isActive,
  });

  factory Barberman.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return Barberman(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? 'Barberman Tidak Dikenal',
      // Mengambil ID Barbershop
      barbershopId: data['barbershop_id'] as String? ?? data['barbershopId'] as String? ?? '', 
      
      imageUrl: data['imageUrl'] as String?, 
      
      // Durasi rata-rata (penting untuk slot booking & AI)
      avgDuration: (data['avg_duration'] as num?)?.toDouble() ??
          (data['avgDuration'] as num?)?.toDouble() ??
          30.0, // fallback 30 menit
          
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'barbershop_id': barbershopId,
      'imageUrl': imageUrl,
      'avg_duration': avgDuration, // Dikembalikan
      'rating': rating,           // Dikembalikan
      'isActive': isActive,
    };
  }
}