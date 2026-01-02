import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserData {
  final String uid;
  final String name;
  final String role; // Field Kunci: 'admin_owner' atau 'customer'
  final String? phoneNumber; // Penting untuk kontak customer
  final String?
  barbershopId; // ID Barbershop yang dikelola (jika role admin_owner)
  final List<String> favoriteBarbershops; // List ID Barbershop favorit

  UserData({
    required this.uid,
    required this.name,
    required this.role,
    this.phoneNumber,
    this.barbershopId,
    this.favoriteBarbershops = const [],
  });

  // Factory constructor untuk membuat objek UserData dari Firestore
  factory UserData.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();

    // Safety check untuk memastikan data adalah Map
    if (raw is! Map<String, dynamic>) {
      debugPrint('⚠️ Invalid Firestore data for user: ${doc.id}');
      return UserData(uid: doc.id, name: 'Guest', role: 'customer');
    }

    final data = raw;

    // Ambil Barbershop ID, menggunakan fallback yang fleksibel
    final shopId =
        data['barbershop_id'] as String? ?? data['barbershopId'] as String?;

    // Ambil list favorit
    final favsRaw = data['favorite_barbershops'] ?? data['favoriteBarbershops'];
    List<String> favs = [];
    if (favsRaw is List) {
      favs = favsRaw.map((e) => e.toString()).toList();
    }

    return UserData(
      uid: doc.id,
      name: data['name'] as String? ?? 'Guest',
      role: data['role'] as String? ?? 'customer',
      phoneNumber:
          data['phone_number'] as String? ?? data['phoneNumber'] as String?,
      barbershopId: shopId,
      favoriteBarbershops: favs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      'favorite_barbershops': favoriteBarbershops,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (barbershopId != null) 'barbershop_id': barbershopId,
    };
  }

  UserData copyWith({
    String? name,
    String? role,
    String? phoneNumber,
    String? barbershopId,
    List<String>? favoriteBarbershops,
  }) {
    return UserData(
      uid: uid,
      name: name ?? this.name,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      barbershopId: barbershopId ?? this.barbershopId,
      favoriteBarbershops: favoriteBarbershops ?? this.favoriteBarbershops,
    );
  }
}
