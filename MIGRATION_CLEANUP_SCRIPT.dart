/// Migration Script: Cleanup Duplicate Bookings
/// 
/// Gunakan untuk mengidentifikasi dan menandai booking duplikat di Firestore.
/// 
/// Jalankan sekali setelah deploy new screens ke production.
/// Lihat QA_CHECKLIST untuk test case duplikasi.

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
      DocumentSnapshot? authoritative = docs.first;

      for (final doc in docs) {
        final authData = (authoritative.data() as Map?) ?? {};
        final currData = (doc.data() as Map?) ?? {};

        final authPayment = authData['payment'] as Map? ?? {};
        final currPayment = currData['payment'] as Map? ?? {};

        // Priority 1: Yang sudah punya bukti pembayaran
        final authHasProof = authPayment['proofUrl'] != null;
        final currHasProof = currPayment['proofUrl'] != null;

        if (currHasProof && !authHasProof) {
          authoritative = doc;
          continue;
        } else if (!currHasProof && authHasProof) {
          continue;
        }

        // Priority 2: Yang sudah verified
        if (currHasProof && authHasProof) {
          final authVerified = authPayment['verificationStatus'] == 'accepted';
          final currVerified = currPayment['verificationStatus'] == 'accepted';

          if (currVerified && !authVerified) {
            authoritative = doc;
            continue;
          } else if (!currVerified && authVerified) {
            continue;
          }
        }

        // Priority 3: Terbaru (createdAt)
        final authCreated = authData['createdAt'] as Timestamp?;
        final currCreated = currData['createdAt'] as Timestamp?;

        if (currCreated != null &&
            (authCreated == null ||
                currCreated.compareTo(authCreated) > 0)) {
          authoritative = doc;
        }
      }

      authoritativeMap[entry.key] = authoritative!.id;
      debugPrint('  ✓ Group ${entry.key.split("|").join(" | ")}: '
          'keep ${authoritative.id}');
    }

    return authoritativeMap;
  }

  /// Mark non-authoritative booking sebagai duplicate_removed
  Future<void> markDuplicatesAsRemoved(
    Map<String, List<String>> duplicates,
    Map<String, String> authoritative,
  ) async {
    debugPrint('🗑️ Mark duplikat sebagai removed...');

    int totalMarked = 0;

    for (final entry in duplicates.entries) {
      final authId = authoritative[entry.key];
      if (authId == null) continue;

      for (final bookingId in entry.value) {
        if (bookingId == authId) continue; // Skip authoritative

        try {
          await _firestore.collection('bookings').doc(bookingId).update({
            'status': 'duplicate_removed',
            'cancellation': {
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelledBy': 'system',
              'cancelledReason':
                  'Marked as duplicate of $authId during migration cleanup',
            },
            'updatedAt': FieldValue.serverTimestamp(),
          });

          debugPrint('  ✓ Marked $bookingId as duplicate_removed');
          totalMarked++;
        } catch (e) {
          debugPrint('  ✗ Error marking $bookingId: $e');
        }
      }
    }

    debugPrint('📈 Total marked as removed: $totalMarked');
  }

  /// Full cleanup flow
  Future<void> runFullCleanup() async {
    debugPrint('\n🚀 === DUPLICATE CLEANUP MIGRATION STARTED ===\n');

    try {
      // Step 1: Identify
      final duplicates = await identifyDuplicates();

      if (duplicates.isEmpty) {
        debugPrint('✅ No duplicates found. Cleanup completed!');
        return;
      }

      // Step 2: Determine authoritative
      final authoritative = await determineAuthoritative(duplicates);

      // Step 3: Mark as removed
      await markDuplicatesAsRemoved(duplicates, authoritative);

      debugPrint('\n✅ === CLEANUP COMPLETED SUCCESSFULLY ===\n');
    } catch (e) {
      debugPrint('\n❌ === CLEANUP FAILED ===\n');
      debugPrint('Error: $e');
      rethrow;
    }
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

      debugPrint('\n📋 What would be done:');
      for (final entry in duplicates.entries) {
        debugPrint('  Group: ${entry.value.join(", ")}');
        debugPrint('    - Would keep 1 booking');
        debugPrint('    - Would mark ${entry.value.length - 1} as duplicate_removed');
      }

      debugPrint('\n✅ Dry run completed. To apply changes, call runFullCleanup()');
    } catch (e) {
      debugPrint('Error during dry run: $e');
      rethrow;
    }
  }
}

/// Usage dalam app:
/// 
/// ```dart
/// // 1. Dry run terlebih dahulu (recommended)
/// final migration = DuplicateBookingMigration();
/// await migration.dryRun();
/// 
/// // 2. Setelah review hasil dry run, jalankan full cleanup
/// await migration.runFullCleanup();
/// ```
/// 
/// Atau integrasikan ke admin panel sebagai button:
/// 
/// ```dart
/// ElevatedButton(
///   onPressed: () async {
///     final migration = DuplicateBookingMigration();
///     
///     showDialog(
///       context: context,
///       builder: (context) => AlertDialog(
///         title: const Text('Cleanup Duplicates?'),
///         content: const Text(
///           'Proses ini akan mengidentifikasi dan menandai booking duplikat '
///           'sebagai duplicate_removed.\n\n'
///           'Apakah Anda yakin?'
///         ),
///         actions: [
///           TextButton(
///             onPressed: () => Navigator.pop(context),
///             child: const Text('Batal'),
///           ),
///           ElevatedButton(
///             onPressed: () async {
///               try {
///                 Navigator.pop(context);
///                 
///                 ScaffoldMessenger.of(context).showSnackBar(
///                   const SnackBar(content: Text('Cleanup sedang berjalan...')),
///                 );
///                 
///                 await migration.runFullCleanup();
///                 
///                 ScaffoldMessenger.of(context).showSnackBar(
///                   const SnackBar(
///                     content: Text('Cleanup selesai!'),
///                     backgroundColor: Colors.green,
///                   ),
///                 );
///               } catch (e) {
///                 ScaffoldMessenger.of(context).showSnackBar(
///                   SnackBar(
///                     content: Text('Error: $e'),
///                     backgroundColor: Colors.red,
///                   ),
///                 );
///               }
///             },
///             child: const Text('Jalankan Cleanup'),
///           ),
///         ],
///       ),
///     );
///   },
///   child: const Text('Cleanup Duplicate Bookings'),
/// )
/// ```

/* ============================================================ */
/* IMPLEMENTATION CHECKLIST */
/* ============================================================ */

/*
Sebelum menjalankan cleanup di production:

[ ] 1. Backup Firestore collection 'bookings'
      Command: Download via Firebase Console atau cloud shell
      
[ ] 2. Test di staging database terlebih dahulu
      - Gunakan test_bookings collection
      - Atau create staging Firestore project
      
[ ] 3. Jalankan dry run di production
      await DuplicateBookingMigration().dryRun();
      
[ ] 4. Review hasil dry run
      - Pastikan group yang diidentifikasi benar
      - Pastikan authoritative booking dipilih dengan tepat
      
[ ] 5. Jalankan full cleanup di production
      await DuplicateBookingMigration().runFullCleanup();
      
[ ] 6. Verify di Firestore console
      - Cek booking dengan status='duplicate_removed'
      - Pastikan jumlah sesuai dengan report
      
[ ] 7. Monitor logs untuk 24 jam
      - Check error patterns
      - Verify no customer complaints
      
[ ] 8. Document hasil cleanup
      - Simpan log output
      - Update issue tracking system
*/
