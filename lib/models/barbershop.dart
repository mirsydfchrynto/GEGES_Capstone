// lib/models/barbershop.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Barbershop {
  final String id;
  final String name;
  final String address;
  final double rating;

  Barbershop({required this.id, required this.name, required this.address, required this.rating});

  factory Barbershop.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Barbershop(
      id: doc.id,
      name: data['name'] ?? 'Nama Barbershop',
      address: data['address'] ?? 'Alamat Tidak Diketahui',
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0, 
    );
  }
}