import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geges_smartbarber/models/barberman_leave.dart';
import 'package:geges_smartbarber/models/barberman.dart';

class BarbermanLeaveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -----------------------
  // 📋 STREAM LISTENERS
  // -----------------------

  /// Stream semua leave requests untuk satu barbershop (untuk admin approval)
  Stream<List<BarbermanLeave>> streamLeavesForBarbershop(
    String barbershopId, {
    String? status, // filter by status: pending, approved, rejected
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('barbershops')
        .doc(barbershopId)
        .collection('barberman_leaves')
        .orderBy('createdAt', descending: true);

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    return query
        .withConverter<BarbermanLeave>(
          fromFirestore: (snap, _) => BarbermanLeave.fromFirestore(snap),
          toFirestore: (leave, _) => leave.toJson(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Stream leave requests untuk satu barberman
  Stream<List<BarbermanLeave>> streamLeavesForBarberman(
    String barbershopId,
    String barbermanId,
  ) {
    return _firestore
        .collection('barbershops')
        .doc(barbershopId)
        .collection('barberman_leaves')
        .where('barbermanId', isEqualTo: barbermanId)
        .orderBy('startDate', descending: true)
        .withConverter<BarbermanLeave>(
          fromFirestore: (snap, _) => BarbermanLeave.fromFirestore(snap),
          toFirestore: (leave, _) => leave.toJson(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // -----------------------
  // ✅ CREATE / REQUEST LEAVE
  // -----------------------

  /// Barberman request leave/cuti
  Future<DocumentReference<Map<String, dynamic>>> requestLeave(
    String barbershopId,
    String barbermanId,
    DateTime startDate,
    DateTime endDate,
    LeaveType leaveType, {
    String? reason,
  }) async {
    try {
      final startTs = Timestamp.fromDate(startDate);
      final endTs = Timestamp.fromDate(endDate);
      final usedDays = endDate.difference(startDate).inDays + 1;

      final leave = BarbermanLeave(
        id: '', // Firestore will generate the id
        barbermanId: barbermanId,
        barbershopId: barbershopId,
        startDate: startTs,
        endDate: endTs,
        type: leaveType,
        reason: reason,
        status: 'pending',
        approvedBy: null,
        createdAt: Timestamp.now(),
        approvedAt: null,
        usedDays: usedDays,
      );

      final ref = await _firestore
          .collection('barbershops')
          .doc(barbershopId)
          .collection('barberman_leaves')
          .add(leave.toJson());

      return ref;
    } catch (e) {
      debugPrint('Error requesting leave: $e');
      rethrow;
    }
  }

  // -----------------------
  // ⚡ ADMIN APPROVAL
  // -----------------------

  /// Admin approve leave request
  Future<void> approveLeave(
    String barbershopId,
    String leaveId, {
    String? adminUid,
  }) async {
    final approverUid =
        adminUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'admin';

    try {
      await _firestore
          .collection('barbershops')
          .doc(barbershopId)
          .collection('barberman_leaves')
          .doc(leaveId)
          .update({
            'status': 'approved',
            'approvedBy': approverUid,
            'approvedAt': FieldValue.serverTimestamp(),
          });

      // Fetch the leave to get barberman ID and used days
      final leaveDoc = await _firestore
          .collection('barbershops')
          .doc(barbershopId)
          .collection('barberman_leaves')
          .doc(leaveId)
          .get();

      if (leaveDoc.exists) {
        final leaveData = leaveDoc.data();
        final barbermanId = leaveData?['barbermanId'] as String?;
        final usedDays = (leaveData?['usedDays'] as num?)?.toInt() ?? 0;

        // Deduct from annual leave days
        if (barbermanId != null) {
          await _updateBarbermanAnnualLeaveDays(
            barbershopId,
            barbermanId,
            -usedDays, // negative to deduct
          );
        }
      }
    } catch (e) {
      debugPrint('Error approving leave: $e');
      rethrow;
    }
  }

  /// Admin reject leave request
  Future<void> rejectLeave(String barbershopId, String leaveId) async {
    try {
      await _firestore
          .collection('barbershops')
          .doc(barbershopId)
          .collection('barberman_leaves')
          .doc(leaveId)
          .update({
            'status': 'rejected',
            'approvedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error rejecting leave: $e');
      rethrow;
    }
  }

  // -----------------------
  // 📅 HELPER METHODS
  // -----------------------

  /// Check if barberman is on leave on a specific date
  Future<bool> isBarberOnLeave(
    String barbershopId,
    String barbermanId,
    DateTime date,
  ) async {
    try {
      final startDate = Timestamp.fromDate(
        DateTime(date.year, date.month, date.day),
      );
      final endDate = Timestamp.fromDate(
        DateTime(date.year, date.month, date.day, 23, 59, 59),
      );

      final snapshot = await _firestore
          .collection('barbershops')
          .doc(barbershopId)
          .collection('barberman_leaves')
          .where('barbermanId', isEqualTo: barbermanId)
          .where('status', isEqualTo: 'approved')
          .where('startDate', isLessThanOrEqualTo: endDate)
          .where('endDate', isGreaterThanOrEqualTo: startDate)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if barber is on leave: $e');
      return false;
    }
  }

  /// Get remaining annual leave days for a barberman
  Future<int> getRemainingAnnualLeaveDays(
    String barbershopId,
    String barbermanId,
  ) async {
    try {
      final barbershop = await _firestore
          .collection('barbershops')
          .doc(barbershopId)
          .get();

      if (!barbershop.exists) return 12; // default

      final barbermen =
          (barbershop.data()?['barbermen'] as List<dynamic>?)
              ?.map((b) => b as Map<String, dynamic>)
              .toList() ??
          [];

      final barberData = barbermen.firstWhere(
        (b) => b['id'] == barbermanId,
        orElse: () => {},
      );

      return (barberData['annualLeaveDays'] as num?)?.toInt() ?? 12;
    } catch (e) {
      debugPrint('Error getting remaining leave days: $e');
      return 12;
    }
  }

  /// Get barber's off days in a week
  Future<List<int>> getBarberOffDays(
    String barbershopId,
    String barbermanId,
  ) async {
    try {
      final barberDoc = await _firestore
          .collection('barbermen')
          .doc(barbermanId)
          .get();

      if (!barberDoc.exists) return []; // no off days

      final offDays =
          (barberDoc.data()?['offDays'] as List<dynamic>?)
              ?.whereType<int>()
              .toList() ??
          [];

      return offDays;
    } catch (e) {
      debugPrint('Error getting barber off days: $e');
      return [];
    }
  }

  // -----------------------
  // 🔧 INTERNAL HELPERS
  // -----------------------

  /// Internal: update barberman's annual leave days
  Future<void> _updateBarbermanAnnualLeaveDays(
    String barbershopId,
    String barbermanId,
    int dayChange, // negative to deduct
  ) async {
    try {
      final barberRef = _firestore.collection('barbermen').doc(barbermanId);
      final barberDoc = await barberRef.get();

      if (!barberDoc.exists) return;

      final currentDays =
          (barberDoc.data()?['annualLeaveDays'] as num?)?.toInt() ?? 12;
      final newDays = (currentDays + dayChange).clamp(0, 365);

      await barberRef.update({'annualLeaveDays': newDays});
    } catch (e) {
      debugPrint('Error updating annual leave days: $e');
    }
  }

  /// Create a new booking request
  Future<void> createBookingRequest(
    String barbershopId,
    Map<String, dynamic> bookingData,
  ) async {
    final bookingRef = _firestore
        .collection('barbershops')
        .doc(barbershopId)
        .collection('booking_requests')
        .doc();

    bookingData['createdAt'] = FieldValue.serverTimestamp();
    bookingData['status'] = 'pending'; // Default status

    await bookingRef.set(bookingData);
  }

  /// Update booking request status
  Future<void> updateBookingStatus(
    String barbershopId,
    String requestId,
    String status,
  ) async {
    final requestRef = _firestore
        .collection('barbershops')
        .doc(barbershopId)
        .collection('booking_requests')
        .doc(requestId);

    await requestRef.update({'status': status});
  }

  /// Automatically cancel unpaid booking requests
  Future<void> cancelUnpaidRequests(
    String barbershopId,
    DateTime deadline,
  ) async {
    final query = _firestore
        .collection('barbershops')
        .doc(barbershopId)
        .collection('booking_requests')
        .where('status', isEqualTo: 'waiting_for_payment')
        .where('paymentDeadline', isLessThan: deadline);

    final snapshot = await query.get();
    for (final doc in snapshot.docs) {
      await doc.reference.update({'status': 'canceled'});
    }
  }
}
