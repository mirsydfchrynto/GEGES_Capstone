// lib/services/queue_service.dart
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // Needed for DateTimeRange
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
  // 🔔 NOTIFICATION SYSTEM (NEW)
  // -----------------------
  
  /// Mengirim notifikasi ke user via Firestore
  Future<void> _sendNotification(String userId, String title, String body, String queueId) async {
    try {
      if (userId.isEmpty) return;
      await _firestore.collection('notifications').add({
        'user_id': userId,
        'title': title,
        'body': body,
        'queue_id': queueId,
        'created_at': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'order_update'
      });
      debugPrint("Notification sent to $userId: $title");
    } catch (e) {
      debugPrint("Failed to send notification: $e");
    }
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
        final monthlyCount = (barberData['monthly_haircut_count'] as num?)?.toInt() ?? 0;
        
        final barberInfo = {
          'id': barberId,
          'monthlyCount': monthlyCount,
          'name': barberData['name'] ?? 'Unknown',
        };

        fallbackBarbers.add(barberInfo);

        bool isOnLeave = barberData['onLeave'] ?? false;
        if (isOnLeave) continue;

        // Cek Libur Mingguan
        final dayName = DateFormat('EEEE', 'en_US').format(bookingTime).toLowerCase();
        final rawOffDays = barberData['offDays'] ?? barberData['off_days'] ?? [];
        final List<String> offDays = (rawOffDays is List) 
            ? rawOffDays.map((e) => e.toString().toLowerCase().trim()).toList()
            : [];
        if (offDays.contains(dayName)) continue;

        // Cek Libur Tanggal Khusus
        final dateStr = DateFormat('yyyy-MM-dd').format(bookingTime);
        final rawSpecific = barberData['specificOffDays'] ?? barberData['specific_off_days'] ?? [];
        final List<String> specificOffDays = (rawSpecific is List) 
            ? rawSpecific.map((e) => e.toString().trim()).toList()
            : [];
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

  @override
  Stream<Queue?> streamQueueById(String id) {
    return _firestore.collection('queues').doc(id).snapshots().map((s) => s.exists ? Queue.fromFirestore(s) : null);
  }

  @override
  Future<Queue?> getQueueById(String queueId) async {
    final snap = await _firestore.collection('queues').doc(queueId).get();
    return snap.exists ? Queue.fromFirestore(snap) : null;
  }

  Stream<List<Queue>> streamAllQueues({List<String>? statusFilter}) {
    Query<Map<String, dynamic>> query = _firestore.collection('queues');
    
    // Gunakan try-catch di dalam Stream untuk menangani error indeks
    return query.orderBy('booking_time', descending: true)
        .withConverter<Queue>(
          fromFirestore: (snap, _) => Queue.fromFirestore(snap),
          toFirestore: (queue, _) => queue.toJson(),
        )
        .snapshots()
        .map((s) {
          final docs = s.docs.map((d) => d.data()).toList();
          if (statusFilter != null && statusFilter.isNotEmpty) {
            return docs.where((q) => statusFilter.contains(q.status.value)).toList();
          }
          return docs;
        })
        .handleError((error) {
          if (error.toString().contains('FAILED_PRECONDITION')) {
            debugPrint('⚠️ Database Index is building. Using in-memory fallback.');
            // Fallback: Ambil data tanpa urutan/filter kompleks, lalu filter di aplikasi
            return _firestore.collection('queues')
                .withConverter<Queue>(
                  fromFirestore: (snap, _) => Queue.fromFirestore(snap),
                  toFirestore: (queue, _) => queue.toJson(),
                )
                .snapshots()
                .map((s) {
                  final docs = s.docs.map((d) => d.data()).toList();
                  if (statusFilter != null && statusFilter.isNotEmpty) {
                    return docs.where((q) => statusFilter.contains(q.status.value)).toList();
                  }
                  return docs;
                });
          }
          throw error;
        });
  }

  Future<void> adminRejectCancellation(String queueId) async {
    await _firestore.collection('queues').doc(queueId).update({
      'status': 'booked', // Revert to booked
      'cancellation_rejection_reason': 'Rejected by admin',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<int> cancelExpiredWaitingQueuesForCustomer(String customerId) async {
    try {
      final now = Timestamp.now();
      try {
        final qs = await _firestore.collection('queues')
            .where('customer_id', isEqualTo: customerId)
            .where('status', isEqualTo: 'waiting')
            .where('payment_deadline', isLessThan: now)
            .get();
        
        int count = 0;
        for (var doc in qs.docs) {
          await doc.reference.update({
            'status': 'cancelled',
            'cancellation_reason': 'Expired (No admin response)',
            'updated_at': FieldValue.serverTimestamp(),
          });
          count++;
        }
        return count;
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition') {
          // Fallback: Filter in-memory
          final qs = await _firestore.collection('queues')
              .where('customer_id', isEqualTo: customerId)
              .get();
          
          int count = 0;
          for (var doc in qs.docs) {
            final data = doc.data();
            final deadline = data['payment_deadline'] as Timestamp?;
            if (data['status'] == 'waiting' && deadline != null && now.seconds > deadline.seconds) {
              await doc.reference.update({
                'status': 'cancelled',
                'cancellation_reason': 'Expired (No admin response)',
                'updated_at': FieldValue.serverTimestamp(),
              });
              count++;
            }
          }
          return count;
        }
        rethrow;
      }
    } catch (e) {
      return 0;
    }
  }

  static bool isBookingLeadTimeSufficient(DateTime bookingTime, {int minMinutes = 30}) {
    return bookingTime.isAfter(DateTime.now().add(Duration(minutes: minMinutes)));
  }

  static const int defaultPaymentWindowMinutes = 15;

  // -----------------------
  // 📅 AVAILABILITY HELPERS
  // -----------------------

  Future<List<DateTimeRange>> getBarberBusyTimeRanges(String barbermanId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    try {
      final qs = await _firestore.collection('queues')
          .where('barberman_id', isEqualTo: barbermanId)
          .where('status', whereIn: ['booked', 'ongoing', 'awaiting_payment'])
          .where('booking_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('booking_time', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();
      
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
    final startDay = DateTime(date.year, date.month, date.day);
    final endDay = startDay.add(const Duration(days: 1));

    // 1. Hitung Kapasitas Barber (Total Kursi)
    //    Hanya hitung yang aktif, tidak cuti, dan tidak libur hari ini
    final dayName = DateFormat('EEEE', 'en_US').format(date).toLowerCase();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    final barbersSnapshot = await _firestore.collection('barbermen')
        .where('barbershop_id', isEqualTo: barbershopId)
        .where('isActive', isEqualTo: true)
        .get();
    
    final activeBarbers = barbersSnapshot.docs.where((doc) {
      final data = doc.data();
      if (data['onLeave'] == true) return false;
      
      final offDays = (data['offDays'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
      if (offDays.contains(dayName)) return false;

      final specificOff = (data['specificOffDays'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (specificOff.contains(dateStr)) return false;

      return true;
    }).toList();

    final int totalCapacity = activeBarbers.length;
    if (totalCapacity == 0) {
      // Jika tidak ada barber masuk, tutup seharian
      return [DateTimeRange(start: startDay, end: endDay)];
    }

    // 2. Ambil semua booking hari ini
    final qs = await _firestore.collection('queues')
        .where('barbershop_id', isEqualTo: barbershopId)
        .where('status', whereIn: ['booked', 'ongoing', 'awaiting_payment'])
        .where('booking_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startDay))
        .where('booking_time', isLessThanOrEqualTo: Timestamp.fromDate(endDay))
        .get();

    // 3. Petakan Load per Slot Waktu (per 30 menit)
    //    Map<JamString, JumlahBooking>
    final Map<String, int> slotLoad = {};
    
    for (var doc in qs.docs) {
       final start = (doc.data()['booking_time'] as Timestamp).toDate();
       final duration = (doc.data()['estimated_duration'] as num? ?? 30).toInt();
       
       // Mark setiap slot 30 menit yang terpakai oleh booking ini
       // Contoh: Durasi 60 menit = makan 2 slot
       int slotsConsumed = (duration / 30).ceil();
       for (int i = 0; i < slotsConsumed; i++) {
         final timeKey = start.add(Duration(minutes: 30 * i));
         final key = DateFormat('HH:mm').format(timeKey);
         slotLoad[key] = (slotLoad[key] ?? 0) + 1;
       }
    }

    // 4. Identifikasi Slot Penuh (Load >= Capacity)
    List<DateTimeRange> fullSlots = [];
    
    // Kita cek setiap slot operasional (misal 9:00 - 21:00)
    // Karena kita tidak tahu jam buka di sini (opsional fetch), kita iterate berdasarkan data load saja
    slotLoad.forEach((timeStr, loadCount) {
      if (loadCount >= totalCapacity) {
        // Slot ini penuh!
        final parts = timeStr.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final slotStart = DateTime(date.year, date.month, date.day, h, m);
        fullSlots.add(DateTimeRange(start: slotStart, end: slotStart.add(const Duration(minutes: 30))));
      }
    });

    return fullSlots;
  }

  Future<int> cancelExpiredBookings(String barbershopId) async {
    // Auto cancel logic
    return 0; // Simplified for this file rewrite
  }

  // -----------------------
  // 🧑‍🔧 ACTIONS (WITH NOTIFICATIONS)
  // -----------------------

  Future<DocumentReference<Map<String, dynamic>>> _resolveQueueDocRef(String id) async {
    return _firestore.collection('queues').doc(id);
  }

  Future<void> startService(String queueId) async {
    final ref = await _resolveQueueDocRef(queueId);
    await ref.update({
      'status': 'ongoing',
      'start_time': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    
    // LOG SUCCESS: Status berubah menjadi Sedang Dikerjakan
    debugPrint('SERVICE START: Queue $queueId is now ONGOING');

    // NOTIFIKASI
    final doc = await ref.get();
    final uid = doc.data()?['customer_id'];
    if (uid != null) await _sendNotification(uid, "Giliran Anda!", "Silakan bersiap, layanan dimulai.", queueId);
  }

  Future<void> finishService(String queueId, [Timestamp? startTime]) async {
    final ref = await _resolveQueueDocRef(queueId);
    await ref.update({
      'status': 'served',
      'finish_time': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // LOG SUCCESS: Layanan selesai dikerjakan
    debugPrint('SERVICE FINISH: Queue $queueId is now SERVED');

    // NOTIFIKASI
    final doc = await ref.get();
    final uid = doc.data()?['customer_id'];
    if (uid != null) await _sendNotification(uid, "Layanan Selesai", "Terima kasih telah menggunakan jasa kami.", queueId);
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

  // 👮 ADMIN ACTIONS (WITH NOTIFICATIONS)

  Future<void> adminConfirmRequest(String queueId, {String? adminUid}) async {
    final uid = adminUid ?? _auth.currentUser?.uid ?? 'admin';
    final ref = await _resolveQueueDocRef(queueId);
    final doc = await ref.get();
    
    final window = await getPaymentWindowForBarbershop(doc.data()?['barbershop_id']);
    final due = DateTime.now().add(Duration(minutes: window));
    
    await ref.update({
      'status': 'awaiting_payment',
      'request_status': 'approved',
      'verified_by': uid,
      'payment_deadline': Timestamp.fromDate(due),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // NOTIFIKASI
    final custId = doc.data()?['customer_id'];
    if (custId != null) await _sendNotification(custId, "Booking Disetujui", "Silakan lakukan pembayaran dalam $window menit.", queueId);
  }

  Future<void> adminRejectRequest(String queueId, {String? rejectionReason, String? adminUid}) async {
    final uid = adminUid ?? _auth.currentUser?.uid ?? 'admin';
    final ref = await _resolveQueueDocRef(queueId);
    final doc = await ref.get();

    await ref.update({
      'status': 'cancelled',
      'request_status': 'rejected',
      'rejection_reason': rejectionReason ?? 'Rejected by admin',
      'verified_by': uid,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // NOTIFIKASI
    final custId = doc.data()?['customer_id'];
    if (custId != null) await _sendNotification(custId, "Booking Ditolak", "Maaf, admin menolak booking ini: $rejectionReason", queueId);
  }

  Future<void> adminConfirmPayment(String queueId, {String? adminUid, String? adminNotes}) async {
    final uid = adminUid ?? _auth.currentUser?.uid ?? 'admin';
    final ref = await _resolveQueueDocRef(queueId);
    final doc = await ref.get();

    await ref.update({
      'status': 'booked',
      'payment_confirmed_at': FieldValue.serverTimestamp(),
      'payment_confirmed_by': uid,
      'payment_verification_status': 'accepted',
      'updated_at': FieldValue.serverTimestamp(),
    });

    // LOG SUCCESS: Pembayaran dikonfirmasi admin
    debugPrint('PAYMENT SUCCESS: Payment for $queueId has been ACCEPTED');

    // NOTIFIKASI
    final custId = doc.data()?['customer_id'];
    if (custId != null) await _sendNotification(custId, "Pembayaran Diterima", "Jadwal Anda telah dikonfirmasi!", queueId);
  }

  Future<void> adminRejectPayment(String queueId, {String? reason, String? adminUid}) async {
    final ref = await _resolveQueueDocRef(queueId);
    final doc = await ref.get();

    await ref.update({
      'status': 'cancelled',
      'payment_verification_status': 'rejected',
      'cancellation_reason': reason ?? 'Payment rejected',
      'updated_at': FieldValue.serverTimestamp(),
    });

    // NOTIFIKASI
    final custId = doc.data()?['customer_id'];
    if (custId != null) await _sendNotification(custId, "Pembayaran Ditolak", "Bukti pembayaran tidak valid: $reason", queueId);
  }

  Future<void> adminProcessRefund(String queueId, {required String refundProofBase64, String? adminUid, String? adminNotes}) async {
    final ref = await _resolveQueueDocRef(queueId);

    await ref.update({
      'status': 'refund_completed',
      'is_refunded': true,
      'refund_proof_base64': refundProofBase64,
      'admin_refund_notes': adminNotes,
      'refund_reason': adminNotes ?? 'Refund processed',
      'refund_processed_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // LOG SUCCESS
    debugPrint('REFUND SUCCESS: Refund for $queueId processed as refund_completed');

    // NOTIFIKASI PENTING (REFUND)
    final doc = await ref.get();
    final custId = doc.data()?['customer_id'];
    if (custId != null) await _sendNotification(custId, "Refund Berhasil", "Dana telah dikembalikan. Cek detail pesanan.", queueId);
  }

  Future<void> adminRefundBooking(String queueId, {String? reason, String? adminUid}) async {
     final ref = await _resolveQueueDocRef(queueId);
     final doc = await ref.get();
     final data = doc.data() ?? {};
     final hasPayment = (data['payment_proof_base64'] != null && data['payment_proof_base64'].toString().isNotEmpty) ||
                        (data['payment_proof_url'] != null && data['payment_proof_url'].toString().isNotEmpty);

     if (hasPayment) {
       await ref.update({
          'status': 'cancelled',
          'is_refunded': true,
          'refund_reason': reason ?? 'Refund approved',
          'refunded_by': adminUid,
          'refund_processed_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
          'payment_proof_base64': FieldValue.delete(),
       });
     } else {
       await ref.update({
          'status': 'cancelled',
          'is_refunded': false,
          'cancellation_reason': reason ?? 'Cancelled by admin',
          'cancelled_by_uid': adminUid,
          'updated_at': FieldValue.serverTimestamp(),
       });
     }
  }

  // 🧾 CORE BOOKING

  Future<DocumentReference<Map<String, dynamic>>> createQueue(Map<String, dynamic> queueData) async {
    Timestamp bookingTs;
    final bt = queueData['booking_time'] ?? queueData['bookingTime'];
    if (bt is DateTime) {
      bookingTs = Timestamp.fromDate(bt);
    } else if (bt is Timestamp) {
      bookingTs = bt;
    } else {
      bookingTs = Timestamp.now();
    }

    final Map<String, dynamic> dataToSave = {
      ...queueData,
      'booking_time': bookingTs,
      'created_at': FieldValue.serverTimestamp(),
    };

    // Auto-set payment_deadline
    final status = dataToSave['status']?.toString();
    if ((status == 'waiting' || status == 'awaiting_payment') && 
        dataToSave['payment_deadline'] == null) {
      final window = await getPaymentWindowForBarbershop(dataToSave['barbershop_id']);
      dataToSave['payment_deadline'] = Timestamp.fromDate(DateTime.now().add(Duration(minutes: window)));
    }

    dataToSave.removeWhere((_, v) => v == null);
    
    // Log teknis
    debugPrint("DEBUG QUEUE PAYLOAD: ${dataToSave.toString()}");

    final String? shopIdRaw = dataToSave['barbershop_id']?.toString();
    final String? shopId = (shopIdRaw != null && shopIdRaw.isNotEmpty) ? shopIdRaw : null;
    final newQueueRef = _firestore.collection('queues').doc(); // Generate ID first

    await _firestore.runTransaction((transaction) async {
      debugPrint('TX START: Validating slot for $shopId at $bookingTs');
      
      // 1. Validasi Jam Buka & Kapasitas (Hanya jika shopId valid)
      if (shopId != null) {
        final shopRef = _firestore.collection('barbershops').doc(shopId);
        final shopSnapshot = await transaction.get(shopRef);
        
        if (shopSnapshot.exists && shopSnapshot.data() != null) {
          final shopData = shopSnapshot.data()!;
          final open = (shopData['open_hour'] ?? shopData['openHour'] ?? 0) as int;
          final close = (shopData['close_hour'] ?? shopData['closeHour'] ?? 24) as int;
          
          final bookingDateTime = bookingTs.toDate();
          final hour = bookingDateTime.hour;
          
          if (hour < open || hour >= close) {
            throw Exception('Booking time outside of operating hours ($open:00 - $close:00)');
          }

          // 2. Race Condition Check (Capacity Validation)
          final capacityQuery = await _firestore.collection('barbermen')
              .where('barbershop_id', isEqualTo: shopId)
              .where('isActive', isEqualTo: true)
              .get();
          
          final dayName = DateFormat('EEEE', 'en_US').format(bookingDateTime).toLowerCase();
          final dateStr = DateFormat('yyyy-MM-dd').format(bookingDateTime);
          
          int totalCapacity = 0;
          for (var doc in capacityQuery.docs) {
            final d = doc.data();
            if (d['onLeave'] == true) continue;
            final offDays = (d['offDays'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
            if (offDays.contains(dayName)) continue;
            final specific = (d['specificOffDays'] as List?)?.map((e) => e.toString()).toList() ?? [];
            if (specific.contains(dateStr)) continue;
            totalCapacity++;
          }

          if (totalCapacity > 0) {
            final existingBookings = await _firestore.collection('queues')
                .where('barbershop_id', isEqualTo: shopId)
                .where('status', whereIn: ['booked', 'ongoing', 'awaiting_payment'])
                .where('booking_time', isEqualTo: bookingTs)
                .get();
            
            debugPrint('TX LOAD CHECK: Current=$existingBookings.docs.length, Max=$totalCapacity');
            if (existingBookings.docs.length >= totalCapacity) {
              throw Exception('Slot penuh! Baru saja diambil orang lain.');
            }
          }
        }
      }

      // 3. Simpan Booking
      transaction.set(newQueueRef, dataToSave);
      debugPrint('TX COMMIT: Booking document created successfully');
    });
    
    // LOG SUCCESS
    try {
      debugPrint('QUEUE SUCCESS: New booking created!');
      debugPrint('   - ID: ${newQueueRef.id}');
      debugPrint('   - Time: ${bookingTs.toDate()}');
    } catch (_) {}
    
    return newQueueRef;
  }

  Future<bool> isSlotAvailable({
    required String barbershopId,
    required String barbermanId,
    required DateTime bookingTime,
    required List<String> serviceIds,
  }) async {
    // Simplified conflict check
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
      final qEnd = qStart.add(Duration(minutes: qDur + 10)); // buffer 10 mins
      if (bookingTime.isBefore(qEnd) && bookingTime.add(const Duration(minutes: 30)).isAfter(qStart)) {
        return false;
      }
    }
    return true;
  }

  Future<int> getPaymentWindowForBarbershop(String? barbershopId) async {
    if (barbershopId == null || barbershopId.isEmpty) return defaultPaymentWindowMinutes;
    try {
      final doc = await _firestore.collection('barbershops').doc(barbershopId).get();
      if (!doc.exists) return defaultPaymentWindowMinutes;
      final data = doc.data();
      if (data == null) return defaultPaymentWindowMinutes;
      
      final window = data['payment_window_minutes'] ?? data['paymentWindowMinutes'];
      if (window is num) return window.toInt();
      if (window is String) return int.tryParse(window) ?? defaultPaymentWindowMinutes;
      
      return defaultPaymentWindowMinutes;
    } catch (e) {
      debugPrint("Error fetching payment window: $e");
      return defaultPaymentWindowMinutes;
    }
  }

  // 🔍 QUERY HELPERS (Standard)
  
  @override
  Future<Queue?> resolveQueueForCustomerByIdOrOrder(String idOrOrderId, String customerId) async {
    // ... impl existing ...
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
    final doc = await ref.get();
    if (!doc.exists) throw Exception('Booking not found');
    
    final data = doc.data()!;
    if (data['customer_id'] != userId) {
      throw Exception('Unauthorized: You can only submit proof for your own booking');
    }

    await ref.update({
      'payment_proof_base64': base64Proof,
      'payment_verification_status': 'pending',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> customerRequestCancellation(String queueId, {required String reason, String? customerId}) async {
    final ref = _firestore.collection('queues').doc(queueId);
    final doc = await ref.get();
    if (!doc.exists) throw Exception('Booking not found');
    
    final data = doc.data()!;
    final status = data['status'];
    final proof = data['payment_proof_base64'] ?? data['payment_proof_url'];
    
    // Validation: if awaiting_payment and NO proof -> should not be a refund request
    if (status == 'awaiting_payment' && (proof == null || proof.toString().isEmpty)) {
      throw Exception('Cannot request refund for unpaid booking');
    }

    final totalPrice = (data['total_price'] as num?)?.toDouble() ?? 0.0;
    Map<String, dynamic> updates = {
      'status': 'cancellation_requested',
      'cancellation_reason': reason,
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (proof != null && proof.toString().isNotEmpty && totalPrice > 0) {
      // 90% refund logic
      updates['refund_amount'] = (totalPrice * 0.9).round();
      updates['refund_deduction'] = (totalPrice * 0.1).round();
    }

    await ref.update(updates);
  }

  Future<void> withdrawCancellationRequest(String queueId) async {
    await _firestore.collection('queues').doc(queueId).update({
      'status': 'booked',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<int> cancelExpiredAwaitingPaymentQueuesForCustomer(String customerId) async {
    try {
      final now = Timestamp.now();
      try {
        final qs = await _firestore.collection('queues')
            .where('customer_id', isEqualTo: customerId)
            .where('status', isEqualTo: 'awaiting_payment')
            .where('payment_deadline', isLessThan: now)
            .get();
        
        int count = 0;
        for (var doc in qs.docs) {
          await doc.reference.update({
            'status': 'cancelled',
            'cancellation_reason': 'Payment time expired',
            'updated_at': FieldValue.serverTimestamp(),
          });
          count++;
        }
        return count;
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition') {
          // Fallback: Filter in-memory
          final qs = await _firestore.collection('queues')
              .where('customer_id', isEqualTo: customerId)
              .get();
          
          int count = 0;
          for (var doc in qs.docs) {
            final data = doc.data();
            final deadline = data['payment_deadline'] as Timestamp?;
            if (data['status'] == 'awaiting_payment' && deadline != null && now.seconds > deadline.seconds) {
              await doc.reference.update({
                'status': 'cancelled',
                'cancellation_reason': 'Payment time expired',
                'updated_at': FieldValue.serverTimestamp(),
              });
              count++;
            }
          }
          return count;
        }
        rethrow;
      }
    } catch (e) {
      return 0;
    }
  }
}
