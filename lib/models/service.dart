// lib/models/service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Service {
  final String id;
  final String name;
  final int price;
  final int defaultDuration; // Durasi standar (menit)

  Service({required this.id, required this.name, required this.price, required this.defaultDuration});

  factory Service.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Service(
      id: doc.id,
      name: data['name'] ?? 'Layanan',
      price: (data['price'] as num?)?.toInt() ?? 0,
      defaultDuration: (data['default_duration'] as num?)?.toInt() ?? 30,
    );
  }
}