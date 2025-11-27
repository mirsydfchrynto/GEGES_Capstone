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
      // optional client-provided payment expiry (Timestamp). If not provided and status == 'waiting', we'll set below.
      'payment_due_at': queueData['payment_due_at'],
      'created_at': FieldValue.serverTimestamp(),
      'payment_proof_base64': queueData['payment_proof_base64'] ?? queueData['payment_proof'],
      'payment_method': queueData['payment_method'],
      'payment_amount': queueData['payment_amount'],
      'order_id': queueData['order_id'],
      'notes': queueData['notes'],
    };

    // remove nulls so Firestore doc stays clean
    dataToSave.removeWhere((_, v) => v == null);

    // If status is 'waiting' and no payment_due_at provided, set a 10-minute expiry from now.
    if ((dataToSave['status'] as String?) == 'waiting' && dataToSave['payment_due_at'] == null) {
      try {
        final due = DateTime.now().add(const Duration(minutes: 10));
        dataToSave['payment_due_at'] = Timestamp.fromDate(due);
      } catch (e) {
        debugPrint('Failed to set payment_due_at: $e');
      }
    }

    try {
      // Use transaction to ensure we don't create conflicting bookings
      final docRef = await _firestore.runTransaction<DocumentReference<Map<String, dynamic>>>((tx) async {
        final barbershopId = dataToSave['barbershop_id'] as String?;
        final barbermanId = dataToSave['barberman_id'] as String?;
        final bookingTs = dataToSave['booking_time'] as Timestamp?;
        final serviceIds = dataToSave['service_ids'] as List<dynamic>?;

        // Re-check slot availability in transaction context
        if (barbershopId != null &&
            barbermanId != null &&
            bookingTs != null &&
            (serviceIds?.isNotEmpty ?? false)) {
          final bookingDateTime = bookingTs.toDate();
          final isAvailable = await isSlotAvailable(
            barbershopId: barbershopId,
            barbermanId: barbermanId,
            bookingTime: bookingDateTime,
            serviceIds: (serviceIds ?? []).cast<String>(),
          );

          if (!isAvailable) {
            throw Exception('Slot tidak tersedia - booking bentrok dengan antrean lain');
          }
        }

        // If slot is available, add the queue document
        final ref = await _firestore.collection('queues').add(dataToSave);
        return ref;
      });
      return docRef;
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

  // -----------------------
  // 👮 ADMIN PAYMENT CONFIRMATION
  // -----------------------

  /// Admin confirms payment: waiting → booked (service belum dimulai)
  Future<void> adminConfirmPayment(
    String queueId, {
    String? adminUid,
    String? adminNotes,
  }) async {
    final confirmedBy =
        adminUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final ref = _firestore.collection('queues').doc(queueId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        if ((data['status'] as String?) != 'waiting') {
          throw Exception(
              'Queue status is not waiting (current: ${data['status']})');
        }

        tx.update(ref, {
          'status': 'booked',
          'payment_confirmed_at': FieldValue.serverTimestamp(),
          'payment_confirmed_by': confirmedBy,
          'admin_payment_notes': adminNotes,
          'booked_at': FieldValue.serverTimestamp(),
          'booked_by': confirmedBy,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      debugPrint('Error adminConfirmPayment($queueId): $e\n$st');
      rethrow;
    }
  }

  /// Admin rejects/cancels booking dengan alasan pembayaran (waiting → cancelled)
  Future<void> adminRejectPayment(
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
          'cancellation_reason':
              reason ?? 'Rejected by admin - payment not confirmed',
          'cancelled_by_uid': confirmedBy,
          'cancelled_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      debugPrint('Error adminRejectPayment($queueId): $e\n$st');
      rethrow;
    }
  }

  /// Customer requests cancellation: booked → cancellation_requested
  Future<void> customerRequestCancellation(
    String queueId, {
    required String reason,
    String? customerId,
  }) async {
    final uid = customerId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    final ref = _firestore.collection('queues').doc(queueId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        if ((data['status'] as String?) != 'booked') {
          throw Exception(
              'Can only cancel from booked status (current: ${data['status']})');
        }

        final totalPrice = (data['total_price'] as num?)?.toInt() ?? 0;
        final refundAmount = (totalPrice * 0.9).toInt();

        tx.update(ref, {
          'status': 'cancellation_requested',
          'cancellation_reason': reason,
          'cancellation_requested_by': uid,
          'cancellation_requested_at': FieldValue.serverTimestamp(),
          'refund_amount': refundAmount,
          'original_price': totalPrice,
          'refund_deduction': totalPrice - refundAmount,
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      debugPrint('Error customerRequestCancellation($queueId): $e\n$st');
      rethrow;
    }
  }

  /// Admin approves cancellation: cancellation_requested → refund_pending
  Future<void> adminApproveCancellation(
    String queueId, {
    String? refundProofBase64,
    String? adminUid,
  }) async {
    final approvedBy =
        adminUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final ref = _firestore.collection('queues').doc(queueId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        if ((data['status'] as String?) != 'cancellation_requested') {
          throw Exception(
              'Queue is not in cancellation_requested status (current: ${data['status']})');
        }

        tx.update(ref, {
          'status': 'refund_pending',
          'cancellation_approved_at': FieldValue.serverTimestamp(),
          'cancellation_approved_by': approvedBy,
          'refund_proof_base64': refundProofBase64,
          'refund_approved_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      debugPrint('Error adminApproveCancellation($queueId): $e\n$st');
      rethrow;
    }
  }

  /// Admin rejects cancellation request: cancellation_requested → booked
  Future<void> adminRejectCancellation(
    String queueId, {
    String? reason,
    String? adminUid,
  }) async {
    final rejectedBy =
        adminUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final ref = _firestore.collection('queues').doc(queueId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        if ((data['status'] as String?) != 'cancellation_requested') {
          throw Exception(
              'Queue is not in cancellation_requested status (current: ${data['status']})');
        }

        tx.update(ref, {
          'status': 'booked',
          'cancellation_rejected_at': FieldValue.serverTimestamp(),
          'cancellation_rejected_by': rejectedBy,
          'cancellation_rejection_reason':
              reason ?? 'Cancellation request rejected by admin',
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      debugPrint('Error adminRejectCancellation($queueId): $e\n$st');
      rethrow;
    }
  }

  // -----------------------
  // ⭐ RATING (AFTER SERVED)
  // -----------------------

  /// Customer submits rating setelah booking served
  Future<void> submitRating(
    String queueId, {
    required double rating,
    required String barbershopId,
    String? comment,
    String? customerId,
  }) async {
    final uid = customerId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5');
    }

    final ref = _firestore.collection('queues').doc(queueId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        if ((data['status'] as String?) != 'served') {
          throw Exception(
              'Can only rate served bookings (current: ${data['status']})');
        }

        tx.update(ref, {
          'rating': rating,
          'rating_comment': comment,
          'rating_submitted_by': uid,
          'rating_submitted_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      debugPrint('Error submitRating($queueId): $e\n$st');
      rethrow;
    }
  }

  // -----------------------
  // 🔍 QUERY HELPERS
  // -----------------------

  /// Get queue details by ID
  Future<Queue?> getQueueById(String queueId) async {
    try {
      final snap = await _firestore.collection('queues').doc(queueId).get();
      if (!snap.exists) return null;
      return Queue.fromFirestore(snap);
    } catch (e) {
      debugPrint('Error getQueueById($queueId): $e');
      return null;
    }
  }

  /// Get all booking history for barbershop
  Future<List<Queue>> getBarbershopBookingHistory(
    String barbershopId, {
    int limit = 50,
  }) async {
    try {
      final qs = await _firestore
          .collection('queues')
          .where('barbershop_id', isEqualTo: barbershopId)
          .orderBy('booking_time', descending: true)
          .limit(limit)
          .get();
      return qs.docs.map((doc) => Queue.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getBarbershopBookingHistory($barbershopId): $e');
      return [];
    }
  }

  /// Cancel waiting queues for a customer whose payment_due_at has passed.
  /// Returns number of cancelled documents.
  Future<int> cancelExpiredWaitingQueuesForCustomer(String customerId) async {
    try {
      final nowTs = Timestamp.fromDate(DateTime.now());
      final qs = await _firestore
          .collection('queues')
          .where('customer_id', isEqualTo: customerId)
          .where('status', isEqualTo: 'waiting')
          .where('payment_due_at', isLessThan: nowTs)
          .get();

      int count = 0;
      for (final doc in qs.docs) {
        await doc.reference.update({
          'status': 'cancelled',
          'cancellation_reason': 'Payment timeout',
          'cancelled_by_uid': 'system',
          'cancelled_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        count++;
      }
      return count;
    } catch (e, st) {
      debugPrint('Error cancelling expired waiting queues for customer $customerId: $e\n$st');
      return 0;
    }
  }

  // =============== ADMIN SCREEN HELPERS ===============

  /// Stream all queues with optional status filter (for admin dashboard)
  Stream<List<Queue>> streamAllQueues({String? barbershopId, List<String>? statusFilter}) {
    Query<Map<String, dynamic>> query = _firestore.collection('queues');

    if (barbershopId != null && barbershopId.isNotEmpty) {
      query = query.where('barbershop_id', isEqualTo: barbershopId);
    }

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.where('status', whereIn: statusFilter);
    }

    return query
        .withConverter<Queue>(
          fromFirestore: (snap, _) => Queue.fromFirestore(snap),
          toFirestore: (queue, _) => queue.toJson(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

  /// Admin confirm booking request (waiting → booked)
  Future<void> adminConfirmRequest(String queueId, {String? adminUid}) async {
    try {
      final uid = adminUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      await _firestore.collection('queues').doc(queueId).update({
        'status': 'booked',
        'request_status': 'approved',
        'verified_by': uid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error confirming request $queueId: $e');
      rethrow;
    }
  }

  /// Admin reject booking request (waiting → cancelled)
  Future<void> adminRejectRequest(String queueId, {String? rejectionReason, String? adminUid}) async {
    try {
      final uid = adminUid ?? FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      await _firestore.collection('queues').doc(queueId).update({
        'status': 'cancelled',
        'request_status': 'rejected',
        'rejection_reason': rejectionReason ?? 'Rejected by admin',
        'verified_by': uid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error rejecting request $queueId: $e');
      rethrow;
    }
  }
}
