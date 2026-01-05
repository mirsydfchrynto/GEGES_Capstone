// lib/services/barberman_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import model Barberman yang sudah Anda sediakan
import 'package:geges_smartbarber/models/barberman.dart';

class BarbermanService {
  final FirebaseFirestore _firestore;
  final String _collection = 'barbermen';

  BarbermanService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // -----------------------
  // FETCH SINGLE BARBERMAN
  // -----------------------

  /// Mengambil data Barberman berdasarkan ID-nya.
  Future<Barberman?> getBarbermanById(String barbermanId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(barbermanId)
          .get();

      if (doc.exists && doc.data() != null) {
        return Barberman.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      debugPrint("Error fetching barberman $barbermanId: $e");
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
            return Barberman.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            );
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
        await _firestore
            .collection(_collection)
            .doc(barberman.id)
            .update(barberman.toJson());
      }
    } catch (e) {
      // ignore: avoid_print
      debugPrint("Error saving barberman: $e");
      rethrow;
    }
  }

  Future<void> deleteBarberman(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({'isActive': false});
    } catch (e) {
      debugPrint("Error deleting barberman: $e");
      rethrow;
    }
  }

  // -----------------------
  // BULK OFF-DAY HELPERS
  // -----------------------

  // Internal cache for undo functionality
  final Map<String, Map<String, List<String>>> _undoCache = {};

  Future<void> bulkSetOffDay(String barbershopId, DayOfWeek day) async {
    final dayName = day.name.toLowerCase();
    final prev = await applyOffDayToAll(barbershopId, dayName);
    _undoCache[barbershopId] = prev;
  }

  Future<void> undoBulkSetOffDay(String barbershopId, DayOfWeek day) async {
    final prev = _undoCache[barbershopId];
    if (prev != null && prev.isNotEmpty) {
      await revertOffDayByPrevious(prev);
      _undoCache.remove(barbershopId);
    }
  }

  /// Apply an off-day (dayName) to all barbermen in a barbershop.
  /// Returns a map of docId -> previous offDays list so the caller can revert if needed.
  Future<Map<String, List<String>>> applyOffDayToAll(
    String barbershopId,
    String dayName,
  ) async {
    final result = <String, List<String>>{};
    final docs = await _firestore
        .collection(_collection)
        .where('barbershop_id', isEqualTo: barbershopId)
        .get();
    if (docs.docs.isEmpty) return result;

    final batch = _firestore.batch();
    for (final d in docs.docs) {
      final data = d.data();
      final existing = (data['offDays'] is List)
          ? List<String>.from(data['offDays'])
          : <String>[];
      result[d.id] = List<String>.from(existing);
      if (!existing.contains(dayName)) {
        final newList = List<String>.from(existing)..add(dayName);
        batch.update(d.reference, {'offDays': newList});
      }
    }

    if (result.isEmpty) return result;
    await batch.commit();
    return result;
  }

  /// Revert off-days using the previous map returned by [applyOffDayToAll].
  Future<void> revertOffDayByPrevious(
    Map<String, List<String>> previous,
  ) async {
    if (previous.isEmpty) return;
    final batch = _firestore.batch();
    for (final entry in previous.entries) {
      final docRef = _firestore.collection(_collection).doc(entry.key);
      batch.update(docRef, {'offDays': entry.value});
    }
    await batch.commit();
  }

  // -----------------------
  // BOOKING MANAGEMENT
  // -----------------------

  /// Membuat permintaan booking baru.
  Future<void> createBookingRequest(
    String barbermanId,
    Map<String, dynamic> bookingData,
  ) async {
    try {
      final bookingCollection = _firestore
          .collection('barbermen')
          .doc(barbermanId)
          .collection('bookings');
      await bookingCollection.add({
        ...bookingData,
        'status': 'waiting',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      debugPrint("Error creating booking request: $e");
      rethrow;
    }
  }

  /// Mengupdate status booking berdasarkan ID booking.
  Future<void> updateBookingStatus(
    String barbermanId,
    String bookingId,
    String status,
  ) async {
    try {
      final bookingDoc = _firestore
          .collection('barbermen')
          .doc(barbermanId)
          .collection('bookings')
          .doc(bookingId);
      await bookingDoc.update({'status': status});
    } catch (e) {
      // ignore: avoid_print
      debugPrint("Error updating booking status: $e");
      rethrow;
    }
  }

  /// Membatalkan booking yang belum dibayar secara otomatis.
  Future<void> cancelUnpaidBookings(String barbermanId) async {
    try {
      final bookingCollection = _firestore
          .collection('barbermen')
          .doc(barbermanId)
          .collection('bookings');
      final unpaidBookings = await bookingCollection
          .where('status', isEqualTo: 'waiting')
          .get();

      for (final doc in unpaidBookings.docs) {
        await doc.reference.update({'status': 'cancelled'});
      }
    } catch (e) {
      // ignore: avoid_print
      debugPrint("Error cancelling unpaid bookings: $e");
      rethrow;
    }
  }
}
