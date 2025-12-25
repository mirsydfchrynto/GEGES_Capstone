// lib/services/barbershop_service.dart
import 'dart:async'; // Diperlukan untuk Future dan Stream
import 'package:cloud_firestore/cloud_firestore.dart';

// Import semua model yang dibutuhkan
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/models/promo_banner.dart';

class BarbershopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -----------------------
  // BARBERSHOP FUNCTIONS
  // -----------------------

  /// Mengambil semua barbershop untuk HomeScreen (Future)
  Future<List<Barbershop>> getAllBarbershops() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('barbershops')
          .get();

      return snapshot.docs
          .map(
            (doc) => Barbershop.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error getAllBarbershops: $e');
      return [];
    }
  }

  // -----------------------
  // BARBERMAN FUNCTIONS (Dipelihara Sesuai Keinginan Anda)
  // -----------------------

  /// Mengambil barbermen di toko tertentu (untuk AppointmentScreen)
  Future<List<Barberman>> getBarbermenByShop(String barbershopId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('barbermen')
          .where('barbershop_id', isEqualTo: barbershopId)
          .get();

      return snapshot.docs
          .map(
            (doc) => Barberman.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error getBarbermenByShop: $e');
      return [];
    }
  }

  /// Mengambil satu barberman berdasarkan ID (untuk AdminDashboardScreen)
  Future<Barberman?> getBarbermanById(String barbermanId) async {
    if (barbermanId.isEmpty) return null;

    try {
      final doc = await _firestore
          .collection('barbermen')
          .doc(barbermanId)
          .get();
      if (!doc.exists) return null;
      return Barberman.fromFirestore(doc); // Pastikan cast aman
    } catch (e) {
      // ignore: avoid_print
      print('Error getBarbermanById: $e');
      return null;
    }
  }

  // -----------------------
  // SERVICE FUNCTIONS (Dipelihara Sesuai Keinginan Anda)
  // -----------------------

  /// Mengambil semua service (untuk AppointmentScreen)
  Future<List<Service>> getAllServices() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('services')
          .get();

      return snapshot.docs
          .map(
            (doc) => Service.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error getAllServices: $e');
      return [];
    }
  }

  // -----------------------
  // PROMO / BANNER FUNCTIONS
  // -----------------------

  /// Stream untuk mengambil promo banner yang aktif.
  Stream<List<PromoBanner>> getPromoBanners() {
    return _firestore
        .collection('promo_banners')
        .where('isActive', isEqualTo: true) // Hanya ambil promo yang aktif
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => PromoBanner.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }
}
