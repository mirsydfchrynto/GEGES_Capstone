import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class TenantService {
  final FirebaseFirestore _fs;
  final FirebaseStorage? _storage;

  TenantService({FirebaseFirestore? firestore, FirebaseStorage? storage}) : _fs = firestore ?? FirebaseFirestore.instance, _storage = storage;

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
  }
}
