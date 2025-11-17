  // lib/services/barbershop_service.dart
  import 'dart:async';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:flutter/foundation.dart';

  // Import model
  import 'package:geges_smartbarber/models/barbershop.dart';
  import 'package:geges_smartbarber/models/barberman.dart';
  import 'package:geges_smartbarber/models/service.dart';
  import 'package:geges_smartbarber/models/promo_banner.dart';
  import 'package:geges_smartbarber/models/queue.dart';
  import 'package:geges_smartbarber/models/user_data.dart';

  class BarbershopService {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    // -----------------------
    // BARBERSHOP FUNCTIONS
    // -----------------------
    Future<List<Barbershop>> getAllBarbershops() async {
      try {
        final snapshot = await _firestore.collection('barbershops').get();
        return snapshot.docs.map((doc) => Barbershop.fromFirestore(doc)).toList();
      } catch (e) {
        debugPrint('Error getAllBarbershops: $e');
        return [];
      }
    }

    Future<Barbershop?> getBarbershopById(String barbershopId) async {
      if (barbershopId.isEmpty) return null;
      try {
        final doc = await _firestore.collection('barbershops').doc(barbershopId).get();
        if (!doc.exists) return null;
        return Barbershop.fromFirestore(doc);
      } catch (e) {
        debugPrint('Error getBarbershopById: $e');
        return null;
      }
    }

    Future<void> updateShopStatus(String id, bool isOpen) async {
      try {
        await _firestore.collection('barbershops').doc(id).update({
          'isOpen': isOpen,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updateShopStatus: $e');
        rethrow;
      }
    }

    // -----------------------
    // BARBERMAN FUNCTIONS
    // -----------------------
    Future<List<Barberman>> getBarbermenByShop(String barbershopId) async {
      try {
        final snapshot = await _firestore
            .collection('barbermen')
            .where('barbershop_id', isEqualTo: barbershopId)
            .get();

        return snapshot.docs
            .map((doc) => Barberman.fromFirestore(doc))
            .toList();
      } catch (e) {
        debugPrint('Error getBarbermenByShop: $e');
        return [];
      }
    }

    Future<Barberman?> getBarbermanById(String barbermanId) async {
      if (barbermanId.isEmpty) return null;
      try {
        final doc = await _firestore.collection('barbermen').doc(barbermanId).get();
        if (!doc.exists) return null;
        return Barberman.fromFirestore(doc);
      } catch (e) {
        debugPrint('Error getBarbermanById: $e');
        return null;
      }
    }

    // -----------------------
    // SERVICE FUNCTIONS
    // -----------------------
    Future<List<Service>> getAllServices() async {
      try {
        final snapshot = await _firestore.collection('services').get();
        return snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList();
      } catch (e) {
        debugPrint('Error getAllServices: $e');
        return [];
      }
    }

    // -----------------------
    // PROMO / BANNER FUNCTIONS
    // -----------------------
    Stream<List<PromoBanner>> getPromoBanners() {
      return _firestore
          .collection('promo_banners')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => PromoBanner.fromFirestore(doc)).toList());
    }

    // -----------------------
    // QUEUE / BOOKING FUNCTIONS
    // -----------------------

    /// Stream antrean aktif (booked | ongoing) menggunakan converter ke model Queue
    Stream<List<Queue>> streamActiveQueuesByShop(String barbershopId) {
      return _firestore
          .collection('queues')
          .where('barbershop_id', isEqualTo: barbershopId)
          .where('status', whereIn: ['booked', 'ongoing'])
          .orderBy('booking_time', descending: false)
          .withConverter<Queue>(
            fromFirestore: (snap, _) => Queue.fromFirestore(snap),
            toFirestore: (q, _) => q.toJson(),
          )
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());
    }

    /// Stream antrean waiting (menunggu konfirmasi) menggunakan converter
    Stream<List<Queue>> streamWaitingQueues(String barbershopId) {
      return _firestore
          .collection('queues')
          .where('barbershop_id', isEqualTo: barbershopId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('booking_time', descending: false)
          .withConverter<Queue>(
            fromFirestore: (snap, _) => Queue.fromFirestore(snap),
            toFirestore: (q, _) => q.toJson(),
          )
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());
    }

    /// General helper: update status queue (dipakai oleh admin)
    Future<void> updateQueueStatus(String queueId, String newStatus,
        {Map<String, dynamic>? extra}) async {
      try {
        final payload = <String, dynamic>{
          'status': newStatus,
          'updated_at': FieldValue.serverTimestamp(),
        };
        if (extra != null) payload.addAll(extra);
        await _firestore.collection('queues').doc(queueId).update(payload);
      } catch (e) {
        debugPrint('Error updateQueueStatus: $e');
        rethrow;
      }
    }

    Future<void> cancelQueue(String queueId,
        {String reason = 'Cancelled by system/admin'}) async {
      try {
        await _firestore.collection('queues').doc(queueId).update({
          'status': 'cancelled',
          'cancellation_reason': reason,
          'cancelled_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error cancelQueue: $e');
        rethrow;
      }
    }

    /// Menandai layanan dimulai (booked -> ongoing)
    Future<void> startService(String queueId) async {
      try {
        await _firestore.collection('queues').doc(queueId).update({
          'status': 'ongoing',
          'start_time': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error startService: $e');
        rethrow;
      }
    }

    /// Menandai layanan selesai (ongoing -> served)
    Future<void> finishService(String queueId) async {
      try {
        final doc = await _firestore.collection('queues').doc(queueId).get();
        if (!doc.exists) throw Exception('Queue not found');

        final data = doc.data()!;
        final start = data['start_time'] as Timestamp?;
        final finishTs = Timestamp.now();

        int actualDuration = 0;
        if (start != null) {
          final now = Timestamp.now();
          actualDuration = ((now.seconds - start.seconds) ~/ 60).clamp(1, 10000).toInt();
        }

        await _firestore.collection('queues').doc(queueId).update({
          'status': 'served',
          'finish_time': finishTs,
          'actual_duration': actualDuration,
          'updated_at': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error finishService: $e');
        rethrow;
      }
    }

    // -----------------------
    // USER / QUEUE HELPERS
    // -----------------------
    Stream<UserData?> getUserDataStream(String userId) {
      return _firestore.collection('users').doc(userId).snapshots().map((doc) {
        if (!doc.exists) return null;
        return UserData.fromFirestore(doc);
      });
    }

    /// Create queue — default status = 'waiting' (admin harus konfirmasi -> 'booked')
    Future<DocumentReference<Map<String, dynamic>>> createQueue(
        Map<String, dynamic> queueData) async {
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
        'barbershop_id': queueData['barbershop_id'] ?? queueData['barbershopId'],
        'customer_id': queueData['customer_id'] ?? queueData['customerId'],
        'barberman_id': queueData['barberman_id'] ?? queueData['barbermanId'],
        'service_ids': queueData['service_ids'] ?? queueData['serviceIds'] ?? [],
        'total_price': queueData['total_price'] ?? queueData['totalPrice'],
        'estimated_duration':
            queueData['estimated_duration'] ?? queueData['estimatedDuration'],
        'booking_time': bookingTs,
        'status': queueData['status'] ?? 'waiting',
        'created_at': FieldValue.serverTimestamp(),
        'payment_proof_base64': queueData['payment_proof_base64'] ?? queueData['payment_proof'],
        'payment_method': queueData['payment_method'],
        'payment_amount': queueData['payment_amount'],
        'order_id': queueData['order_id'],
        'notes': queueData['notes'],
      };

      dataToSave.removeWhere((_, v) => v == null);

      try {
        final ref = await _firestore.collection('queues').add(dataToSave);
        return ref;
      } catch (e) {
        debugPrint('Error createQueue: $e');
        rethrow;
      }
    }

    Future<QuerySnapshot<Map<String, dynamic>>> getQueuesByOrderId(String orderId) async {
      try {
        return await _firestore
            .collection('queues')
            .where('order_id', isEqualTo: orderId)
            .get();
      } catch (e) {
        debugPrint('Error getQueuesByOrderId: $e');
        rethrow;
      }
    }
  }
