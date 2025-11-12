// lib/services/queue_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geges_smartbarber/models/queue.dart';

class QueueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, int> _serviceDurationCache = {};

  QueueService();

  // -----------------------
  // 🔁 STREAM LISTENERS
  // -----------------------

  /// Stream antrean aktif (booked | ongoing)
  Stream<List<Queue>> getActiveQueueStream(String barbershopId) {
    return _firestore
        .collection('queues')
        .where('barbershop_id', isEqualTo: barbershopId)
        .where('status', whereIn: ['booked', 'ongoing'])
        .orderBy('booking_time', descending: false)
        .withConverter<Queue>(
          fromFirestore: (snap, _) => Queue.fromFirestore(snap),
          toFirestore: (queue, _) => queue.toJson(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Stream antrean untuk dashboard Admin (dapat difilter berdasarkan status)
  Stream<List<Queue>> streamQueuesForBarbershop(
    String barbershopId, {
    List<String>? statusFilter,
    String? barbermanIdFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('queues')
        .where('barbershop_id', isEqualTo: barbershopId);

    if (barbermanIdFilter != null && barbermanIdFilter.isNotEmpty) {
      query = query.where('barberman_id', isEqualTo: barbermanIdFilter);
    }

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', whereIn: statusFilter);
    }

    query = query.orderBy('booking_time', descending: false);

    return query
        .withConverter<Queue>(
          fromFirestore: (snap, _) => Queue.fromFirestore(snap),
          toFirestore: (queue, _) => queue.toJson(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

  /// Stream antrean berdasarkan customer ID
  Stream<List<Queue>> streamQueuesForCustomer(
    String customerId, {
    List<String>? statusFilter,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('queues')
        .where('customer_id', isEqualTo: customerId);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', whereIn: statusFilter);
    }

    query = query.orderBy('booking_time', descending: true);

    return query
        .withConverter<Queue>(
          fromFirestore: (snap, _) => Queue.fromFirestore(snap),
          toFirestore: (queue, _) => queue.toJson(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

  // -----------------------
  // 🧑‍🔧 ACTIONS (ADMIN / BARBERMAN)
  // -----------------------

  /// Mulai service (ubah status booked → ongoing)
  Future<void> startService(String queueId) async {
    try {
      await _firestore.collection('queues').doc(queueId).update({
        'start_time': FieldValue.serverTimestamp(),
        'status': 'ongoing',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error starting service for queue $queueId: $e");
      rethrow;
    }
  }

  /// Selesaikan service (ongoing → served)
  Future<void> finishService(String queueId, Timestamp startTime) async {
    try {
      final finishTime = Timestamp.now();
      int actualDurationInMinutes =
          (finishTime.seconds - startTime.seconds) ~/ 60;
      if (actualDurationInMinutes <= 0) actualDurationInMinutes = 1;

      await _firestore.collection('queues').doc(queueId).update({
        'finish_time': finishTime,
        'status': 'served',
        'actual_duration': actualDurationInMinutes,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error finishing service for queue $queueId: $e");
      rethrow;
    }
  }

  /// Batalkan antrean
  Future<void> cancelQueue(
    String queueId, {
    String reason = 'Admin/Barberman Cancellation',
  }) async {
    try {
      await _firestore.collection('queues').doc(queueId).update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_by_uid': FirebaseAuth.instance.currentUser?.uid,
        'cancelled_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error cancelling queue $queueId: $e");
      rethrow;
    }
  }

  // -----------------------
  // 🆓 MANUAL APPROVAL (ADMIN)
  // -----------------------

  /// Konfirmasi manual admin → status booked, service belum dimulai
  Future<void> manualConfirmBooking(String queueId, {String? adminUid}) async {
    final confirmedBy =
        adminUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final ref = _firestore.collection('queues').doc(queueId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');

        tx.update(ref, {
          'status': 'booked',
          'payment_confirmed_at': FieldValue.serverTimestamp(),
          'payment_confirmed_by': confirmedBy,
          'booked_at': FieldValue.serverTimestamp(),
          'booked_by': confirmedBy,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      debugPrint('Error manualConfirmBooking($queueId): $e\n$st');
      rethrow;
    }
  }

  /// Tolak manual admin → status cancelled
  Future<void> manualRejectBooking(
    String queueId, {
    String? reason,
    String? adminUid,
  }) async {
    final confirmedBy =
        adminUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final ref = _firestore.collection('queues').doc(queueId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');

        tx.update(ref, {
          'status': 'cancelled',
          'cancellation_reason': reason ?? 'Rejected by admin (manual)',
          'cancelled_by_uid': confirmedBy,
          'cancelled_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      debugPrint('Error manualRejectBooking($queueId): $e\n$st');
      rethrow;
    }
  }

  // -----------------------
  // 🧾 CREATE QUEUE (CUSTOMER)
  // -----------------------

  /// Membuat antrean / booking baru — default STATUS = 'waiting'
  Future<DocumentReference<Map<String, dynamic>>> createQueue(
    Map<String, dynamic> queueData,
  ) async {
    // normalize booking_time
    Timestamp? bookingTs;
    final bt = queueData['booking_time'] ?? queueData['bookingTime'];
    if (bt is DateTime) {
      bookingTs = Timestamp.fromDate(bt);
    } else if (bt is Timestamp) {
      bookingTs = bt;
    } else {
      bookingTs = null;
    }

    final Map<String, dynamic> dataToSave = {
      'barbershop_id': queueData['barbershop_id'] ?? queueData['barbershopId'],
      'customer_id':
          queueData['customer_id'] ??
          queueData['customerId'] ??
          FirebaseAuth.instance.currentUser?.uid,
      'barberman_id': queueData['barberman_id'] ?? queueData['barbermanId'],
      'service_ids': queueData['service_ids'] ??
          (queueData['service_id'] != null
              ? [queueData['service_id']]
              : queueData['serviceIds'] ?? []),
      'total_price': queueData['total_price'] ?? queueData['totalPrice'],
      'estimated_duration':
          queueData['estimated_duration'] ?? queueData['estimatedDuration'],
      'booking_time': bookingTs ?? FieldValue.serverTimestamp(),
      // crucial: default to 'waiting' so admin must confirm to become 'booked'
      'status': queueData['status'] ?? 'waiting',
      'created_at': FieldValue.serverTimestamp(),
      'payment_proof_base64': queueData['payment_proof_base64'] ?? queueData['payment_proof'],
      'payment_method': queueData['payment_method'],
      'payment_amount': queueData['payment_amount'],
      'order_id': queueData['order_id'],
      'notes': queueData['notes'],
    };

    // remove nulls so Firestore doc stays clean
    dataToSave.removeWhere((_, v) => v == null);

    try {
      final ref = await _firestore.collection('queues').add(dataToSave);
      return ref;
    } catch (e) {
      debugPrint("Error creating queue: $e");
      rethrow;
    }
  }

  // -----------------------
  // 🕐 SLOT AVAILABILITY
  // -----------------------

  /// Cek tumpang tindih antar booking — hanya memeriksa antrean yang sudah booked/ongoing
  Future<bool> isSlotAvailable({
    required String barbershopId,
    required String barbermanId,
    required DateTime bookingTime,
    required List<String> serviceIds,
  }) async {
    try {
      final int estimatedDurationMinutes =
          await _computeTotalDurationForServiceIds(serviceIds);

      DateTime bookingStart = bookingTime;
      DateTime bookingEnd = bookingStart.add(
        Duration(minutes: estimatedDurationMinutes),
      );

      final QuerySnapshot<Map<String, dynamic>> qs = await _firestore
          .collection('queues')
          .where('barbershop_id', isEqualTo: barbershopId)
          .where('barberman_id', isEqualTo: barbermanId)
          .where('status', whereIn: ['booked', 'ongoing'])
          .get();

      for (final doc in qs.docs) {
        final queue = Queue.fromFirestore(doc);

        final DateTime existingStart = queue.bookingTime.toDate();
        int existingDuration = queue.estimatedDuration ?? 0;

        if (existingDuration <= 0) {
          List<String> existingServiceIds =
              queue.serviceIds ??
                  (queue.serviceId != null ? [queue.serviceId!] : []);
          if (existingServiceIds.isNotEmpty) {
            existingDuration = await _computeTotalDurationForServiceIds(
              existingServiceIds,
            );
          } else {
            existingDuration = 30;
          }
        }

        final DateTime existingEnd = existingStart.add(
          Duration(minutes: existingDuration),
        );
        final bool overlaps =
            bookingStart.isBefore(existingEnd) &&
            bookingEnd.isAfter(existingStart);

        if (overlaps) {
          debugPrint("❌ Slot not available — overlaps with queue ${queue.id}");
          return false;
        }
      }

      return true;
    } catch (e, st) {
      debugPrint("Error in isSlotAvailable: $e\n$st");
      return false;
    }
  }

  // -----------------------
  // ⚙️ HELPERS
  // -----------------------

  Future<int> _computeTotalDurationForServiceIds(
    List<String> serviceIds,
  ) async {
    if (serviceIds.isEmpty) return 30;

    int total = 0;
    final List<String> missingIds = [];

    for (final id in serviceIds) {
      if (_serviceDurationCache.containsKey(id)) {
        total += _serviceDurationCache[id]!;
      } else {
        missingIds.add(id);
      }
    }

    if (missingIds.isNotEmpty) {
      final chunks = _chunkList<String>(missingIds, 10);
      for (final chunk in chunks) {
        final qs = await _firestore
            .collection('services')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in qs.docs) {
          final data = doc.data();
          final dur =
              (data['default_duration'] as num?)?.toInt() ??
              (data['defaultDuration'] as num?)?.toInt() ??
              30;
          _serviceDurationCache[doc.id] = dur;
          total += dur;
        }
        final returnedIds = qs.docs.map((d) => d.id).toSet();
        final missingAfterQuery = chunk
            .where((id) => !returnedIds.contains(id))
            .toList();
        for (var mid in missingAfterQuery) {
          _serviceDurationCache[mid] = 30;
          total += 30;
        }
      }
    }
    return total;
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final List<List<T>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  void preloadServiceDurations(Map<String, int> map) {
    _serviceDurationCache.addAll(map);
  }

  void clearServiceDurationCache() {
    _serviceDurationCache.clear();
  }
}
