// lib/models/user_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserData {
  final String uid;
  final String name;
  final String role; // Field Kunci: admin_owner atau customer

  UserData({required this.uid, required this.name, required this.role});

  factory UserData.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    // Ambil data dari Firestore, pastikan tipe data aman
    final data = doc.data()!;
    return UserData(
      uid: doc.id,
      name: data['name'] ?? 'Guest',
      role: data['role'] ?? 'customer', 
    );
  }
}