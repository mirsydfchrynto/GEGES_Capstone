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
  final Map<String, int> _serviceDurationCache = {};

  QueueService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // -----------------------
  // 🧠 FAIR ASSIGNMENT ALGORITHM
  // -----------------------

  /// Mencari barberman terbaik secara otomatis berdasarkan:
  /// 1. Ketersediaan (tidak libur & tidak ada booking bentrok)
  /// 2. Keadilan (prioritas barber dengan jumlah potong bulanan paling sedikit)
  Future<String?> getFairAvailableBarberman({
    required String barbershopId,
    required DateTime bookingTime,
    required List<String> serviceIds,
  }) async {
    try {
      // 1. Ambil semua hairstylist AKTIF di barbershop tersebut
      final barbersDocs = await _firestore
          .collection('barbermen')
          .where('barbershop_id', isEqualTo: barbershopId)
          .where('isActive', isEqualTo: true)
          .get();

      if (barbersDocs.docs.isEmpty) {
        debugPrint("getFairAvailableBarberman: No active hairstylists found for shop $barbershopId");
        return null;
      }

      final List<Map<String, dynamic>> eligibleBarbers = [];
      final List<Map<String, dynamic>> fallbackBarbers = [];

      for (var doc in barbersDocs.docs) {
        final barberData = doc.data();
        final barberId = doc.id;
        final barberName = barberData['name'] ?? 'Unknown';
        
        final monthlyCount = (barberData['monthly_haircut_count'] as num?)?.toInt() ?? 
                             (barberData['monthlyHaircutCount'] as num?)?.toInt() ?? 0;
        
        final barberInfo = {
          'id': barberId,
          'monthlyCount': monthlyCount,
          'name': barberName,
        };

        // Simpan semua sebagai fallback jika yang ideal tidak ketemu
        fallbackBarbers.add(barberInfo);

        // 2. Filter Ideal (Ketersediaan & Libur)
        bool isOnLeave = barberData['onLeave'] ?? false;
        if (isOnLeave) {
          debugPrint("getFairAvailableBarberman: $barberName is on leave (ideal skip)");
          continue;
        }

        final dayName = DateFormat('EEEE', 'en_US').format(bookingTime).toLowerCase();
        final List<dynamic> offDays = barberData['offDays'] ?? [];
        if (offDays.contains(dayName)) {
          debugPrint("getFairAvailableBarberman: $barberName is off on $dayName (ideal skip)");
          continue;
        }

        final dateStr = DateFormat('yyyy-MM-dd').format(bookingTime);
        final List<dynamic> specificOffDays = barberData['specificOffDays'] ?? [];
        if (specificOffDays.contains(dateStr)) {
          debugPrint("getFairAvailableBarberman: $barberName has holiday on $dateStr (ideal skip)");
          continue;
        }

        // 3. Cek bentrokan jadwal (Termasuk Ghost check)
        final isAvailable = await isSlotAvailable(
          barbershopId: barbershopId,
          barbermanId: barberId,
          bookingTime: bookingTime,
          serviceIds: serviceIds,
        );

        if (!isAvailable) {
          debugPrint("getFairAvailableBarberman: $barberName has conflict (ideal skip)");
          continue;
        }

        // Hairstylist lolos semua kriteria ideal
        eligibleBarbers.add(barberInfo);
      }

      // RUMUS FLEKSIBEL:
      // Gunakan yang ideal jika ada. Jika tidak ada yang ideal (semua libur/sibuk), 
      // gunakan fallback (semua yang aktif) agar user tetap bisa dapet jadwal.
      final List<Map<String, dynamic>> finalCandidates = 
          eligibleBarbers.isNotEmpty ? eligibleBarbers : fallbackBarbers;

      if (finalCandidates.isEmpty) return null;

      // 4. Keadilan & Pengacakan:
      // Kocok urutan agar jika monthlyCount sama, hasilnya acak (Fair Random).
      finalCandidates.shuffle(Random());

      // 5. Sorting berdasarkan Monthly Count (Paling sedikit diprioritaskan)
      finalCandidates.sort((a, b) => (a['monthlyCount'] as int).compareTo(b['monthlyCount'] as int));

      final selectedId = finalCandidates.first['id'] as String;
      debugPrint("getFairAvailableBarberman: Selected ${eligibleBarbers.isNotEmpty ? 'IDEAL' : 'FALLBACK'} hairstylist: ${finalCandidates.first['name']} ($selectedId)");
      return selectedId;
    } catch (e, st) {
      debugPrint("Error in getFairAvailableBarberman: $e\n$st");
      return null;
    }
  }

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
  // Helper to resolve identifier across 'queues' and legacy 'bookings' collections.
  Future<DocumentReference<Map<String, dynamic>>> _resolveQueueDocRef(
    String id,
  ) async {
    final queuesRef = _firestore.collection('queues').doc(id);
    final qSnap = await queuesRef.get();
    if (qSnap.data() != null) return queuesRef;
    final bookingsRef = _firestore.collection('bookings').doc(id);
    final bSnap = await bookingsRef.get();
    if (bSnap.data() != null) return bookingsRef;
    return queuesRef; // fallback reference (will not exist)
  }

  Future<void> startService(String queueId) async {
    try {
      final ref = await _resolveQueueDocRef(queueId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('Queue not found: $queueId');

      await ref.update({
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
  Future<void> finishService(String queueId, [Timestamp? startTime]) async {
    try {
      final ref = await _resolveQueueDocRef(queueId);
      final snap = await ref.get();
      if (!snap.exists) throw Exception('Queue not found: $queueId');

      // If startTime not provided, read start_time from the document
      Timestamp startTs = startTime ?? Timestamp.now();
      if (startTime == null) {
        final s = snap.data()?['start_time'] as Timestamp?;
        if (s != null) startTs = s;
      }

      final finishTime = Timestamp.now();
      int actualDurationInMinutes =
          (finishTime.seconds - startTs.seconds) ~/ 60;
      if (actualDurationInMinutes <= 0) actualDurationInMinutes = 1;

      await ref.update({
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
  @override
  Future<void> cancelQueue(
    String queueId, {
    String reason = 'Admin/Barberman Cancellation',
    String? cancelledBy,
  }) async {
    try {
      final by =
          cancelledBy ?? _auth.currentUser?.uid ?? 'system';
      await _firestore.collection('queues').doc(queueId).update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_by_uid': by,
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
    // IMPORTANT: For safety we no longer directly move to 'booked' here.
    // To enforce the payment-first flow, delegate to adminConfirmRequest
    // which will set 'awaiting_payment' and create a payment deadline.
    debugPrint(
      'manualConfirmBooking() called - delegating to adminConfirmRequest to enforce payment flow',
    );
    await adminConfirmRequest(queueId, adminUid: adminUid);
  }

  /// Tolak manual admin → status cancelled
  Future<void> manualRejectBooking(
    String queueId, {
    String? reason,
    String? adminUid,
  }) async {
    final confirmedBy =
        adminUid ?? _auth.currentUser?.uid ?? 'admin';
    try {
      final ref = await _resolveQueueDocRef(queueId);
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
      final doc = await ref.get();
      final customerId = doc.data()?['customer_id'] as String?;
      if (customerId != null) {
        await _createNotificationForUser(
          customerId,
          'Booking Ditolak',
          'Booking Anda ditolak oleh admin.',
          queueId,
        );
      }
    } catch (e, st) {
      debugPrint('Error manualRejectBooking($queueId): $e\n$st');
      rethrow;
    }
  }

  /// Delete queue document (Customer Action - Hapus Pesanan)
  /// Only allowed for served or cancelled status to clean up history
  Future<void> deleteQueue(String queueId) async {
    try {
      await _firestore.collection('queues').doc(queueId).delete();
    } catch (e) {
      debugPrint("Error deleting queue $queueId: $e");
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
          _auth.currentUser?.uid,
      'barberman_id': queueData['barberman_id'] ?? queueData['barbermanId'],
      'service_ids':
          queueData['service_ids'] ??
          (queueData['service_id'] != null
              ? [queueData['service_id']]
              : queueData['serviceIds'] ?? []),
      'total_price': queueData['total_price'] ?? queueData['totalPrice'],
      // Barber selection fee (optional)
      'barber_selection_fee':
          queueData['barber_selection_fee'] ??
          queueData['barberSelectionFee'] ??
          0,
      'paid_barber_selection':
          queueData['paid_barber_selection'] ??
          queueData['paidBarberSelection'] ??
          false,
      'estimated_duration':
          queueData['estimated_duration'] ?? queueData['estimatedDuration'],
      'booking_time': bookingTs ?? FieldValue.serverTimestamp(),
      // crucial: default to 'waiting' so admin must confirm to become 'booked'
      'status': queueData['status'] ?? 'waiting',
      // optional client-provided payment expiry (Timestamp). If not provided and status == 'waiting', we'll set below.
      'payment_deadline':
          queueData['payment_due_at'] ?? queueData['payment_deadline'],
      'created_at': FieldValue.serverTimestamp(),
      'payment_proof_base64':
          queueData['payment_proof_base64'] ?? queueData['payment_proof'],
      'payment_method': queueData['payment_method'],
      'payment_amount': queueData['payment_amount'],
      'order_id': queueData['order_id'],
      'notes': queueData['notes'],
    };
    // remove nulls so Firestore doc stays clean
    dataToSave.removeWhere((_, v) => v == null);

    // If client created a booking already intending to pay (awaiting_payment),
    // ensure payment_deadline is set and mark as approved for compatibility
    if ((dataToSave['status'] as String?) == 'awaiting_payment') {
      try {
        if (dataToSave['payment_deadline'] == null) {
          final shopId = dataToSave['barbershop_id'] as String?;
          final window = await getPaymentWindowForBarbershop(shopId);
          final due = DateTime.now().add(Duration(minutes: window));
          dataToSave['payment_deadline'] = Timestamp.fromDate(due);
        }
        dataToSave['request_status'] =
            dataToSave['request_status'] ?? 'approved';
      } catch (e) {
        debugPrint('Failed to set awaiting_payment defaults: $e');
      }
    }

    // If status is 'waiting' and no payment_due_at provided, set a 10-minute expiry from now.
    if ((dataToSave['status'] as String?) == 'waiting' &&
        dataToSave['payment_deadline'] == null) {
      try {
        final shopId = dataToSave['barbershop_id'] as String?;
        final window = await getPaymentWindowForBarbershop(shopId);
        final due = DateTime.now().add(Duration(minutes: window));
        dataToSave['payment_deadline'] = Timestamp.fromDate(due);
      } catch (e) {
        debugPrint('Failed to set payment_deadline: $e');
      }
    }

    // --- Validation: booking time not in the past and within shop hours ---
    try {
      final bookingTsLocal = dataToSave['booking_time'] as Timestamp?;
      if (bookingTsLocal != null) {
        final bookingDt = bookingTsLocal.toDate();
        final now = DateTime.now();
        if (bookingDt.isBefore(now.subtract(const Duration(seconds: 5)))) {
          throw Exception('Waktu booking sudah lewat');
        }

        // Enforce business rule: booking must be made at least 30 minutes
        // before the selected booking time to avoid immediate collisions.
        if (!QueueService.isBookingLeadTimeSufficient(
          bookingDt,
          minMinutes: 30,
        )) {
          throw Exception(
            'Booking harus dibuat minimal 30 menit sebelum waktu mulai',
          );
        }

        // If barbershop supplied, verify within open/close hours
        final barbershopId = dataToSave['barbershop_id'] as String?;
        if (barbershopId != null) {
          final bsDoc = await _firestore
              .collection('barbershops')
              .doc(barbershopId)
              .get();
          final bsData = bsDoc.data();
          int parseHour(dynamic v, int fallback) {
            if (v == null) return fallback;
            if (v is int) return v;
            if (v is String) {
              if (v.contains(':')) {
                return int.tryParse(v.split(':').first) ?? fallback;
              }
              return int.tryParse(v) ?? fallback;
            }
            return fallback;
          }

          final open = parseHour(
            bsData?['open_hour'] ?? bsData?['openHour'],
            9,
          );
          final close = parseHour(
            bsData?['close_hour'] ?? bsData?['closeHour'],
            21,
          );

          final estDuration = (dataToSave['estimated_duration'] as int?) ?? 0;
          final finish = bookingDt.add(Duration(minutes: estDuration));
          final dayOpen = DateTime(
            bookingDt.year,
            bookingDt.month,
            bookingDt.day,
            open,
          );
          final dayClose = DateTime(
            bookingDt.year,
            bookingDt.month,
            bookingDt.day,
            close,
          );

          if (bookingDt.isBefore(dayOpen) || finish.isAfter(dayClose)) {
            throw Exception('Waktu booking di luar jam kerja barbershop');
          }
        }
      }
    } catch (e) {
      debugPrint('Validation failed before creating queue: $e');
      rethrow;
    }

    try {
      // Use transaction to ensure we don't create conflicting bookings
      final docRef = await _firestore
          .runTransaction<DocumentReference<Map<String, dynamic>>>((tx) async {
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
                throw Exception(
                  'Slot tidak tersedia - booking bentrok dengan antrean lain',
                );
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

  /// Create queue with an `order_index` uniqueness guard. If `order_id` is
  /// provided, this transaction will ensure only one queue is created for that
  /// order. If an existing index exists it will return the existing queue
  /// document reference instead of creating a duplicate.
  Future<DocumentReference<Map<String, dynamic>>> createQueueWithOrderIndex(
    Map<String, dynamic> queueData,
  ) async {
    final orderId =
        queueData['order_id'] as String? ?? queueData['orderId'] as String?;

    // If no orderId supplied, fall back to regular createQueue behavior.
    if (orderId == null || orderId.isEmpty) {
      return createQueue(queueData);
    }

    final orderIndexRef = _firestore.collection('order_index').doc(orderId);

    try {
      final docRef = await _firestore
          .runTransaction<DocumentReference<Map<String, dynamic>>>((tx) async {
            final idxSnap = await tx.get(orderIndexRef);
            if (idxSnap.exists) {
              final existing = idxSnap.data()?['queue_id'] as String?;
              if (existing != null && existing.isNotEmpty) {
                // Return existing queue ref
                return _firestore.collection('queues').doc(existing);
              }
              // If an index exists but no queue_id yet, abort to avoid racing.
              throw Exception('order_id already reserved — try again shortly');
            }

            // Build minimal data payload (normalize booking_time similar to createQueue)
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
              'barbershop_id':
                  queueData['barbershop_id'] ?? queueData['barbershopId'],
              'customer_id':
                  queueData['customer_id'] ??
                  queueData['customerId'] ??
                  _auth.currentUser?.uid,
              'barberman_id':
                  queueData['barberman_id'] ?? queueData['barbermanId'],
              'service_ids':
                  queueData['service_ids'] ??
                  (queueData['service_id'] != null
                      ? [queueData['service_id']]
                      : queueData['serviceIds'] ?? []),
              'total_price':
                  queueData['total_price'] ?? queueData['totalPrice'],
              'estimated_duration':
                  queueData['estimated_duration'] ??
                  queueData['estimatedDuration'],
              'booking_time': bookingTs ?? FieldValue.serverTimestamp(),
              'status': queueData['status'] ?? 'waiting',
              'payment_deadline':
                  queueData['payment_due_at'] ?? queueData['payment_deadline'],
              'created_at': FieldValue.serverTimestamp(),
              'payment_proof_base64':
                  queueData['payment_proof_base64'] ??
                  queueData['payment_proof'],
              'payment_method': queueData['payment_method'],
              'payment_amount': queueData['payment_amount'],
              'order_id': orderId,
              'notes': queueData['notes'],
            };

            dataToSave.removeWhere((_, v) => v == null);

            if ((dataToSave['status'] as String?) == 'waiting' &&
                dataToSave['payment_deadline'] == null) {
              // Respect per-barbershop payment window if available
              final bsId =
                  queueData['barbershop_id'] ?? queueData['barbershopId'];
              final window = await getPaymentWindowForBarbershop(
                bsId as String?,
              );
              final due = DateTime.now().add(Duration(minutes: window));
              dataToSave['payment_deadline'] = Timestamp.fromDate(due);
            }

            // Create queue doc and index atomically
            final queuesColl = _firestore.collection('queues');
            final newRef = queuesColl.doc();
            tx.set(newRef, dataToSave);
            tx.set(orderIndexRef, {
              'queue_id': newRef.id,
              'created_at': FieldValue.serverTimestamp(),
            });

            return newRef;
          });

      return docRef;
    } catch (e) {
      debugPrint('Error createQueueWithOrderIndex: $e');
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

      // Optimasi: Ambil antrean dalam rentang +/- 12 jam dari waktu booking
      // untuk menangkap potensi overlap yang melewati tengah malam tanpa membebani performa.
      final DateTime startRange = bookingTime.subtract(const Duration(hours: 12));
      final DateTime endRange = bookingTime.add(const Duration(hours: 12));

      // include 'awaiting_payment' because awaiting payment should lock the slot
      final QuerySnapshot<Map<String, dynamic>> qs = await _firestore
          .collection('queues')
          .where('barbershop_id', isEqualTo: barbershopId)
          .where('barberman_id', isEqualTo: barbermanId)
          .where('status', whereIn: ['booked', 'ongoing', 'awaiting_payment'])
          .where('booking_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startRange))
          .where('booking_time', isLessThanOrEqualTo: Timestamp.fromDate(endRange))
          .get();

      for (final doc in qs.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        
        // --- SMART GHOST CHECK ---
        // Abaikan booking 'awaiting_payment' yang sudah lewat deadline-nya (kadaluarsa)
        // Ini mencegah slot terkunci selamanya jika customer tidak bayar.
        if (status == 'awaiting_payment') {
          final deadline = data['payment_deadline'] as Timestamp?;
          final hasProof = (data['payment_proof_base64'] != null && data['payment_proof_base64'].toString().isNotEmpty) ||
                           (data['payment'] != null && (data['payment']['proofUrl'] != null));
          
          if (deadline != null && deadline.toDate().isBefore(DateTime.now()) && !hasProof) {
            debugPrint("isSlotAvailable: Skipping expired ghost booking ${doc.id}");
            continue; 
          }
        }

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
          Duration(minutes: existingDuration + 15), // 15 min buffer
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

  /// Check that a booking is at least [minMinutes] ahead of now.
  /// Returns true when `bookingTime` is at least `minMinutes` in the future.
  static bool isBookingLeadTimeSufficient(
    DateTime bookingTime, {
    int minMinutes = 30,
  }) {
    final minLead = DateTime.now().add(Duration(minutes: minMinutes));
    return bookingTime.isAfter(minLead) ||
        bookingTime.isAtSameMomentAs(minLead);
  }

  /// Default payment window in minutes when barbershop doesn't override.
  static const int defaultPaymentWindowMinutes = 10;

  /// Resolve payment window (in minutes) for a given barbershop.
  /// Returns [defaultPaymentWindowMinutes] when the barbershop doesn't
  /// specify a value or when an error occurs reading it.
  /// Resolve payment window (in minutes) for a given barbershop.
  /// Public for testing.
  Future<int> getPaymentWindowForBarbershop(String? barbershopId) async {
    if (barbershopId == null || barbershopId.isEmpty) {
      return QueueService.defaultPaymentWindowMinutes;
    }
    try {
      final doc = await _firestore
          .collection('barbershops')
          .doc(barbershopId)
          .get();
      final data = doc.data() ?? {};
      final raw =
          data['payment_window_minutes'] ?? data['paymentWindowMinutes'];
      if (raw == null) return QueueService.defaultPaymentWindowMinutes;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) {
        final parsed = int.tryParse(raw);
        if (parsed != null) return parsed;
      }
      return QueueService.defaultPaymentWindowMinutes;
    } catch (e) {
      debugPrint('Failed to read paymentWindowMinutes for $barbershopId: $e');
      return QueueService.defaultPaymentWindowMinutes;
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

  /// Admin confirms payment: awaiting_payment → booked (service belum dimulai)
  /// This is the second admin step: verify uploaded payment proof and then
  /// mark the booking as officially booked so it enters the live queue.
  Future<void> adminConfirmPayment(
    String queueId, {
    String? adminUid,
    String? adminNotes,
  }) async {
    final confirmedBy =
        adminUid ?? _auth.currentUser?.uid ?? 'admin';

    try {
      final ref = await _resolveQueueDocRef(queueId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        // only allow confirming payment when admin previously approved and
        // the queue is awaiting payment
        if ((data['status'] as String?) != 'awaiting_payment') {
          throw Exception(
            'Queue status is not awaiting_payment (current: ${data['status']})',
          );
        }

        // ensure payment proof exists
        final paymentProof = data['payment_proof_base64'] as String?;
        if (paymentProof == null || paymentProof.isEmpty) {
          throw Exception('No payment proof uploaded for this queue');
        }

        tx.update(ref, {
          'status': 'booked',
          'payment_confirmed_at': FieldValue.serverTimestamp(),
          'payment_confirmed_by': confirmedBy,
          'admin_payment_notes': adminNotes,
          'booked_at': FieldValue.serverTimestamp(),
          'booked_by': confirmedBy,
          'updated_at': FieldValue.serverTimestamp(),
          // Unified Schema synchronization
          'payment.verificationStatus': 'accepted',
          'payment.verificationAcceptedAt': FieldValue.serverTimestamp(),
          'payment.verificationAcceptedBy': confirmedBy,
          'payment.verificationNotes': adminNotes,
          'payment_verification_status': 'accepted',
        });
      });
      // after successful transaction, notify customer
      final afterDoc = await ref.get();
      final afterData = afterDoc.data();
      final customerId = afterData?['customer_id'] as String?;
      if (customerId != null) {
        await _createNotificationForUser(
          customerId,
          'Pembayaran Dikonfirmasi',
          'Pembayaran Anda telah diverifikasi. Booking Anda sekarang terkonfirmasi.',
          queueId,
        );
      }
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
        adminUid ?? _auth.currentUser?.uid ?? 'admin';

    try {
      final ref = await _resolveQueueDocRef(queueId);
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
          // Unified Schema synchronization
          'payment.verificationStatus': 'rejected',
          'payment.verificationRejectedAt': FieldValue.serverTimestamp(),
          'payment.verificationRejectedBy': confirmedBy,
          'payment.rejectionReason': reason,
          'payment.proofLocked': false, // Allow re-upload
          'payment_verification_status': 'rejected',
        });
      });
      final afterDoc = await ref.get();
      final afterData = afterDoc.data();
      final customerId = afterData?['customer_id'] as String?;
      if (customerId != null) {
        await _createNotificationForUser(
          customerId,
          'Pembayaran Ditolak',
          'Pembayaran Anda ditolak oleh admin. Silakan unggah bukti lagi atau hubungi admin.',
          queueId,
        );
      }
    } catch (e, st) {
      debugPrint('Error adminRejectPayment($queueId): $e\n$st');
      rethrow;
    }
  }

  /// Admin refund a booking - hapus bukti pembayaran, set isRefunded=true
  /// Dipanggil ketika:
  /// - Admin membatalkan booking
  /// - Admin menerima request pembatalan dari customer
  /// - Refund diproses manual atau otomatis
  Future<void> adminRefundBooking(
    String queueId, {
    String? reason = 'Dibatalkan oleh admin',
    String? adminUid,
  }) async {
    final refundedBy =
        adminUid ?? _auth.currentUser?.uid ?? 'admin';

    try {
      final ref = await _resolveQueueDocRef(queueId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');

        final data = snap.data() ?? {};
        final hasPaymentProof =
            (data['payment_proof_base64'] as String?)?.isNotEmpty ?? false;
        final hasVerifiedBy =
            (data['verified_by'] as String?)?.isNotEmpty ?? false;

        if (!hasPaymentProof && !hasVerifiedBy) {
          // No payment found: perform a plain cancel, do not mark as refunded
          tx.update(ref, {
            'status': 'cancelled',
            'cancellation_reason': reason ?? 'Dibatalkan oleh admin',
            'cancelled_by_uid': refundedBy,
            'cancelled_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        } else {
          // Payment exists: process refund fields
          tx.update(ref, {
            'status': 'cancelled',
            'is_refunded': true,
            'refunded_at': FieldValue.serverTimestamp(),
            'refund_reason': reason ?? 'Dibatalkan oleh admin',
            'refunded_by': refundedBy,
            // PENTING: Hapus bukti pembayaran dari database (hide proof)
            'payment_proof_base64': FieldValue.delete(),
            'updated_at': FieldValue.serverTimestamp(),
          });
        }
      });

      // Ambil data updated untuk notifikasi
      final afterDoc = await ref.get();
      final afterData = afterDoc.data();
      final customerId = afterData?['customer_id'] as String?;

      // Kirim notifikasi ke customer bahwa refund sudah diproses
      if (customerId != null) {
        await _createNotificationForUser(
          customerId,
          'Refund Diproses',
          'Pesanan Anda telah dibatalkan dan refund akan diproses. Alasan: $reason',
          queueId,
        );
      }
    } catch (e, st) {
      debugPrint('Error adminRefundBooking($queueId): $e\n$st');
      rethrow;
    }
  }

  /// Create a simple notification doc for a user (helper)
  Future<void> _createNotificationForUser(
    String userId,
    String title,
    String body,
    String queueId,
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'user_id': userId,
        'title': title,
        'body': body,
        'queue_id': queueId,
        'created_at': FieldValue.serverTimestamp(),
        'read': false,
        'delivered': false,
      });
    } catch (e) {
      debugPrint('Failed to create notification for $userId: $e');
    }
  }

  /// Customer requests cancellation: booked → cancellation_requested
  Future<void> customerRequestCancellation(
    String queueId, {
    required String reason,
    String? customerId,
  }) async {
    final uid = customerId ?? _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final ref = await _resolveQueueDocRef(queueId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        final status = data['status'] as String?;
        final payment = data['payment'] as Map<String, dynamic>?;
        final hasProof = (data['payment_proof_base64'] != null &&
                data['payment_proof_base64'].toString().isNotEmpty) ||
            (payment?['proofUrl'] != null);

        // Allow cancellation if booked OR (awaiting_payment AND hasProof)
        if (status != 'booked' &&
            !(status == 'awaiting_payment' && hasProof)) {
          throw Exception(
            'Cannot request cancellation for status: $status (Proof uploaded: $hasProof)',
          );
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

  /// Customer withdraws cancellation request: cancellation_requested → booked
  Future<void> withdrawCancellationRequest(String queueId) async {
    try {
      final ref = await _resolveQueueDocRef(queueId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        if ((data['status'] as String?) != 'cancellation_requested') {
          throw Exception('Hanya bisa menarik pengajuan yang sedang diproses');
        }

        tx.update(ref, {
          'status': 'booked',
          'cancellation_reason': FieldValue.delete(),
          'cancellation_requested_at': FieldValue.delete(),
          'cancellation_requested_by': FieldValue.delete(),
          'refund_amount': FieldValue.delete(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });
    } catch (e, st) {
      debugPrint('Error withdrawCancellationRequest($queueId): $e\n$st');
      rethrow;
    }
  }

  /// Admin process refund: cancellation_requested → refund_completed
  Future<void> adminProcessRefund(
    String queueId, {
    required String refundProofBase64,
    String? adminUid,
    String? adminNotes,
  }) async {
    final processedBy =
        adminUid ?? _auth.currentUser?.uid ?? 'admin';

    try {
      final ref = await _resolveQueueDocRef(queueId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        if ((data['status'] as String?) != 'cancellation_requested') {
          throw Exception(
            'Queue is not in cancellation_requested status (current: ${data['status']})',
          );
        }

        tx.update(ref, {
          'status': 'refund_completed', // New status for completed refunds
          'refund_proof_base64': refundProofBase64,
          'refund_processed_at': FieldValue.serverTimestamp(),
          'refund_processed_by': processedBy,
          'admin_refund_notes': adminNotes,
          'is_refunded': true,
          'payment_proof_base64': FieldValue.delete(), // Delete old payment proof
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      // Notify customer
      final doc = await ref.get();
      final customerId = doc.data()?['customer_id'] as String?;
      if (customerId != null) {
        await _createNotificationForUser(
          customerId,
          'Refund Berhasil',
          'Refund Anda telah diproses. Silakan cek bukti transfer di detail pesanan.',
          queueId,
        );
      }
    } catch (e, st) {
      debugPrint('Error adminProcessRefund($queueId): $e\n$st');
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
        adminUid ?? _auth.currentUser?.uid ?? 'admin';
    try {
      final ref = await _resolveQueueDocRef(queueId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        if ((data['status'] as String?) != 'cancellation_requested') {
          throw Exception(
            'Queue is not in cancellation_requested status (current: ${data['status']})',
          );
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
        adminUid ?? _auth.currentUser?.uid ?? 'admin';
    try {
      final ref = await _resolveQueueDocRef(queueId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Queue not found: $queueId');
        final data = snap.data() ?? {};

        if ((data['status'] as String?) != 'cancellation_requested') {
          throw Exception(
            'Queue is not in cancellation_requested status (current: ${data['status']})',
          );
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
    final uid = customerId ?? _auth.currentUser?.uid;
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
            'Can only rate served bookings (current: ${data['status']})',
          );
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
  @override
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

  /// Stream a single queue document by its id. Returns `null` when document is missing.
  /// This allows UI widgets such as `PaymentScreen` to listen for external updates
  /// (e.g., admin or anti-dup services submitting payment proof) and update immediately.
  @override
  Stream<Queue?> streamQueueById(String id) async* {
    try {
      final ref = _firestore.collection('queues').doc(id);
      await for (final snap in ref.snapshots()) {
        if (!snap.exists) {
          yield null;
        } else {
          yield Queue.fromFirestore(snap);
        }
      }
    } catch (e) {
      debugPrint('Error streamQueueById($id): $e');
      yield null;
    }
  }

  /// Get queue by ID with customer ownership validation
  /// Returns null if queue doesn't exist or doesn't belong to customer
  Future<Queue?> getQueueByIdForCustomer(
    String queueId,
    String customerId,
  ) async {
    try {
      final snap = await _firestore.collection('queues').doc(queueId).get();
      if (!snap.exists) {
        debugPrint('Queue $queueId not found');
        return null;
      }

      final queue = Queue.fromFirestore(snap);

      // Validate ownership
      if (queue.customerId != customerId) {
        debugPrint(
          'Unauthorized: Queue $queueId does not belong to customer $customerId',
        );
        return null;
      }

      return queue;
    } catch (e) {
      debugPrint('Error getQueueByIdForCustomer($queueId): $e');
      return null;
    }
  }

  /// Resolve a queue for a customer by either queue document id or order id.
  ///
  /// Use this when the UI passes an `orderId` (e.g., 'ORD-123...') rather than the
  /// Firestore document id. Returns the Queue if found and owned by the given customer.
  @override
  Future<Queue?> resolveQueueForCustomerByIdOrOrder(
    String idOrOrderId,
    String customerId,
  ) async {
    try {
      // First, try doc id lookup
      final docSnap = await _firestore
          .collection('queues')
          .doc(idOrOrderId)
          .get();
      if (docSnap.exists) {
        final q = Queue.fromFirestore(docSnap);
        if (q.customerId == customerId) return q;
        return null; // found but not owned by customer
      }

      // Fallback: query by order_id
      final qs = await _firestore
          .collection('queues')
          .where('order_id', isEqualTo: idOrOrderId)
          .where('customer_id', isEqualTo: customerId)
          .limit(1)
          .get();
      if (qs.docs.isNotEmpty) {
        return Queue.fromFirestore(qs.docs.first);
      }

      return null;
    } catch (e) {
      debugPrint('Error resolving queue for $idOrOrderId: $e');
      return null;
    }
  }

  /// Submit payment proof for an existing queue document in a transaction.
  ///
  /// This delegates to BookingAntiDuplicateService logic to ensure:
  /// 1. Schema consistency (using nested 'payment' map)
  /// 2. Locking mechanism (prevent double submit)
  /// 3. Proper status transition (pending verification)
  @override
  Future<void> submitPaymentProofForQueue({
    required String queueId,
    required String userId,
    required String base64Proof,
  }) async {
    // Direct usage of BookingAntiDuplicateService logic within the transaction context
    // of the original method to maintain the existing interface but fix the schema.

    final firestore = _firestore;
    final queueRef = firestore.collection('queues').doc(queueId);

    try {
      await firestore.runTransaction((tx) async {
        final qSnap = await tx.get(queueRef);
        if (!qSnap.exists) {
          throw Exception('Queue dokumen tidak ditemukan: $queueId');
        }

        final qData = qSnap.data();
        if (qData == null) throw Exception('Queue data kosong');

        final customerId = qData['customer_id'] as String?;
        if (customerId == null || customerId != userId) {
          throw Exception('Unauthorized: booking bukan milik Anda');
        }

        final paymentMap = Map<String, dynamic>.from(qData['payment'] ?? {});
        if (paymentMap['proofLocked'] == true) {
          throw Exception('Upload sudah terkunci (proofLocked=true)');
        }

        // Apply Unified Schema (Nested 'payment' map)
        // Also keep legacy root fields for backward compatibility if needed by other readers,
        // but the authoritative source is now the 'payment' map.
        tx.update(queueRef, {
          // 1. Nested Schema (Authoritative)
          'payment.proofUrl': base64Proof, // Storing base64 in proofUrl field for now as per legacy
          'payment.proofUploadedAt': FieldValue.serverTimestamp(),
          'payment.proofUploadedBy': userId,
          'payment.proofUploadAttemptCount': FieldValue.increment(1),
          'payment.proofLocked': true,
          'payment.verificationStatus': 'pending',

          // 2. Legacy Flat Schema (Backward Compatibility)
          'payment_proof_base64': base64Proof,
          'payment_method': 'bank_transfer',
          'payment_amount':
              (qData['total_price'] as num?)?.toInt() ??
              qData['payment_amount'] ??
              0,
          'payment_submitted_at': FieldValue.serverTimestamp(),

          // 3. Status Maintenance
          // We do NOT change main status to 'booked' here. It stays 'awaiting_payment'
          // until Admin verifies it. But we ensure verificationStatus is 'pending'.
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      debugPrint(
        'submitPaymentProofForQueue (Unified Schema): transaction complete for $queueId',
      );
    } catch (e) {
      debugPrint('Error submitPaymentProofForQueue($queueId): $e');
      rethrow;
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

  /// Count queues for a specific barbershop and optional status filter.
  /// This is a lightweight `get().size` and should be used for badges/counters.
  Future<int> countQueuesForBarbershop(
    String barbershopId, {
    String? status,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _firestore
          .collection('queues')
          .where('barbershop_id', isEqualTo: barbershopId);
      if (status != null && status.isNotEmpty) {
        q = q.where('status', isEqualTo: status);
      }
      final snap = await q.get();
      return snap.size;
    } catch (e) {
      debugPrint('Error counting queues for $barbershopId status=$status: $e');
      return 0;
    }
  }

  /// Cancel waiting queues for a customer whose payment_due_at has passed.
  /// Re-enabled for Spark (Free) Plan compatibility.
  Future<int> cancelExpiredWaitingQueuesForCustomer(String customerId) async {
    final nowTs = Timestamp.fromDate(DateTime.now());
    try {
      final qs = await _firestore
          .collection('queues')
          .where('customer_id', isEqualTo: customerId)
          .where('status', isEqualTo: 'waiting')
          .where('payment_deadline', isLessThan: nowTs)
          .get();

      int count = 0;
      for (final doc in qs.docs) {
        final data = doc.data();
        final hasProof = (data['payment_proof_base64'] != null &&
                data['payment_proof_base64'].toString().isNotEmpty) ||
            (data['payment'] != null &&
                (data['payment']['proofUrl'] != null ||
                    data['payment']['payment_proof_base64'] != null));

        if (hasProof) continue;

        await doc.reference.update({
          'status': 'cancelled',
          'cancellation_reason': 'Payment timeout (Client-side)',
          'cancelled_by_uid': 'system',
          'cancelled_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        count++;
      }
      return count;
    } catch (e) {
      // Fallback: handle missing index by filtering client-side
      try {
        final qs = await _firestore
            .collection('queues')
            .where('customer_id', isEqualTo: customerId)
            .get();
        int count = 0;
        for (final doc in qs.docs) {
          final d = doc.data();
          final deadline = d['payment_deadline'] as Timestamp?;
          final hasProof = (d['payment_proof_base64'] != null &&
                  d['payment_proof_base64'].toString().isNotEmpty) ||
              (d['payment'] != null &&
                  (d['payment']['proofUrl'] != null ||
                      d['payment']['payment_proof_base64'] != null));

          if (d['status'] == 'waiting' &&
              deadline != null &&
              deadline.compareTo(nowTs) < 0 &&
              !hasProof) {
            await doc.reference.update({
              'status': 'cancelled',
              'cancellation_reason': 'Payment timeout (Client-side Fallback)',
              'cancelled_by_uid': 'system',
              'cancelled_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            });
            count++;
          }
        }
        return count;
      } catch (_) {
        return 0;
      }
    }
  }

  /// Cancel awaiting_payment queues for a customer whose payment_due_at has passed.
  /// Re-enabled for Spark (Free) Plan compatibility.
  @override
  Future<int> cancelExpiredAwaitingPaymentQueuesForCustomer(
    String customerId,
  ) async {
    final nowTs = Timestamp.fromDate(DateTime.now());
    try {
      final qs = await _firestore
          .collection('queues')
          .where('customer_id', isEqualTo: customerId)
          .where('status', isEqualTo: 'awaiting_payment')
          .where('payment_deadline', isLessThan: nowTs)
          .get();

      int count = 0;
      for (final doc in qs.docs) {
        final data = doc.data();
        final hasProof = (data['payment_proof_base64'] != null &&
                data['payment_proof_base64'].toString().isNotEmpty) ||
            (data['payment'] != null &&
                (data['payment']['proofUrl'] != null ||
                    data['payment']['payment_proof_base64'] != null));

        if (hasProof) continue;

        await doc.reference.update({
          'status': 'cancelled',
          'cancellation_reason': 'Payment timeout (Client-side)',
          'cancelled_by_uid': 'system',
          'cancelled_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
        count++;
      }
      return count;
    } catch (e) {
      // Fallback: handle missing index
      try {
        final qs = await _firestore
            .collection('queues')
            .where('customer_id', isEqualTo: customerId)
            .get();
        int count = 0;
        for (final doc in qs.docs) {
          final d = doc.data();
          final deadline = d['payment_deadline'] as Timestamp?;
          final hasProof = (d['payment_proof_base64'] != null &&
                  d['payment_proof_base64'].toString().isNotEmpty) ||
              (d['payment'] != null &&
                  (d['payment']['proofUrl'] != null ||
                      d['payment']['payment_proof_base64'] != null));

          if (d['status'] == 'awaiting_payment' &&
              deadline != null &&
              deadline.compareTo(nowTs) < 0 &&
              !hasProof) {
            await doc.reference.update({
              'status': 'cancelled',
              'cancellation_reason': 'Payment timeout (Client-side Fallback)',
              'cancelled_by_uid': 'system',
              'cancelled_at': FieldValue.serverTimestamp(),
              'updated_at': FieldValue.serverTimestamp(),
            });
            count++;
          }
        }
        return count;
      } catch (_) {
        return 0;
      }
    }
  }

  // =============== ADMIN SCREEN HELPERS ===============

  /// Stream all queues with optional status filter (for admin dashboard)
  Stream<List<Queue>> streamAllQueues({
    String? barbershopId,
    List<String>? statusFilter,
  }) {
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

  /// Admin confirms booking request (waiting → awaiting_payment)
  /// This performs the first admin step: approve the request and give the
  /// customer a limited window (e.g. 10 minutes) to upload payment proof.
  Future<void> adminConfirmRequest(String queueId, {String? adminUid}) async {
    try {
      final uid = adminUid ?? _auth.currentUser?.uid ?? 'admin';
      // Determine per-shop payment window and set awaiting_payment with deadline
      final ref = await _resolveQueueDocRef(queueId);
      final qdoc = await ref.get();
      final qdata = qdoc.data();
      final bsId = qdata?['barbershop_id'] as String?;
      final window = await getPaymentWindowForBarbershop(bsId);
      final due = DateTime.now().add(Duration(minutes: window));
      await ref.update({
        'status': 'awaiting_payment',
        'request_status': 'approved',
        'verified_by': uid,
        'payment_deadline': Timestamp.fromDate(due),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // create a notification for the customer to pay
      final doc = await ref.get();
      final afterData = doc.data();
      final customerId = afterData?['customer_id'] as String?;
      if (customerId != null) {
        await _firestore.collection('notifications').add({
          'user_id': customerId,
          'title': 'Booking Disetujui - Silakan Bayar',
          'body':
              'Booking Anda telah disetujui. Silakan lakukan pembayaran dalam $window menit untuk mengamankan slot.',
          'queue_id': queueId,
          'created_at': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      debugPrint('Error confirming request $queueId: $e');
      rethrow;
    }
  }

  /// Admin reject booking request (waiting → cancelled)
  Future<void> adminRejectRequest(
    String queueId, {
    String? rejectionReason,
    String? adminUid,
  }) async {
    try {
      final uid = adminUid ?? _auth.currentUser?.uid ?? 'admin';
      final ref = await _resolveQueueDocRef(queueId);
      await ref.update({
        'status': 'cancelled',
        'request_status': 'rejected',
        'rejection_reason': rejectionReason ?? 'Rejected by admin',
        'verified_by': uid,
        'updated_at': FieldValue.serverTimestamp(),
      });
      // notify customer
      final doc = await ref.get();
      final customerId = doc.data()?['customer_id'] as String?;
      if (customerId != null) {
        await _createNotificationForUser(
          customerId,
          'Request Ditolak',
          'Permintaan booking Anda ditolak oleh admin.',
          queueId,
        );
      }
    } catch (e) {
      debugPrint('Error rejecting request $queueId: $e');
      rethrow;
    }
  }
}
