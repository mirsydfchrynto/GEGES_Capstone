import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class TenantService {
  final FirebaseFirestore _fs;
  final FirebaseStorage? _storage;
  final dynamic _emailOutboxService; // keep dynamic to avoid import cycle in tests

  TenantService({FirebaseFirestore? firestore, FirebaseStorage? storage, dynamic emailOutboxService}) : _fs = firestore ?? FirebaseFirestore.instance, _storage = storage, _emailOutboxService = emailOutboxService;

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
  Future<void> updateTenantApplication(String tenantId, Map<String, dynamic> data) async {
    await _fs.collection('tenants').doc(tenantId).update(
      {...data, 'updated_at': Timestamp.fromDate(DateTime.now())},
    );
  }

  /// Upload a document file for tenant and return download URL.
  Future<String> uploadTenantDocument(String tenantId, File file, {String? filename}) async {
    final fileName = filename ?? file.path.split('/').last;
    final st = _storage ?? FirebaseStorage.instance;
    final ref = st.ref().child('tenants/$tenantId/docs/$fileName');
    final task = await ref.putFile(file);
    final url = await task.ref.getDownloadURL();
    return url;
  }

  /// Submit registration payment proof (manual proof upload)
  Future<void> submitRegistrationPayment({
    required String tenantId,
    required String proofUrl,
    required String userId,
  }) async {
    final payment = {
      'payment': {
        'method': 'manual',
        'proofUrl': proofUrl,
        'proofLocked': true,
        'verificationStatus': 'pending',
        'paidBy': userId,
        'paidAt': Timestamp.fromDate(DateTime.now()),
      }
    };

    await _fs.collection('tenants').doc(tenantId).set(payment, SetOptions(merge: true));
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
          final title = approve ? 'Pendaftaran Tenant Disetujui' : 'Pendaftaran Tenant Ditolak';
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
          final subject = approve ? 'Tenant Registration Approved' : 'Tenant Registration Rejected';
          final body = approve
              ? 'Selamat — tenant Anda telah disetujui. Silakan periksa dashboard untuk langkah selanjutnya.'
              : 'Maaf — tenant Anda ditolak. ${reason ?? ''}';

          try {
            await _emailOutboxService.queueEmail(to: ownerEmail, subject: subject, body: body, metadata: {'tenantId': tenantId, 'approved': approve});
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
