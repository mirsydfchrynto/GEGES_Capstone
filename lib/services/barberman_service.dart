// lib/services/barberman_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import model Barberman yang sudah Anda sediakan
import 'package:geges_smartbarber/models/barberman.dart';

class BarbermanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'barbermen';

  // -----------------------
  // FETCH SINGLE BARBERMAN
  // -----------------------

  /// Mengambil data Barberman berdasarkan ID-nya.
  Future<Barberman?> getBarbermanById(String barbermanId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(barbermanId).get();

      if (doc.exists && doc.data() != null) {
        return Barberman.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print("Error fetching barberman $barbermanId: $e");
      return null;
    }
  }

  // -----------------------
  // STREAM LIST OF BARBERMEN
  // -----------------------

  /// Stream daftar Barberman yang bekerja di Barbershop tertentu.
  /// Mem filter berdasarkan field 'barbershop_id' atau 'barbershopId'.
  Stream<List<Barberman>> streamBarbermenByBarbershop(String barbershopId) {
    // Kita asumsikan ada field 'barbershop_id' (atau 'barbershopId') di koleksi 'barbermen'
    // yang menyimpan ID barbershop tempat barberman itu bekerja.
    return _firestore
        .collection(_collection)
        .where('barbershop_id', isEqualTo: barbershopId) 
        // Anda mungkin ingin menambahkan orderBy untuk sorting
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Barberman.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      }).toList();
    });
  }

  // -----------------------
  // UTILITY / ADMIN
  // -----------------------

  /// Membuat atau mengupdate dokumen Barberman baru.
  /// (Contoh sederhana untuk operasi CUD)
  Future<void> saveBarberman(Barberman barberman) async {
    try {
      if (barberman.id.isEmpty) {
        // Create new
        await _firestore.collection(_collection).add(barberman.toJson());
      } else {
        // Update existing
        await _firestore.collection(_collection).doc(barberman.id).update(barberman.toJson());
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error saving barberman: $e");
      rethrow;
    }
  }
}