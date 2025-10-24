// lib/models/barberman.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Barberman {
  final String id;
  final String name;
  final String barbershopId;
  final double avgDuration; // Kunci AI: Rata-rata durasi potong

  Barberman({required this.id, required this.name, required this.barbershopId, required this.avgDuration});

  factory Barberman.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Barberman(
      id: doc.id,
      name: data['name'] ?? 'Barberman',
      barbershopId: data['barbershop_id'] ?? '',
      // Konversi data dari Firestore (num) ke double
      avgDuration: (data['avg_duration'] as num?)?.toDouble() ?? 30.0, 
    );
  }
}