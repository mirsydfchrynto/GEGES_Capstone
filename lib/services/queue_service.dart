// lib/services/queue_service.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/models/queue.dart';

import 'queue_service_contract.dart';

class QueueService implements QueueServiceContract {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  QueueService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // -----------------------
  // 🧠 FAIR ASSIGNMENT ALGORITHM
  // -----------------------

  Future<String?> getFairAvailableBarberman({
    required String barbershopId,
    required DateTime bookingTime,
    required List<String> serviceIds,
  }) async {
    try {
      final barbersDocs = await _firestore
          .collection('barbermen')
          .where('barbershop_id', isEqualTo: barbershopId)
          .where('isActive', isEqualTo: true)
          .get();

      if (barbersDocs.docs.isEmpty) return null;

      final List<Map<String, dynamic>> eligibleBarbers = [];
      final List<Map<String, dynamic>> fallbackBarbers = [];

      for (var doc in barbersDocs.docs) {
        final barberData = doc.data();
        final barberId = doc.id;
        final monthlyCount = (barberData['monthly_haircut_count'] as num?)?.toInt() ?? 
                             (barberData['monthlyHaircutCount'] as num?)?.toInt() ?? 0;
        
        final barberInfo = {
          'id': barberId,
          'monthlyCount': monthlyCount,
          'name': barberData['name'] ?? 'Unknown',
        };

        fallbackBarbers.add(barberInfo);

        bool isOnLeave = barberData['onLeave'] ?? false;
        if (isOnLeave) continue;

        final dayName = DateFormat('EEEE', 'en_US').format(bookingTime).toLowerCase();
        final List<dynamic> offDays = barberData['offDays'] ?? [];
        if (offDays.contains(dayName)) continue;

        final dateStr = DateFormat('yyyy-MM-dd').format(bookingTime);
        final List<dynamic> specificOffDays = barberData['specificOffDays'] ?? [];
        if (specificOffDays.contains(dateStr)) continue;

        final isAvailable = await isSlotAvailable(
          barbershopId: barbershopId,
          barbermanId: barberId,
          bookingTime: bookingTime,
          serviceIds: serviceIds,
        );

        if (isAvailable) {
          eligibleBarbers.add(barberInfo);
        }
      }

      final List<Map<String, dynamic>> finalCandidates = 
          eligibleBarbers.isNotEmpty ? eligibleBarbers : fallbackBarbers;

      if (finalCandidates.isEmpty) return null;

      finalCandidates.shuffle(Random());
      finalCandidates.sort((a, b) => (a['monthlyCount'] as int).compareTo(b['monthlyCount'] as int));

      return finalCandidates.first['id'] as String;
    } catch (e) {
      debugPrint("Error in getFairAvailableBarberman: $e");
      return null;
    }
  }

  // -----------------------
  // 🔁 STREAM LISTENERS
  // -----------------------

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

