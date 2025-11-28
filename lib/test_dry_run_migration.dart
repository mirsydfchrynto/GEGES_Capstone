/// Test Dry Run for Migration Cleanup
/// 
/// Jalankan di main.dart atau dari admin panel untuk identify duplikat tanpa modifikasi data

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DuplicateBookingMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Identifikasi booking duplikat berdasarkan userId + scheduledAt + serviceId
  Future<Map<String, List<String>>> identifyDuplicates() async {
    debugPrint('🔍 Mulai identifikasi duplikat...');

    final bookings = await _firestore.collection('bookings').get();
    
    // Group by userId + scheduledAt + serviceId
    final Map<String, List<String>> groups = {};

    for (final doc in bookings.docs) {
      final data = doc.data();
      final userId = data['userId'] as String?;
      final scheduledAt = data['scheduledAt'] as Timestamp?;
      
      // Ambil serviceId dari nested services array atau field
      final services = data['services'] as List? ?? [];
      String? serviceId;
      if (services.isNotEmpty) {
        final firstService = services.first;
        if (firstService is Map) {
          serviceId = firstService['serviceId'] as String?;
        } else if (firstService is String) {
          serviceId = firstService;
        }
      }

      if (userId != null && scheduledAt != null && serviceId != null) {
        final key = '$userId|${scheduledAt.toDate()}|$serviceId';
        groups.putIfAbsent(key, () => []);
        groups[key]!.add(doc.id);
      }
    }

    // Filter hanya yang memiliki duplikat (size > 1)
    final duplicates = <String, List<String>>{};
    for (final entry in groups.entries) {
      if (entry.value.length > 1) {
        duplicates[entry.key] = entry.value;
      }
    }

    debugPrint('📊 Hasil: ${duplicates.length} grup duplikat ditemukan');
    for (final entry in duplicates.entries) {
      debugPrint('  - ${entry.value.join(", ")} (${entry.value.length} docs)');
    }

    return duplicates;
  }

  /// Tentukan booking mana yang "authoritative" (yang harus dikeep)
  /// Prioritas: 
  /// 1. Sudah upload bukti (proofUrl != null)
  /// 2. Sudah verified (verificationStatus='accepted')
  /// 3. Terbaru (latest createdAt)
  Future<Map<String, String>> determineAuthoritative(
    Map<String, List<String>> duplicates,
  ) async {
    debugPrint('🎯 Tentukan booking authoritative...');

    final Map<String, String> authoritativeMap = {};

    for (final entry in duplicates.entries) {
      final bookingIds = entry.value;
      final docs = <DocumentSnapshot>[];

      // Fetch semua document dalam grup
      for (final id in bookingIds) {
        final doc = await _firestore.collection('bookings').doc(id).get();
        if (doc.exists) {
          docs.add(doc);
        }
      }

      if (docs.isEmpty) continue;

      // Tentukan authoritative berdasarkan prioritas
      late DocumentSnapshot authoritative;
      authoritative = docs.first;

      for (final doc in docs) {
        final authData = (authoritative.data() as Map? ?? {});
        final currData = (doc.data() as Map? ?? {});

        final authPayment = authData['payment'] as Map? ?? {};
        final currPayment = currData['payment'] as Map? ?? {};

        // Priority 1: Yang sudah punya bukti pembayaran
        final authHasProof = authPayment['proofUrl'] != null;
        final currHasProof = currPayment['proofUrl'] != null;

        if (currHasProof && !authHasProof) {
          authoritative = doc;
          continue;
        }

        // Priority 2: Yang sudah verified
        final authVerified = authPayment['verificationStatus'] == 'accepted';
        final currVerified = currPayment['verificationStatus'] == 'accepted';

        if (currVerified && !authVerified) {
          authoritative = doc;
          continue;
        }

        // Priority 3: Terbaru
        final authCreated = authData['createdAt'] as Timestamp?;
        final currCreated = currData['createdAt'] as Timestamp?;

        if (currCreated != null && authCreated != null && currCreated.compareTo(authCreated) > 0) {
          authoritative = doc;
        }
      }

      authoritativeMap[entry.key] = authoritative.id;
    }

    return authoritativeMap;
  }

  /// Dry run: hanya report, jangan modify
  Future<void> dryRun() async {
    debugPrint('\n🔍 === DRY RUN MODE (No changes made) ===\n');

    try {
      final duplicates = await identifyDuplicates();

      if (duplicates.isEmpty) {
        debugPrint('✅ No duplicates found.');
        return;
      }

      final authoritative = await determineAuthoritative(duplicates);

      debugPrint('\n📋 REPORT - What would be done:');
      debugPrint('Total duplikat groups: ${duplicates.length}');
      
      int totalDuplicates = 0;
      for (final entry in duplicates.entries) {
        final bookingIds = entry.value;
        final authId = authoritative[entry.key];
        final duplicateIds = bookingIds.where((id) => id != authId).toList();
        
        totalDuplicates += duplicateIds.length;
        
        debugPrint('\n  Group: ${bookingIds.join(", ")}');
        debugPrint('    - KEEP (authoritative): $authId');
        debugPrint('    - REMOVE (mark as duplicate_removed): ${duplicateIds.join(", ")}');
      }

      debugPrint('\n📊 Summary:');
      debugPrint('  - Total booking groups with duplicates: ${duplicates.length}');
      debugPrint('  - Total duplicate documents to mark: $totalDuplicates');
      debugPrint('  - Total authoritative to keep: ${duplicates.length}');

      debugPrint('\n✅ Dry run completed. To apply changes, call runFullCleanup()');
    } catch (e) {
      debugPrint('Error during dry run: $e');
      rethrow;
    }
  }

  /// Full cleanup: identifikasi dan tandai duplicate
  Future<void> runFullCleanup() async {
    debugPrint('\n⚠️ === FULL CLEANUP MODE (Making changes) ===\n');

    try {
      final duplicates = await identifyDuplicates();

      if (duplicates.isEmpty) {
        debugPrint('✅ No duplicates found. Nothing to clean up.');
        return;
      }

      final authoritative = await determineAuthoritative(duplicates);

      debugPrint('\n🗑️ Menghapus ${duplicates.length} grup duplikat...');

      int removedCount = 0;
      for (final entry in duplicates.entries) {
        final bookingIds = entry.value;
        final authId = authoritative[entry.key];

        for (final id in bookingIds) {
          if (id != authId) {
            // Soft delete: tandai sebagai duplicate_removed
            await _firestore.collection('bookings').doc(id).update({
              'status': 'duplicate_removed',
              'reason': 'Booking duplikat, authoritative adalah $authId',
              'removedAt': FieldValue.serverTimestamp(),
            });
            removedCount++;
            debugPrint('  ✓ Marked $id as duplicate_removed (keeping $authId)');
          }
        }
      }

      debugPrint('\n✅ === CLEANUP COMPLETED SUCCESSFULLY ===\n');
      debugPrint('Total marked as duplicate_removed: $removedCount');
    } catch (e) {
      debugPrint('\n❌ === CLEANUP FAILED ===\n');
      debugPrint('Error: $e');
      rethrow;
    }
  }
}

/// Test function - jalankan dari main.dart atau admin panel
Future<void> testDryRunMigration() async {
  debugPrint('\n========== STARTING DRY RUN TEST ==========\n');
  
  try {
    final migration = DuplicateBookingMigration();
    await migration.dryRun();
  } catch (e) {
    debugPrint('Test failed: $e');
  }
  
  debugPrint('\n========== DRY RUN TEST COMPLETED ==========\n');
}
