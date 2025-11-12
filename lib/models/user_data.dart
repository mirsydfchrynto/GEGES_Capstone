import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserData {
  final String uid;
  final String name;
  final String role; // Field Kunci: 'admin_owner' atau 'customer'
  final String? phoneNumber; // Penting untuk kontak customer
  final String?
  barbershopId; // ID Barbershop yang dikelola (jika role admin_owner)

  UserData({
    required this.uid,
    required this.name,
    required this.role,
    this.phoneNumber,
    this.barbershopId,
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

    return UserData(
      uid: doc.id,
      name: data['name'] as String? ?? 'Guest',
      role: data['role'] as String? ?? 'customer',
      phoneNumber:
          data['phone_number'] as String? ?? data['phoneNumber'] as String?,
      barbershopId: shopId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (barbershopId != null) 'barbershop_id': barbershopId,
    };
  }

  UserData copyWith({
    String? name,
    String? role,
    String? phoneNumber,
    String? barbershopId,
  }) {
    return UserData(
      uid: uid,
      name: name ?? this.name,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      barbershopId: barbershopId ?? this.barbershopId,
    );
  }
}
