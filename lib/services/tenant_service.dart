import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class TenantService {
  final FirebaseFirestore _fs;
  final FirebaseStorage? _storage; // ignore: unused_field
  final dynamic
  _emailOutboxService; // keep dynamic to avoid import cycle in tests

  TenantService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    dynamic emailOutboxService,
  }) : _fs = firestore ?? FirebaseFirestore.instance,
       _storage = storage,
       _emailOutboxService = emailOutboxService;

  /// Expose the internal firestore instance for dependency injection and tests
  FirebaseFirestore get firestore => _fs;

  /// Create a tenant application document and return the new doc id.
  Future<String> createTenantApplication(Map<String, dynamic> data) async {
    final docRef = _fs.collection('tenants').doc();
    final now = DateTime.now();
    final payload = Map<String, dynamic>.from(data)
      ..addAll({
        'status': 'draft',
        'created_at': Timestamp.fromDate(now),
        'updated_at': Timestamp.fromDate(now),
      });

    await docRef.set(payload);
    return docRef.id;
  }

  /// Update a tenant application with given data
  Future<void> updateTenantApplication(
    String tenantId,
    Map<String, dynamic> data,
  ) async {
    await _fs.collection('tenants').doc(tenantId).update({
      ...data,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Upload a document file for tenant and return a string reference (stored in Firestore as base64).
  ///
  /// Implementation notes:
  /// - Saves a document under `tenants/{tenantId}/documents/{docId}` with fields:
  ///   `filename`, `content_base64`, `content_type`, `size`, `uploaded_by`, `created_at`.
  /// - Returns the document path (e.g. "tenants/{tenantId}/documents/{docId}") for reference.
  Future<String> uploadTenantDocument(
    String tenantId,
    File file, {
    String? filename,
  }) async {
    final fileName = filename ?? file.path.split('/').last;
    final bytes = await file.readAsBytes();
    final base64Content = base64Encode(bytes);

    // safety size limit: keep under ~950KB (payment flow uses 950000 limit)
    const int sizeLimit = 950000;
    if (base64Content.length > sizeLimit) {
      throw Exception(
        'Ukuran file terlalu besar. Silakan kompres atau gunakan file yang lebih kecil.',
      );
    }

    final docRef = _fs
        .collection('tenants')
        .doc(tenantId)
        .collection('documents')
        .doc();
    final userId = (() {
      try {
        return FirebaseFirestore
            .instance
            .app
            .options
            .projectId; // fallback; tests override TenantService
      } catch (_) {
        return null;
      }
    })();

    await docRef.set({
      'filename': fileName,
      'content_base64': base64Content,
      'size': bytes.length,
      'content_type': fileName.split('.').last,
      'uploaded_by': userId,
      'created_at': FieldValue.serverTimestamp(),
    });

    return docRef.path;
  }

  /// Submit registration payment proof (manual proof upload).
  /// Accepts either a 'proofUrl' (legacy/storage) OR a 'proofBase64' payload (preferred - stores in tenant doc).
  Future<void> submitRegistrationPayment({
    required String tenantId,
    String? proofUrl,
    String? proofBase64,
    required String userId,
  }) async {
    final payment = {
      'payment': {
        'method': 'manual',
        'proofUrl': proofUrl,
        'payment_proof_base64': proofBase64,
        'proofLocked': true,
        'verificationStatus': 'pending',
        'paidBy': userId,
        'paidAt': Timestamp.fromDate(DateTime.now()),
      },
    };

    await _fs
        .collection('tenants')
        .doc(tenantId)
        .set(payment, SetOptions(merge: true));

    // append a simple history event so users can track their registration/payment lifecycle
    try {
      await _fs.collection('tenants').doc(tenantId).update({
        'history': FieldValue.arrayUnion([
          {
            'type': 'registration_payment',
            'status': 'pending',
            'note': 'Bukti pembayaran terkirim dan sedang diproses',
            'created_at': FieldValue.serverTimestamp(),
          },
        ]),
      });
    } catch (_) {
      // best-effort: do not fail the main operation if history append fails
    }
  }

  /// Admin verifies tenant (approve or reject)
  Future<void> verifyTenant({
    required String tenantId,
    required bool approve,
    String? verifiedBy,
    String? reason,
  }) async {
    final update = <String, dynamic>{
      'status': approve ? 'active' : 'rejected',
      'verified_by': verifiedBy,
      'verified_at': Timestamp.fromDate(DateTime.now()),
    };
    if (!approve && reason != null) update['rejection_reason'] = reason;

    await _fs.collection('tenants').doc(tenantId).update(update);

    // After updating tenant status, queue notification & email to owner
    try {
      final tenantDoc = await _fs.collection('tenants').doc(tenantId).get();
      final Map<String, dynamic>? data = tenantDoc.data();
      if (data != null) {
        final ownerUid = data['owner_uid'] as String?;
        final ownerEmail = data['owner_email'] as String?;

        // create a user notification doc for FCM/local handling
        if (ownerUid != null) {
          final title = approve
              ? 'Pendaftaran Tenant Disetujui'
              : 'Pendaftaran Tenant Ditolak';
          final body = approve
              ? 'Pendaftaran tenant Anda telah disetujui. Anda sekarang dapat melanjutkan setup.'
              : 'Pendaftaran tenant Anda ditolak oleh admin.${reason != null ? '\nAlasan: $reason' : ''}';

          await _fs.collection('notifications').add({
            'user_id': ownerUid,
            'title': title,
            'body': body,
            'delivered': false,
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        // queue an email in outbox if available
        if (ownerEmail != null && _emailOutboxService != null) {
          final subject = approve
              ? 'Tenant Registration Approved'
              : 'Tenant Registration Rejected';
          final body = approve
              ? 'Selamat — tenant Anda telah disetujui. Silakan periksa dashboard untuk langkah selanjutnya.'
              : 'Maaf — tenant Anda ditolak. ${reason ?? ''}';

          try {
            await _emailOutboxService.queueEmail(
              to: ownerEmail,
              subject: subject,
              body: body,
              metadata: {'tenantId': tenantId, 'approved': approve},
            );
          } catch (_) {
            // best-effort: swallow email failures so admin flow is not blocked
          }
        }
      }
    } catch (_) {
      // best-effort
    }
  }
}
