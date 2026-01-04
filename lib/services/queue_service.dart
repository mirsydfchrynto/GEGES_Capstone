// lib/services/queue_service.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // Needed for DateTimeRange
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
  // 🧑‍🔧 HELPER METHODS
  // -----------------------

  bool _safeBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase().trim() == 'true';
    if (value is num) return value == 1;
    return defaultValue;
  }

  bool isBarberHolidayRaw(Map<String, dynamic> data, DateTime date) {
    // Stripping time components for accurate daily comparison
    final targetDate = DateTime(date.year, date.month, date.day);
    final dayName = DateFormat('EEEE', 'en_US').format(targetDate).toLowerCase();
    
    final rawOffDays = data['offDays'];
    final List<String> offDays = (rawOffDays is List) 
        ? rawOffDays.map((e) => e.toString().toLowerCase().trim()).toList()
        : [];
    if (offDays.contains(dayName)) return true;

    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final rawSpecific = data['specificOffDays'];
    final List<String> specificOffDays = (rawSpecific is List) ? rawSpecific.map((e) => e.toString().trim()).toList() : [];
    return specificOffDays.contains(dateStr);
  }

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
  // 📅 AVAILABILITY HELPERS
  // -----------------------

  Future<List<DateTimeRange>> getBarberBusyTimeRanges(String barbermanId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    try {
      final barberDoc = await _firestore.collection('barbermen').doc(barbermanId).get();
      if (barberDoc.exists) {
        final data = barberDoc.data()!;
        if (!_safeBool(data['isActive'], defaultValue: true) || _safeBool(data['onLeave']) || isBarberHolidayRaw(data, date)) return [DateTimeRange(start: startOfDay, end: endOfDay)];
      }
      final qs = await _firestore.collection('queues').where('barberman_id', isEqualTo: barbermanId).where('status', whereIn: ['booked', 'ongoing', 'awaiting_payment']).where('booking_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay)).where('booking_time', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay)).get();
      final List<DateTimeRange> busySlots = [];
      for (var doc in qs.docs) {
        final data = doc.data();
        final start = (data['booking_time'] as Timestamp).toDate();
        final duration = (data['estimated_duration'] as num? ?? 30).toInt();
        busySlots.add(DateTimeRange(start: start, end: start.add(Duration(minutes: duration + 10))));
      }
      return busySlots;
    } catch (e) { return []; }
  }

  Future<List<DateTimeRange>> getShopBusySlots({required String barbershopId, required DateTime date}) async {
    final barbersDocs = await _firestore.collection('barbermen').where('barbershop_id', isEqualTo: barbershopId).where('isActive', isEqualTo: true).get();
    int availableBarbersCount = 0;
    for (var doc in barbersDocs.docs) {
      final data = doc.data();
      if (!_safeBool(data['onLeave']) && !isBarberHolidayRaw(data, date)) availableBarbersCount++;
    }
    if (availableBarbersCount == 0) return [DateTimeRange(start: DateTime(date.year, date.month, date.day), end: DateTime(date.year, date.month, date.day, 23, 59, 59))];
    final startDay = DateTime(date.year, date.month, date.day);
    final qs = await _firestore.collection('queues').where('barbershop_id', isEqualTo: barbershopId).where('status', whereIn: ['booked', 'ongoing', 'awaiting_payment']).where('booking_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startDay)).where('booking_time', isLessThanOrEqualTo: Timestamp.fromDate(startDay.add(const Duration(days: 1)))).get();
    Map<int, int> slotCounts = {};
    for (var doc in qs.docs) {
      final start = (doc.data()['booking_time'] as Timestamp).toDate();
      final dur = (doc.data()['estimated_duration'] as num? ?? 30).toInt();
      for (int t = start.hour * 60 + start.minute; t < start.hour * 60 + start.minute + dur; t += 30) {
        int gridSlot = (t ~/ 30) * 30;
        slotCounts[gridSlot] = (slotCounts[gridSlot] ?? 0) + 1;
      }
    }
    List<DateTimeRange> fullSlots = [];
    slotCounts.forEach((timeMin, barberCount) {
      if (barberCount >= availableBarbersCount) {
        final s = DateTime(date.year, date.month, date.day, timeMin ~/ 60, timeMin % 60);
        fullSlots.add(DateTimeRange(start: s, end: s.add(const Duration(minutes: 30))));
      }
    });
    return fullSlots;
  }

  Future<int> cancelExpiredBookings(String barbershopId) async {
    try {
      final now = DateTime.now();
      final qs = await _firestore.collection('queues').where('barbershop_id', isEqualTo: barbershopId).where('status', isEqualTo: 'awaiting_payment').get();
      final batch = _firestore.batch();
      int count = 0;
      for (var doc in qs.docs) {
        final deadline = doc.data()['payment_deadline'] as Timestamp?;
        if (deadline != null && now.isAfter(deadline.toDate())) {
          batch.update(doc.reference, { 'status': 'cancelled', 'cancellation_reason': 'System: Pembayaran kadaluwarsa (Auto-Cancel)', 'cancelled_by_uid': 'system_auto', 'cancelled_at': FieldValue.serverTimestamp(), 'updated_at': FieldValue.serverTimestamp() });
          count++;
        }
      }
      if (count > 0) await batch.commit();
      return count;
    } catch (e) { return 0; }
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
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final hasProof = (data['payment_proof_base64'] as String?)?.isNotEmpty ?? false;
    
    if (hasProof) {
      await ref.update({
        'status': 'cancelled',
        'is_refunded': true,
        'refunded_at': FieldValue.serverTimestamp(),
        'refunded_by': adminUid ?? 'admin',
        'refund_reason': reason ?? 'Refunded by admin',
        'updated_at': FieldValue.serverTimestamp(),
        'payment_proof_base64': FieldValue.delete(),
      });
    } else {
      await ref.update({
        'status': 'cancelled',
        'cancelled_by_uid': adminUid ?? 'admin',
        'cancellation_reason': reason ?? 'Cancelled by admin',
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
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
        if (bsDoc.exists) {
          final open = (bsDoc.data()?['open_hour'] ?? 9) as int;
          final close = (bsDoc.data()?['close_hour'] ?? 21) as int;
          final hour = bookingTs.toDate().hour;
          if (hour < open || hour >= close) {
            throw Exception('Waktu booking di luar jam kerja');
          }
        }
        
        // Auto-set payment deadline if status warrants it
        final status = dataToSave['status'] as String?;
        if (status == 'waiting' || status == 'awaiting_payment') {
           final window = await getPaymentWindowForBarbershop(bsId);
           dataToSave['payment_deadline'] = Timestamp.fromDate(DateTime.now().add(Duration(minutes: window)));
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
    if (barbershopId == null || barbershopId.isEmpty) return defaultPaymentWindowMinutes;
    try {
      final doc = await _firestore.collection('barbershops').doc(barbershopId).get();
      if (!doc.exists) return defaultPaymentWindowMinutes;
      final data = doc.data() ?? {};
      final raw = data['payment_window_minutes'] ?? data['paymentWindowMinutes'];
      
      if (raw is int) return raw;
      if (raw is double) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? defaultPaymentWindowMinutes;
      if (raw is num) return raw.toInt();
      
      return defaultPaymentWindowMinutes;
    } catch (_) {
      return defaultPaymentWindowMinutes;
    }
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
    if (doc.exists) {
      final q = Queue.fromFirestore(doc);
      return q.customerId == customerId ? q : null;
    }
    final qs = await _firestore.collection('queues').where('order_id', isEqualTo: idOrOrderId).limit(1).get();
    if (qs.docs.isEmpty) return null;
    final q = Queue.fromFirestore(qs.docs.first);
    return q.customerId == customerId ? q : null;
  }

  @override
  Future<void> submitPaymentProofForQueue({required String queueId, required String userId, required String base64Proof}) async {
    final ref = _firestore.collection('queues').doc(queueId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Not found');
      
      final data = snap.data() ?? {};
      if (data['customer_id'] != userId) {
        throw Exception('Unauthorized access to this queue');
      }

      final totalPrice = (data['total_price'] as num? ?? 0).toInt();
      tx.set(ref, {
        'payment_proof_base64': base64Proof,
        'payment_verification_status': 'pending',
        'payment': {
          'verificationStatus': 'pending',
          'proofUrl': base64Proof,
          'proofUploadedAt': FieldValue.serverTimestamp(),
          'proofUploadedBy': userId,
          'proofLocked': true
        },
        'refund_amount': (totalPrice * 0.9).toInt(),
        'updated_at': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
    });
  }

  Future<void> customerRequestCancellation(String queueId, {required String reason, String? customerId}) async {
    final ref = await _resolveQueueDocRef(queueId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref); if (!snap.exists) throw Exception('Not found');
      final data = snap.data() ?? {};
      
      if (data['status'] == 'awaiting_payment') {
        final proof = data['payment_proof_base64'] as String?;
        if (proof == null || proof.isEmpty) throw Exception('No proof');
      }
      
      final price = (data['total_price'] as num? ?? 0).toInt();
      tx.update(ref, { 
        'status': 'cancellation_requested', 
        'cancellation_reason': reason, 
        'refund_amount': (price * 0.9).toInt(), 
        'refund_deduction': price - (price * 0.9).toInt(), 
        'updated_at': FieldValue.serverTimestamp() 
      });
    });
  }

  Future<int> cancelExpiredWaitingQueuesForCustomer(String customerId) async {
    try {
      final qs = await _firestore.collection('queues').where('customer_id', isEqualTo: customerId).where('status', isEqualTo: 'waiting').get();
      return _cancelExpiredDocs(qs.docs);
    } catch (e) {
      if (e is FirebaseException && e.code == 'failed-precondition') {
        final allQs = await _firestore.collection('queues').where('customer_id', isEqualTo: customerId).get();
        return _cancelExpiredDocs(allQs.docs.where((d) => d.data()['status'] == 'waiting').toList());
      }
      rethrow;
    }
  }

  @override
  Future<int> cancelExpiredAwaitingPaymentQueuesForCustomer(String customerId) async {
    try {
      final qs = await _firestore.collection('queues').where('customer_id', isEqualTo: customerId).where('status', isEqualTo: 'awaiting_payment').get();
      return _cancelExpiredDocs(qs.docs);
    } catch (e) {
      if (e is FirebaseException && e.code == 'failed-precondition') {
        final allQs = await _firestore.collection('queues').where('customer_id', isEqualTo: customerId).get();
        return _cancelExpiredDocs(allQs.docs.where((d) => d.data()['status'] == 'awaiting_payment').toList());
      }
      rethrow;
    }
  }

  Future<int> _cancelExpiredDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final now = Timestamp.now();
    int count = 0;
    for (var doc in docs) {
      final dl = doc.data()['payment_deadline'] as Timestamp?;
      if (dl != null && dl.compareTo(now) < 0) {
        await doc.reference.update({'status': 'cancelled', 'cancellation_reason': 'Expired'});
        count++;
      }
    }
    return count;
  }

  Stream<List<Queue>> streamAllQueues({String? barbershopId, List<String>? statusFilter}) {
    Query query = _firestore.collection('queues');
    if (barbershopId != null) query = query.where('barbershop_id', isEqualTo: barbershopId);
    if (statusFilter != null) query = query.where('status', whereIn: statusFilter);
    return query.snapshots().map((s) => s.docs.map((d) => Queue.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList());
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