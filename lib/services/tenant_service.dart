import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geges_smartbarber/models/tenant.dart';



abstract class TenantServiceContract {
  Future<Tenant> createTenant({required String businessName, required String documentBase64, required String packageId});
  Future<void> markPaid(String tenantId, String invoiceId);
  Future<void> attachInvoice(String tenantId, {required String invoiceId, required DateTime deadline});
  Future<void> submitRegistrationPayment({required String tenantId, String? proofUrl, String? proofBase64, required String userId});
  Future<void> cancelRegistrationByOwner({required String tenantId, required String userId, String? reason});
  Future<Tenant?> getActiveRegistrationForOwner(String ownerUid);
}

class TenantService implements TenantServiceContract {
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
  @override
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

  /// Owner cancels registration/payment
  @override
  Future<void> cancelRegistrationByOwner({
    required String tenantId,
    required String userId,
    String? reason,
  }) async {
    await _fs.collection('tenants').doc(tenantId).update({
      'invoice.status': 'cancelled_by_owner',
      'invoice.cancelled_by': userId,
      'invoice.cancel_reason': reason ?? 'Dibatalkan oleh pemilik',
      'history': FieldValue.arrayUnion([
        {
          'type': 'registration_cancelled_by_owner',
          'note': reason ?? 'Dibatalkan oleh pemilik',
          'created_at': FieldValue.serverTimestamp(),
        }
      ]),
    });
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

  /// Cancel tenant invoices whose payment_deadline has passed and are still pending proof.
  /// Returns the number of invoices cancelled.
  Future<int> cancelExpiredInvoices() async {
    final now = Timestamp.fromDate(DateTime.now());
    final coll = _fs.collection('tenants');

    int updated = 0;

    // Query for tenants with invoice.payment_deadline < now
    try {
      final q = await coll.where('invoice.payment_deadline', isLessThan: now).get();
      for (final doc in q.docs) {
        final data = doc.data();
        final invoice = data['invoice'] as Map<String, dynamic>?;
        if (invoice == null) continue;
        final status = (invoice['status'] ?? '').toString();
        if (status == 'waiting_proof' || status == 'waiting' || status == 'payment_submitted') {
          await doc.reference.update({
            'invoice.status': 'payment_timeout_cancelled',
            'history': FieldValue.arrayUnion([
              {
                'type': 'registration_payment_timeout',
                'note': 'Pendaftaran dibatalkan karena waktu pembayaran habis',
                'created_at': FieldValue.serverTimestamp(),
              }
            ]),
          });
          updated += 1;
        }
      }
    } catch (e) {
      // best-effort: if query fails due to index requirements, fallback to scanning all tenants (small-scale assumption)
      final all = await coll.get();
      for (final doc in all.docs) {
        final data = doc.data();
        final invoice = data['invoice'] as Map<String, dynamic>?;
        if (invoice == null) continue;
        final deadline = invoice['payment_deadline'] as Timestamp?;
        if (deadline != null && deadline.compareTo(now) < 0) {
          final status = (invoice['status'] ?? '').toString();
          if (status == 'waiting_proof' || status == 'waiting' || status == 'payment_submitted') {
            await doc.reference.update({
              'invoice.status': 'payment_timeout_cancelled',
              'history': FieldValue.arrayUnion([
                {
                  'type': 'registration_payment_timeout',
                  'note': 'Pendaftaran dibatalkan karena waktu pembayaran habis',
                  'created_at': FieldValue.serverTimestamp(),
                }
              ]),
            });
            updated += 1;
          }
        }
      }
    }

    return updated;
  }

  /// Convenience: create a tenant and return a lightweight Tenant model
  @override
  /// Convenience: create a tenant and return a lightweight Tenant model
  /// If the owner already has an active (non-final) registration, returns that tenant instead
  @override
  Future<Tenant> createTenant({required String businessName, required String documentBase64, required String packageId}) async {
    // Best-effort check for existing active registration for current user
    try {
      final currentUserId = (() {
        try {
          // avoid importing firebase_auth in all environments; use FirebaseFirestore instance to inspect projectId as fallback in tests
          return FirebaseFirestore.instance.app.options.projectId;
        } catch (_) {
          return null;
        }
      })();

      if (currentUserId != null) {
        final existing = await getActiveRegistrationForOwner(currentUserId);
        if (existing != null) {
          return existing;
        }
      }
    } catch (_) {
      // best effort — proceed to create if query fails
    }

    final id = await createTenantApplication({
      'business_name': businessName,
      'document_base64': documentBase64,
      'package_id': packageId,
    });
    return Tenant(id: id, businessName: businessName, documentBase64: documentBase64, packageId: packageId);
  }

  /// Returns an active (in-progress) tenant registration for the given ownerUid
  Future<Tenant?> getActiveRegistrationForOwner(String ownerUid) async {
    final coll = _fs.collection('tenants');
    final now = Timestamp.fromDate(DateTime.now());
    final inProgressStatuses = ['draft', 'awaiting_payment', 'awaiting_confirmation', 'payment_submitted', 'waiting_proof'];

    try {
      final q = await coll.where('owner_uid', isEqualTo: ownerUid).get();
      for (final doc in q.docs) {
        final data = doc.data();
        final status = (data['status'] as String?) ?? '';
        if (inProgressStatuses.contains(status)) {
          return Tenant(
            id: doc.id,
            businessName: data['business_name'] as String? ?? '',
            documentBase64: data['document_base64'] as String? ?? '',
            packageId: data['package_id'] as String? ?? '',
            status: status,
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Attach an invoice (id + deadline) to tenant and set status to awaiting_payment
  @override
  Future<void> attachInvoice(String tenantId, {required String invoiceId, required DateTime deadline}) async {
    await _fs.collection('tenants').doc(tenantId).update({
      'invoice_id': invoiceId,
      'payment_deadline': Timestamp.fromDate(deadline),
      'status': 'awaiting_payment',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Mark tenant invoice as paid (owner/view will call this after successful payment)
  @override
  Future<void> markPaid(String tenantId, String invoiceId) async {
    await _fs.collection('tenants').doc(tenantId).update({
      'status': 'awaiting_confirmation',
      'invoice_id': invoiceId,
      'paid_at': FieldValue.serverTimestamp(),
    });
  }
}

