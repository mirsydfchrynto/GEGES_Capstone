/// Layanan untuk mencegah duplikasi booking dan upload bukti pembayaran
///
/// Menggunakan Firestore transactions untuk atomicity dan consistency.
/// Pola:
/// 1. Setiap upload payment proof hanya boleh terjadi sekali (lock mechanism)
/// 2. Hanya satu dokumen per booking ID
/// 3. Transisi status ketat: created to confirmed to pending to accepted to paid_verified
/// 4. proofLocked = true mencegah UI double-submit

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class BookingAntiDuplicateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String bookingsCollection = 'bookings';

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

    final bookingRef = _firestore.collection(bookingsCollection).doc(bookingId);

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
        if (status != 'confirmed') {
          throw Exception(
            'Booking tidak dalam status confirmed. Status saat ini: $status',
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
  /// Update: verificationStatus='accepted', status='paid_verified'
  /// Persyaratan: verificationStatus harus 'pending'
  Future<void> acceptPaymentVerification({
    required String bookingId,
    required String adminUid,
    String? adminNotes,
  }) async {
    final bookingRef = _firestore.collection(bookingsCollection).doc(bookingId);

    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(bookingRef);
        if (!snapshot.exists) {
          throw Exception('Booking tidak ditemukan: $bookingId');
        }

        final data = snapshot.data() ?? {};
        final payment = Map<String, dynamic>.from(data['payment'] ?? {});
        final verificationStatus = payment['verificationStatus'] as String?;

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
          'status': 'paid_verified',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        debugPrint(
          '[BookingAntiDupService] Pembayaran accepted: '
          'bookingId=$bookingId, adminUid=$adminUid',
        );
      });
    } catch (e, st) {
      debugPrint('[BookingAntiDupService] Error acceptPaymentVerification: $e\n$st');
      rethrow;
    }
  }

  /// Admin reject pembayaran
  /// 
  /// Update: verificationStatus='rejected', status='confirmed' (allow re-upload)
  /// atau status='cancelled' tergantung policy
  Future<void> rejectPaymentVerification({
    required String bookingId,
    required String adminUid,
    required String rejectionReason,
    bool allowReupload = true,
  }) async {
    final bookingRef = _firestore.collection(bookingsCollection).doc(bookingId);

    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(bookingRef);
        if (!snapshot.exists) {
          throw Exception('Booking tidak ditemukan: $bookingId');
        }

        final data = snapshot.data() ?? {};
        final payment = Map<String, dynamic>.from(data['payment'] ?? {});
        final verificationStatus = payment['verificationStatus'] as String?;

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
          'status': allowReupload ? 'confirmed' : 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (!allowReupload) {
          updateData['payment.proofUrl'] = FieldValue.delete();
        }

        tx.update(bookingRef, updateData);

        debugPrint(
          '[BookingAntiDupService] Pembayaran rejected: '
          'bookingId=$bookingId, reason=$rejectionReason, allowReupload=$allowReupload',
        );
      });
    } catch (e, st) {
      debugPrint('[BookingAntiDupService] Error rejectPaymentVerification: $e\n$st');
      rethrow;
    }
  }

  /// Get booking dengan ownership validation
  Future<DocumentSnapshot?> getBookingForUser(
    String bookingId,
    String userId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(bookingsCollection)
          .doc(bookingId)
          .get();

      if (!snapshot.exists) return null;

      final data = snapshot.data() ?? {};
      if ((data['userId'] as String?) != userId) {
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
  Stream<List<DocumentSnapshot>> streamCustomerBookingsFiltered({
    required String userId,
    required String filterType, // 'created', 'confirmed', 'payment_pending', 'paid', 'cancelled'
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(bookingsCollection)
        .where('userId', isEqualTo: userId);

    switch (filterType) {
      case 'created':
        query = query.where('status', isEqualTo: 'created');
        break;

      case 'confirmed':
        // Menunggu pembayaran: confirmed & belum upload
        query = query
            .where('status', isEqualTo: 'confirmed')
            .where('payment.verificationStatus', isNull: true);
        break;

      case 'payment_pending':
        // Pembayaran dikirim: verificationStatus = pending
        query = query.where('payment.verificationStatus', isEqualTo: 'pending');
        break;

      case 'paid':
        // Terbayar: status = paid_verified
        query = query.where('status', isEqualTo: 'paid_verified');
        break;

      case 'cancelled':
        query = query.where('status', isEqualTo: 'cancelled');
        break;

      default:
        throw Exception('Filter type tidak dikenali: $filterType');
    }

    query = query.orderBy('createdAt', descending: true);

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
        .collection(bookingsCollection)
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
  /// Return: List<List<String>> dimana setiap inner list adalah group ID yang duplikasi
  /// Gunakan untuk admin cleanup manual
  Future<List<List<String>>> identifyDuplicateBookings() async {
    try {
      final allBookings = await _firestore
          .collection(bookingsCollection)
          .get();

      final Map<String, List<String>> groupByKey = {};

      for (var doc in allBookings.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        final scheduledAt = data['scheduledAt'] as Timestamp?;
        final serviceId = data['serviceId'] as String?;

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
      await _firestore.collection(bookingsCollection).doc(bookingId).update({
        'status': 'duplicate_removed',
        'duplicateRemovedAt': FieldValue.serverTimestamp(),
        'duplicateRemovedReason': reason,
      });

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
