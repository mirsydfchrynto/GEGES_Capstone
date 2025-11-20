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

  // -----------------------
  // BOOKING MANAGEMENT
  // -----------------------

  /// Membuat permintaan booking baru.
  Future<void> createBookingRequest(String barbermanId, Map<String, dynamic> bookingData) async {
    try {
      final bookingCollection = _firestore.collection('barbermen').doc(barbermanId).collection('bookings');
      await bookingCollection.add({
        ...bookingData,
        'status': 'waiting',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print("Error creating booking request: $e");
      rethrow;
    }
  }

  /// Mengupdate status booking berdasarkan ID booking.
  Future<void> updateBookingStatus(String barbermanId, String bookingId, String status) async {
    try {
      final bookingDoc = _firestore.collection('barbermen').doc(barbermanId).collection('bookings').doc(bookingId);
      await bookingDoc.update({'status': status});
    } catch (e) {
      // ignore: avoid_print
      print("Error updating booking status: $e");
      rethrow;
    }
  }

  /// Membatalkan booking yang belum dibayar secara otomatis.
  Future<void> cancelUnpaidBookings(String barbermanId) async {
    try {
      final bookingCollection = _firestore.collection('barbermen').doc(barbermanId).collection('bookings');
      final unpaidBookings = await bookingCollection.where('status', isEqualTo: 'waiting').get();

      for (final doc in unpaidBookings.docs) {
        await doc.reference.update({'status': 'cancelled'});
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error cancelling unpaid bookings: $e");
      rethrow;
    }
  }
}