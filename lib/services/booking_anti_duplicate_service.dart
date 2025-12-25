// Layanan untuk mencegah duplikasi booking dan upload bukti pembayaran
//
// Menggunakan Firestore transactions untuk atomicity dan consistency.
// Pola:
// 1. Setiap upload payment proof hanya boleh terjadi sekali (lock mechanism)
// 2. Hanya satu dokumen per booking ID
// 3. Transisi status ketat: awaiting_payment -> (upload proof) -> pending -> accepted -> booked
// 4. proofLocked = true mencegah UI double-submit

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class BookingAntiDuplicateService {
  final FirebaseFirestore _firestore;

  BookingAntiDuplicateService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  static const String primaryCollection = 'queues';

  Future<DocumentReference<Map<String, dynamic>>> _resolveBookingDocRef(
    String id,
  ) async {
    final primaryRef = _firestore.collection(primaryCollection).doc(id);
    final pSnap = await primaryRef.get();
    if (pSnap.data() != null) return primaryRef;
    final legacyRef = _firestore.collection('bookings').doc(id);
    final lSnap = await legacyRef.get();
    if (lSnap.data() != null) return legacyRef;
    return primaryRef; // fallback primary ref (likely non-existent)
  }

  /// Submit bukti pembayaran dengan transaction (atomik, prevent double-upload)
  ///
  /// Kondisi yang dicek:
  /// - Booking harus exist
  /// - Status harus 'confirmed'
  /// - payment.proofUrl harus null (belum ada)
  /// - payment.proofLocked harus false/null
  ///
  /// Jika semua kondisi terpenuhi:
  /// - Set proofUrl, proofUploadedAt (server ts), proofUploadedBy (uid)
  /// - Increment proofUploadAttemptCount
  /// - Set proofLocked = true
  /// - Set verificationStatus = 'pending'
  /// - Update updatedAt
  ///
  /// Throws exception jika:
  /// - Booking tidak ditemukan
  /// - Status tidak 'confirmed'
  /// - Proof sudah ada atau locked
  /// - Race condition (2 tx concurrent → hanya 1 sukses)
  Future<void> submitPaymentProof({
    required String bookingId,
    required String proofUrl, // URL atau base64
    required String userId,
  }) async {
    if (bookingId.isEmpty || proofUrl.isEmpty || userId.isEmpty) {
      throw Exception('Parameter tidak boleh kosong');
    }

    final bookingRef = await _resolveBookingDocRef(bookingId);

    try {
      await _firestore.runTransaction((tx) async {
        // Step 1: Read current state
        final snapshot = await tx.get(bookingRef);
        if (!snapshot.exists) {
          throw Exception('Booking tidak ditemukan: $bookingId');
        }

        final data = snapshot.data() ?? {};
        final status = data['status'] as String?;
        final payment = Map<String, dynamic>.from(data['payment'] ?? {});

        final currentProofUrl = payment['proofUrl'] as String?;
        final proofLocked = payment['proofLocked'] as bool? ?? false;

        // Step 2: Validasi kondisi
        // Dalam flow payment-first, customer mengirimkan bukti saat status == 'awaiting_payment'
        if (status != 'awaiting_payment') {
          throw Exception(
            'Booking tidak dalam status awaiting_payment. Status saat ini: $status',
          );
        }

        if (currentProofUrl != null && currentProofUrl.isNotEmpty) {
          throw Exception(
            'Bukti pembayaran sudah dikirim — tidak dapat upload ulang. '
            'Hubungi admin jika ada kesalahan.',
          );
        }

        if (proofLocked) {
          throw Exception('Upload sudah terkunci (proofLocked=true)');
        }

        // Step 3: Update atomically
        tx.update(bookingRef, {
          'payment.proofUrl': proofUrl,
          'payment.proofUploadedAt': FieldValue.serverTimestamp(),
          'payment.proofUploadedBy': userId,
          'payment.proofUploadAttemptCount': FieldValue.increment(1),
          'payment.proofLocked': true,
          'payment.verificationStatus': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint(
          '[BookingAntiDupService] Bukti pembayaran submitted: '
          'bookingId=$bookingId, userId=$userId, proofUrl=$proofUrl',
        );
      });
    } catch (e, st) {
      debugPrint('[BookingAntiDupService] Error submitPaymentProof: $e\n$st');
      rethrow;
    }
  }

  /// Admin verifikasi pembayaran: accepted
  ///
  /// Update: verificationStatus='accepted', status='booked'
  /// Persyaratan: verificationStatus harus 'pending'
  Future<void> acceptPaymentVerification({
    required String bookingId,
    required String adminUid,
    String? adminNotes,
  }) async {
    final bookingRef = await _resolveBookingDocRef(bookingId);

    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(bookingRef);
        if (!snapshot.exists) {
          throw Exception('Booking tidak ditemukan: $bookingId');
        }

        final data = snapshot.data() ?? {};
        final payment = Map<String, dynamic>.from(data['payment'] ?? {});
        final verificationStatus =
            payment['verificationStatus'] as String? ??
            data['payment_verification_status'] as String?;

        if (verificationStatus != 'pending') {
          throw Exception(
            'Hanya booking dengan verificationStatus=pending yang dapat diverifikasi. '
            'Status saat ini: $verificationStatus',
          );
        }

        tx.update(bookingRef, {
          'payment.verificationStatus': 'accepted',
          'payment.verificationAcceptedAt': FieldValue.serverTimestamp(),
          'payment.verificationAcceptedBy': adminUid,
          if (adminNotes != null && adminNotes.isNotEmpty)
            'payment.verificationNotes': adminNotes,
          // After verification the booking becomes booked and enters the live queue
          'status': 'booked',
          'payment_verification_status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint(
          '[BookingAntiDupService] Pembayaran accepted: '
          'bookingId=$bookingId, adminUid=$adminUid',
        );
      });
    } catch (e, st) {
      debugPrint(
        '[BookingAntiDupService] Error acceptPaymentVerification: $e\n$st',
      );
      rethrow;
    }
  }

  /// Admin reject pembayaran
  ///
  /// Update: verificationStatus='rejected', status='awaiting_payment' (allow re-upload)
  /// atau status='cancelled' tergantung policy
  Future<void> rejectPaymentVerification({
    required String bookingId,
    required String adminUid,
    required String rejectionReason,
    bool allowReupload = true,
  }) async {
    final bookingRef = await _resolveBookingDocRef(bookingId);

    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(bookingRef);
        if (!snapshot.exists) {
          throw Exception('Booking tidak ditemukan: $bookingId');
        }

        final data = snapshot.data() ?? {};
        final payment = Map<String, dynamic>.from(data['payment'] ?? {});
        final verificationStatus =
            payment['verificationStatus'] as String? ??
            data['payment_verification_status'] as String?;

        if (verificationStatus != 'pending') {
          throw Exception(
            'Hanya booking dengan verificationStatus=pending yang dapat di-reject.',
          );
        }

        final Map<String, dynamic> updateData = {
          'payment.verificationStatus': 'rejected',
          'payment.verificationRejectedAt': FieldValue.serverTimestamp(),
          'payment.verificationRejectedBy': adminUid,
          'payment.rejectionReason': rejectionReason,
          'payment.proofLocked': !allowReupload, // Unlock jika reupload allowed
          'status': allowReupload ? 'awaiting_payment' : 'cancelled',
          'payment_verification_status': 'rejected',
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (!allowReupload) {
          updateData['payment.proofUrl'] = FieldValue.delete();
          updateData['payment_proof_base64'] = FieldValue.delete();
        }

        tx.update(bookingRef, updateData);

        debugPrint(
          '[BookingAntiDupService] Pembayaran rejected: '
          'bookingId=$bookingId, reason=$rejectionReason, allowReupload=$allowReupload',
        );
      });
    } catch (e, st) {
      debugPrint(
        '[BookingAntiDupService] Error rejectPaymentVerification: $e\n$st',
      );
      rethrow;
    }
  }

  /// Get booking dengan ownership validation
  Future<DocumentSnapshot?> getBookingForUser(
    String bookingId,
    String userId,
  ) async {
    try {
      final ref = await _resolveBookingDocRef(bookingId);
      final snapshot = await ref.get();

      if (!snapshot.exists) return null;

      final data = snapshot.data() ?? {};
      if ((data['userId'] as String?) != userId &&
          (data['customer_id'] as String?) != userId) {
        throw Exception('Booking bukan milik user ini');
      }

      return snapshot;
    } catch (e) {
      debugPrint('[BookingAntiDupService] Error getBookingForUser: $e');
      return null;
    }
  }

  /// Stream bookings untuk customer dengan filter eksklusif
  ///
  /// Gunakan untuk setiap tab agar tidak ada overlap/duplikasi
  /// filterType supported:
  /// - 'awaiting_payment' : status == 'awaiting_payment' & no verificationStatus
  /// - 'payment_pending'  : payment.verificationStatus == 'pending'
  /// - 'booked'           : status in ['booked', 'ongoing']
  /// - 'cancelled'        : status == 'cancelled'
  Stream<List<DocumentSnapshot>> streamCustomerBookingsFiltered({
    required String userId,
    required String
    filterType, // 'awaiting_payment', 'payment_pending', 'booked', 'cancelled'
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('queues')
        .where('customer_id', isEqualTo: userId);

    switch (filterType) {
      case 'awaiting_payment':
        // Menunggu pembayaran: awaiting_payment & belum upload
        query = query
            .where('status', isEqualTo: 'awaiting_payment')
            .where('payment.verificationStatus', isNull: true);
        break;

      case 'payment_pending':
        // Pembayaran dikirim: verificationStatus = pending
        query = query.where('payment.verificationStatus', isEqualTo: 'pending');
        break;

      case 'booked':
        // Terbayar / sudah booked: status in booked or ongoing
        query = query.where('status', whereIn: ['booked', 'ongoing']);
        break;

      case 'cancelled':
        query = query.where('status', isEqualTo: 'cancelled');
        break;

      default:
        throw Exception('Filter type tidak dikenali: $filterType');
    }

    query = query.orderBy('created_at', descending: true);

    return query.snapshots().map((snapshot) {
      final List<DocumentSnapshot> docs = snapshot.docs;

      // Safety: deduplicate by bookingId (meskipun seharusnya tidak ada duplikasi)
      final Map<String, DocumentSnapshot> unique = {};
      for (var doc in docs) {
        unique[doc.id] = doc;
      }

      return unique.values.toList();
    });
  }

  /// Stream admin verifikasi pembayaran (hanya pending)
  ///
  /// Admin melihat hanya booking yang payment.verificationStatus == 'pending'
  /// Deduplicate by bookingId untuk extra safety
  Stream<List<DocumentSnapshot>> streamPaymentVerificationQueue() {
    return _firestore
        .collection('queues')
        .where('payment.verificationStatus', isEqualTo: 'pending')
        .orderBy('payment.proofUploadedAt', descending: false) // oldest first
        .snapshots()
        .map((snapshot) {
          final List<DocumentSnapshot> docs = snapshot.docs;

          // Deduplicate by bookingId
          final Map<String, DocumentSnapshot> unique = {};
          for (var doc in docs) {
            if (!unique.containsKey(doc.id)) {
              unique[doc.id] = doc;
            }
          }

          debugPrint(
            '[BookingAntiDupService] Verifikasi queue: ${unique.length} pending payments',
          );
          return unique.values.toList();
        });
  }

  /// Identify duplikasi: cari booking dengan kombinasi userId + scheduledAt yang sama
  ///
  /// Return: `List<List<String>>` dimana setiap inner list adalah group ID yang duplikasi
  /// Gunakan untuk admin cleanup manual
  Future<List<List<String>>> identifyDuplicateBookings() async {
    try {
      final allQueues = await _firestore.collection('queues').get();
      final allBookingsLegacy = await _firestore.collection('bookings').get();

      final allDocs = [...allQueues.docs, ...allBookingsLegacy.docs];

      final Map<String, List<String>> groupByKey = {};

      for (var doc in allDocs) {
        final data = doc.data();
        final userId =
            data['userId'] as String? ?? data['customer_id'] as String?;
        final scheduledAt =
            data['scheduledAt'] as Timestamp? ??
            data['booking_time'] as Timestamp?;
        String? serviceId;
        if (data['serviceId'] is String) {
          serviceId = data['serviceId'] as String?;
        } else if (data['service_ids'] is List) {
          final list = (data['service_ids'] as List);
          if (list.isNotEmpty) serviceId = list.first as String?;
        }

        if (userId == null || scheduledAt == null) continue;

        // Unique key untuk grouping
        final key = '$userId|${scheduledAt.toDate()}|$serviceId';
        groupByKey.putIfAbsent(key, () => []).add(doc.id);
      }

      // Filter hanya group dengan size > 1
      final duplicates = groupByKey.values
          .where((list) => list.length > 1)
          .toList();

      debugPrint(
        '[BookingAntiDupService] Found ${duplicates.length} duplicate groups',
      );
      return duplicates;
    } catch (e) {
      debugPrint('[BookingAntiDupService] Error identifyDuplicateBookings: $e');
      return [];
    }
  }

  /// Mark booking sebagai duplicate_removed (soft delete)
  ///
  /// Gunakan untuk migrasi: pilih 1 booking authoritative, mark yang lain
  Future<void> markAsDuplicateRemoved({
    required String bookingId,
    required String reason,
  }) async {
    try {
      final ref = _firestore.collection('queues').doc(bookingId);
      final snap = await ref.get();
      if (snap.exists) {
        await ref.update({
          'status': 'duplicate_removed',
          'duplicateRemovedAt': FieldValue.serverTimestamp(),
          'duplicateRemovedReason': reason,
        });
      } else {
        final legacyRef = _firestore.collection('bookings').doc(bookingId);
        await legacyRef.update({
          'status': 'duplicate_removed',
          'duplicateRemovedAt': FieldValue.serverTimestamp(),
          'duplicateRemovedReason': reason,
        });
      }

      debugPrint(
        '[BookingAntiDupService] Marked as duplicate: '
        '$bookingId, reason=$reason',
      );
    } catch (e) {
      debugPrint('[BookingAntiDupService] Error markAsDuplicateRemoved: $e');
      rethrow;
    }
  }
}
