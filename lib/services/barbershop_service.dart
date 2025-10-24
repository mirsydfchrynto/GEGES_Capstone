// lib/services/barbershop_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/barberman.dart'; 
import 'package:geges_smartbarber/models/service.dart';

class BarbershopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mengambil Semua Barbershop
  Future<List<Barbershop>> getAllBarbershops() async {
    QuerySnapshot snapshot = await _firestore.collection('barbershops').get();
    return snapshot.docs.map((doc) => Barbershop.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>)).toList();
  }

  // Mengambil Barbermen di toko tertentu
  Future<List<Barberman>> getBarbermenByShop(String barbershopId) async {
    QuerySnapshot snapshot = await _firestore
          .collection('barbermen')
          .where('barbershop_id', isEqualTo: barbershopId)
          .get();
    return snapshot.docs.map((doc) => Barberman.fromFirestore(doc)).toList();
  }

  // Mengambil Service
  Future<List<Service>> getAllServices() async {
    QuerySnapshot snapshot = await _firestore.collection('services').get();
    return snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList();
  }
}