  Stream<List<Queue>> streamQueuesForBarbershop(
    String barbershopId, {
    List<String>? statusFilter,
    String? barbermanIdFilter,
    int limit = 50,
    DocumentSnapshot? startAfter,
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

    query = query.orderBy('booking_time', descending: false).limit(limit);

    if (startAfter != null) query = query.startAfterDocument(startAfter);

    return query
        .withConverter<Queue>(
          fromFirestore: (snap, _) => Queue.fromFirestore(snap),
          toFirestore: (queue, _) => queue.toJson(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList());
  }

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
  // 🧑‍🔧 ACTIONS
  // -----------------------

  Future<DocumentReference<Map<String, dynamic>>> _resolveQueueDocRef(String id) async {
    final queuesRef = _firestore.collection('queues').doc(id);
    final qSnap = await queuesRef.get();
    if (qSnap.exists) return queuesRef;
    final bookingsRef = _firestore.collection('bookings').doc(id);
    final bSnap = await bookingsRef.get();
    if (bSnap.exists) return bookingsRef;
    return queuesRef;
  }

  Future<void> startService(String queueId) async {
    final ref = await _resolveQueueDocRef(queueId);
    await ref.update({
      'start_time': FieldValue.serverTimestamp(),
      'status': 'ongoing',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> finishService(String queueId, [Timestamp? startTime]) async {
    final ref = await _resolveQueueDocRef(queueId);
    final snap = await ref.get();
    Timestamp startTs = startTime ?? (snap.data()?['start_time'] as Timestamp? ?? Timestamp.now());
    final finishTime = Timestamp.now();
    int dur = (finishTime.seconds - startTs.seconds) ~/ 60;
    if (dur <= 0) dur = 1;

    await ref.update({
      'finish_time': finishTime,
      'status': 'served',
      'actual_duration': dur,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> cancelQueue(String queueId, {String reason = 'Cancellation', String? cancelledBy}) async {
    final by = cancelledBy ?? _auth.currentUser?.uid ?? 'system';
    await _firestore.collection('queues').doc(queueId).update({
      'status': 'cancelled',
      'cancellation_reason': reason,
      'cancelled_by_uid': by,
      'cancelled_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteQueue(String queueId) async {
    await _firestore.collection('queues').doc(queueId).delete();
  }

  // 👮 ADMIN ACTIONS

  Future<void> adminConfirmRequest(String queueId, {String? adminUid}) async {
    final uid = adminUid ?? _auth.currentUser?.uid ?? 'admin';
    final ref = await _resolveQueueDocRef(queueId);
    final qdoc = await ref.get();
    final bsId = qdoc.data()?['barbershop_id'] as String?;
    final window = await getPaymentWindowForBarbershop(bsId);
    final due = DateTime.now().add(Duration(minutes: window));
    
    await ref.update({
      'status': 'awaiting_payment',
      'request_status': 'approved',
      'verified_by': uid,
      'payment_deadline': Timestamp.fromDate(due),
      'updated_at': FieldValue.serverTimestamp(),
    });

    final customerId = qdoc.data()?['customer_id'] as String?;
    if (customerId != null) {
      await _createNotificationForUser(customerId, 'Booking Disetujui', 'Silakan bayar dalam $window menit.', queueId);
    }
  }

  Future<void> adminRejectRequest(String queueId, {String? rejectionReason, String? adminUid}) async {
    final uid = adminUid ?? _auth.currentUser?.uid ?? 'admin';
    final ref = await _resolveQueueDocRef(queueId);
    await ref.update({
      'status': 'cancelled',
      'request_status': 'rejected',
      'rejection_reason': rejectionReason ?? 'Rejected by admin',
      'verified_by': uid,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminConfirmPayment(String queueId, {String? adminUid, String? adminNotes}) async {
    final uid = adminUid ?? _auth.currentUser?.uid ?? 'admin';
    final ref = await _resolveQueueDocRef(queueId);
    await ref.update({
      'status': 'booked',
      'payment_confirmed_at': FieldValue.serverTimestamp(),
      'payment_confirmed_by': uid,
      'payment_verification_status': 'accepted',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminRejectPayment(String queueId, {String? reason, String? adminUid}) async {
    final ref = await _resolveQueueDocRef(queueId);
    await ref.update({
      'status': 'cancelled',
      'payment_verification_status': 'rejected',
      'cancellation_reason': reason ?? 'Payment rejected',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminRefundBooking(String queueId, {String? reason, String? adminUid}) async {
    final ref = await _resolveQueueDocRef(queueId);
    await ref.update({
      'status': 'cancelled',
      'is_refunded': true,
      'refunded_at': FieldValue.serverTimestamp(),
      'refunded_by': adminUid ?? 'admin',
      'refund_reason': reason ?? 'Refunded by admin',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminProcessRefund(String queueId, {required String refundProofBase64, String? adminUid, String? adminNotes}) async {
    final ref = await _resolveQueueDocRef(queueId);
    await ref.update({
      'status': 'cancelled',
      'is_refunded': true,
      'refund_proof_base64': refundProofBase64,
      'refund_processed_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminRejectCancellation(String queueId, {String? reason, String? adminUid}) async {
    final ref = await _resolveQueueDocRef(queueId);
    await ref.update({
      'status': 'booked',
      'cancellation_rejection_reason': reason,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // 🧾 CORE BOOKING

  Future<DocumentReference<Map<String, dynamic>>> createQueue(Map<String, dynamic> queueData) async {
    Timestamp? bookingTs;
    final bt = queueData['booking_time'] ?? queueData['bookingTime'];
    if (bt is DateTime) {
      bookingTs = Timestamp.fromDate(bt);
    } else if (bt is Timestamp) {
      bookingTs = bt;
    }

    final Map<String, dynamic> dataToSave = {
      ...queueData,
      'booking_time': bookingTs ?? FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    };
    dataToSave.removeWhere((_, v) => v == null);

    final bool isManual = dataToSave['customer_is_manual'] == true;
    if (bookingTs != null && !isManual) {
      if (bookingTs.toDate().isBefore(DateTime.now().subtract(const Duration(seconds: 5)))) {
        throw Exception('Waktu booking sudah lewat');
      }
      if (!isBookingLeadTimeSufficient(bookingTs.toDate())) {
        throw Exception('Booking harus dibuat minimal 30 menit sebelum waktu mulai');
      }
    }

    if (bookingTs != null) {
      final bsId = dataToSave['barbershop_id'] as String?;
      if (bsId != null) {
        final bsDoc = await _firestore.collection('barbershops').doc(bsId).get();
        final open = (bsDoc.data()?['open_hour'] ?? 9) as int;
        final close = (bsDoc.data()?['close_hour'] ?? 21) as int;
        final hour = bookingTs.toDate().hour;
        if (hour < open || hour >= close) {
          throw Exception('Waktu booking di luar jam kerja');
        }
      }
    }

    return await _firestore.collection('queues').add(dataToSave);
  }

  Future<bool> isSlotAvailable({
    required String barbershopId,
    required String barbermanId,
    required DateTime bookingTime,
    required List<String> serviceIds,
  }) async {
    final start = bookingTime.subtract(const Duration(hours: 4));
    final end = bookingTime.add(const Duration(hours: 4));
    final qs = await _firestore.collection('queues')
        .where('barbershop_id', isEqualTo: barbershopId)
        .where('barberman_id', isEqualTo: barbermanId)
        .where('status', whereIn: ['booked', 'ongoing', 'awaiting_payment'])
        .where('booking_time', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('booking_time', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    for (var doc in qs.docs) {
      final qStart = (doc.data()['booking_time'] as Timestamp).toDate();
      final qDur = (doc.data()['estimated_duration'] as num? ?? 30).toInt();
      final qEnd = qStart.add(Duration(minutes: qDur + 15));
      if (bookingTime.isBefore(qEnd) && bookingTime.add(const Duration(minutes: 30)).isAfter(qStart)) {
        return false;
      }
    }
    return true;
  }

  static bool isBookingLeadTimeSufficient(DateTime bookingTime, {int minMinutes = 30}) {
    return bookingTime.isAfter(DateTime.now().add(Duration(minutes: minMinutes)));
  }

  static const int defaultPaymentWindowMinutes = 15;

  Future<int> getPaymentWindowForBarbershop(String? barbershopId) async {
    if (barbershopId == null) return defaultPaymentWindowMinutes;
    final doc = await _firestore.collection('barbershops').doc(barbershopId).get();
    return (doc.data()?['payment_window_minutes'] ?? defaultPaymentWindowMinutes) as int;
  }

  // 🔍 QUERY HELPERS

  @override
  Future<Queue?> getQueueById(String queueId) async {
    final snap = await _firestore.collection('queues').doc(queueId).get();
    return snap.exists ? Queue.fromFirestore(snap) : null;
  }

  @override
  Stream<Queue?> streamQueueById(String id) {
    return _firestore.collection('queues').doc(id).snapshots().map((s) => s.exists ? Queue.fromFirestore(s) : null);
  }

  @override
  Future<Queue?> resolveQueueForCustomerByIdOrOrder(String idOrOrderId, String customerId) async {
    final doc = await _firestore.collection('queues').doc(idOrOrderId).get();
    if (doc.exists) return Queue.fromFirestore(doc);
    final qs = await _firestore.collection('queues').where('order_id', isEqualTo: idOrOrderId).limit(1).get();
    return qs.docs.isNotEmpty ? Queue.fromFirestore(qs.docs.first) : null;
  }

  @override
  Future<void> submitPaymentProofForQueue({required String queueId, required String userId, required String base64Proof}) async {
    await _firestore.collection('queues').doc(queueId).update({
      'payment_proof_base64': base64Proof,
      'payment_verification_status': 'pending',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<int> cancelExpiredWaitingQueuesForCustomer(String customerId) async {
    final now = Timestamp.now();
    final qs = await _firestore.collection('queues')
        .where('customer_id', isEqualTo: customerId)
        .where('status', isEqualTo: 'waiting')
        .where('payment_deadline', isLessThan: now)
        .get();
    for (var doc in qs.docs) {
      await doc.reference.update({'status': 'cancelled', 'cancellation_reason': 'Expired'});
    }
    return qs.size;
  }

  @override
  Future<int> cancelExpiredAwaitingPaymentQueuesForCustomer(String customerId) async {
    final now = Timestamp.now();
    final qs = await _firestore.collection('queues')
        .where('customer_id', isEqualTo: customerId)
        .where('status', isEqualTo: 'awaiting_payment')
        .where('payment_deadline', isLessThan: now)
        .get();
    for (var doc in qs.docs) {
      await doc.reference.update({'status': 'cancelled', 'cancellation_reason': 'Expired'});
    }
    return qs.size;
  }

  Stream<List<Queue>> streamAllQueues({String? barbershopId, List<String>? statusFilter}) {
    Query query = _firestore.collection('queues');
    if (barbershopId != null) query = query.where('barbershop_id', isEqualTo: barbershopId);
    if (statusFilter != null) query = query.where('status', whereIn: statusFilter);
    return query.snapshots().map((s) => s.docs.map((d) => Queue.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }

  Future<void> customerRequestCancellation(String queueId, {required String reason, String? customerId}) async {
    await _firestore.collection('queues').doc(queueId).update({
      'status': 'cancellation_requested',
      'cancellation_reason': reason,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> withdrawCancellationRequest(String queueId) async {
    await _firestore.collection('queues').doc(queueId).update({
      'status': 'booked',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createNotificationForUser(String userId, String title, String body, String queueId) async {
    await _firestore.collection('notifications').add({
      'user_id': userId,
      'title': title,
      'body': body,
      'queue_id': queueId,
      'created_at': FieldValue.serverTimestamp(),
      'read': false,
    });
  }
}