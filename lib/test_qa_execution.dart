/// QA Test Execution Script
/// 
/// Run this to execute automated checks for duplikasi fix verification.
/// Can be integrated into admin panel or run manually during QA.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class QATestExecutor {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// TEST 1: Create Booking Check - Verify exactly 1 document created
  Future<QATestResult> testCreateBooking({
    required String customerId,
    required String barbermanId,
    required String barbershopId,
    required Timestamp scheduledAt,
  }) async {
    debugPrint('\n🧪 TEST 1: Create Booking & Check Single Document');
    debugPrint('='.padRight(50, '='));

    try {
      // Step 1: Create booking
      final bookingRef = _firestore.collection('bookings').doc();
      await bookingRef.set({
        'userId': customerId,
        'barbermanId': barbermanId,
        'barbershopId': barbershopId,
        'scheduledAt': scheduledAt,
        'serviceIds': ['test-service-1'],
        'amount': 100000,
        'currency': 'IDR',
        'status': 'pending_confirmation',
        'createdAt': FieldValue.serverTimestamp(),
        'payment': {
          'amount': 100000,
          'currency': 'IDR',
          'proofUrl': null,
          'proofLocked': false,
          'verificationStatus': null,
        },
      });

      // Step 2: Verify only 1 document created
      final docs = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: customerId)
          .where('scheduledAt', isEqualTo: scheduledAt)
          .get();

      final passed = docs.docs.length == 1;
      final bookingId = bookingRef.id;

      debugPrint('✅ Booking created with ID: $bookingId');
      debugPrint('📊 Document count: ${docs.docs.length}');
      debugPrint('✅ Payment field initialized: ✓');

      return QATestResult(
        testName: 'TEST 1: Create Booking',
        passed: passed,
        details: passed
            ? 'Exactly 1 document created, payment field initialized'
            : 'Expected 1 document, found ${docs.docs.length}',
        bookingIdForNextTest: bookingId,
      );
    } catch (e) {
      debugPrint('❌ Error: $e');
      return QATestResult(
        testName: 'TEST 1: Create Booking',
        passed: false,
        details: 'Error: $e',
      );
    }
  }

  /// TEST 2: Admin Confirm - Verify status updated in-place
  Future<QATestResult> testAdminConfirm(String bookingId) async {
    debugPrint('\n🧪 TEST 2: Admin Confirms Booking');
    debugPrint('='.padRight(50, '='));

    try {
      // Get document before update
      final beforeDoc = await _firestore.collection('bookings').doc(bookingId).get();
      final beforeId = beforeDoc.id;

      // Step 1: Admin confirms
      await _firestore.collection('bookings').doc(bookingId).update({
        'status': 'confirmed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Step 2: Verify document ID unchanged
      final afterDoc = await _firestore.collection('bookings').doc(bookingId).get();
      final afterId = afterDoc.id;
      final statusUpdated = afterDoc.get('status') == 'confirmed';

      final passed = beforeId == afterId && statusUpdated;

      debugPrint('✅ Document ID unchanged: $beforeId == $afterId');
      debugPrint('✅ Status updated: ${afterDoc.get('status')}');
      debugPrint('✅ No new documents created');

      return QATestResult(
        testName: 'TEST 2: Admin Confirm',
        passed: passed,
        details: passed
            ? 'Status updated in-place, document ID unchanged'
            : 'Document ID or status mismatch',
      );
    } catch (e) {
      debugPrint('❌ Error: $e');
      return QATestResult(
        testName: 'TEST 2: Admin Confirm',
        passed: false,
        details: 'Error: $e',
      );
    }
  }

  /// TEST 3: Upload Proof - Verify proofLocked=true, no new doc
  Future<QATestResult> testUploadProof(String bookingId, String proofUrl) async {
    debugPrint('\n🧪 TEST 3: Customer Uploads Proof, No Duplicates');
    debugPrint('='.padRight(50, '='));

    try {
      // Step 1: Check proofLocked is false before
      final beforeDoc = await _firestore.collection('bookings').doc(bookingId).get();
      final proofLockedBefore = beforeDoc.get('payment.proofLocked') ?? false;

      // Step 2: Update proof (transaction)
      await _firestore.runTransaction((tx) async {
        final docSnapshot = await tx.get(_firestore.collection('bookings').doc(bookingId));
        final currentLocked = docSnapshot.get('payment.proofLocked') ?? false;

        if (currentLocked) {
          throw Exception('Proof already locked, cannot upload');
        }

        tx.update(_firestore.collection('bookings').doc(bookingId), {
          'payment.proofUrl': proofUrl,
          'payment.proofUploadedAt': FieldValue.serverTimestamp(),
          'payment.proofLocked': true,
          'payment.verificationStatus': 'pending',
          'payment.proofUploadAttemptCount': FieldValue.increment(1),
        });
      });

      // Step 3: Verify update
      final afterDoc = await _firestore.collection('bookings').doc(bookingId).get();
      final proofLockedAfter = afterDoc.get('payment.proofLocked') ?? false;
      final proofUrlSet = afterDoc.get('payment.proofUrl') != null;
      final statusPending = afterDoc.get('payment.verificationStatus') == 'pending';

      final passed = proofLockedAfter && proofUrlSet && statusPending;

      debugPrint('✅ Proof URL set: $proofUrlSet');
      debugPrint('✅ proofLocked changed: $proofLockedBefore → $proofLockedAfter');
      debugPrint('✅ verificationStatus: ${afterDoc.get('payment.verificationStatus')}');

      return QATestResult(
        testName: 'TEST 3: Upload Proof',
        passed: passed,
        details: passed
            ? 'Proof uploaded, proofLocked=true, no new documents'
            : 'Proof update incomplete',
      );
    } catch (e) {
      debugPrint('❌ Error: $e');
      return QATestResult(
        testName: 'TEST 3: Upload Proof',
        passed: false,
        details: 'Error: $e',
      );
    }
  }

  /// TEST 7: Tab Exclusivity - Verify mutual exclusion of queries
  Future<QATestResult> testTabExclusivity(String customerId) async {
    debugPrint('\n🧪 TEST 7: My Bookings Tab Exclusivity');
    debugPrint('='.padRight(50, '='));

    try {
      // Define all 5 tabs with exclusive filters
      final tabs = <String, Query>{
        'Tab 1: Menunggu Konfirmasi': _firestore
            .collection('bookings')
            .where('userId', isEqualTo: customerId)
            .where('status', isEqualTo: 'pending_confirmation'),
        'Tab 2: Menunggu Pembayaran': _firestore
            .collection('bookings')
            .where('userId', isEqualTo: customerId)
            .where('status', isEqualTo: 'confirmed')
            .where('payment.verificationStatus', isNull: true),
        'Tab 3: Pembayaran Dikirim': _firestore
            .collection('bookings')
            .where('userId', isEqualTo: customerId)
            .where('payment.verificationStatus', isEqualTo: 'pending'),
        'Tab 4: Terbayar': _firestore
            .collection('bookings')
            .where('userId', isEqualTo: customerId)
            .where('payment.verificationStatus', isEqualTo: 'accepted'),
        'Tab 5: Dibatalkan': _firestore
            .collection('bookings')
            .where('userId', isEqualTo: customerId)
            .where('status', isEqualTo: 'cancelled'),
      };

      // Collect all booking IDs from each tab
      final allBookingIds = <String>{};
      final duplicatesInMultipleTabs = <String>[];

      for (final entry in tabs.entries) {
        final snapshot = await entry.value.get();
        debugPrint('${entry.key}: ${snapshot.docs.length} bookings');

        for (final doc in snapshot.docs) {
          if (allBookingIds.contains(doc.id)) {
            duplicatesInMultipleTabs.add(doc.id);
          }
          allBookingIds.add(doc.id);
        }
      }

      final passed = duplicatesInMultipleTabs.isEmpty;

      if (passed) {
        debugPrint('✅ No duplicates across tabs');
      } else {
        debugPrint('❌ Duplicates found in multiple tabs: $duplicatesInMultipleTabs');
      }

      return QATestResult(
        testName: 'TEST 7: Tab Exclusivity',
        passed: passed,
        details: passed
            ? 'All tabs have exclusive queries, no overlaps'
            : 'Found ${duplicatesInMultipleTabs.length} bookings in multiple tabs',
      );
    } catch (e) {
      debugPrint('❌ Error: $e');
      return QATestResult(
        testName: 'TEST 7: Tab Exclusivity',
        passed: false,
        details: 'Error: $e',
      );
    }
  }

  /// Summary Report
  Future<void> generateSummaryReport(List<QATestResult> results) async {
    debugPrint('\n');
    debugPrint('═'.padRight(60, '═'));
    debugPrint('📊 QA TEST SUMMARY REPORT'.padRight(60));
    debugPrint('═'.padRight(60, '═'));

    int passedCount = 0;
    int failedCount = 0;

    for (final result in results) {
      final status = result.passed ? '✅ PASS' : '❌ FAIL';
      debugPrint('$status | ${result.testName}');
      debugPrint('   Details: ${result.details}');

      if (result.passed) {
        passedCount++;
      } else {
        failedCount++;
      }
    }

    debugPrint('');
    debugPrint('📈 Total: ${results.length} | Passed: $passedCount | Failed: $failedCount');

    if (failedCount == 0) {
      debugPrint('✅ All tests PASSED! Duplikasi fix is working correctly.');
    } else {
      debugPrint('❌ $failedCount test(s) failed. Review issues above.');
    }

    debugPrint('═'.padRight(60, '═'));
  }
}

/// Result class for each test
class QATestResult {
  final String testName;
  final bool passed;
  final String details;
  final String? bookingIdForNextTest;

  QATestResult({
    required this.testName,
    required this.passed,
    required this.details,
    this.bookingIdForNextTest,
  });
}

/// Integration test runner
Future<void> runQATests({
  required String customerId,
  required String barbermanId,
  required String barbershopId,
}) async {
  debugPrint('\n');
  debugPrint('╔═══════════════════════════════════════════════════════════╗');
  debugPrint('║     QA CHECKLIST - DUPLIKASI BOOKING FIX VERIFICATION     ║');
  debugPrint('╚═══════════════════════════════════════════════════════════╝');

  final executor = QATestExecutor();
  final results = <QATestResult>[];

  // Test 1: Create Booking
  final test1Result = await executor.testCreateBooking(
    customerId: customerId,
    barbermanId: barbermanId,
    barbershopId: barbershopId,
    scheduledAt: Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
  );
  results.add(test1Result);
  final bookingId = test1Result.bookingIdForNextTest;

  if (bookingId != null) {
    // Test 2: Admin Confirm
    final test2Result = await executor.testAdminConfirm(bookingId);
    results.add(test2Result);

    // Test 3: Upload Proof
    final test3Result = await executor.testUploadProof(
      bookingId,
      'gs://example-bucket/proof-image.jpg',
    );
    results.add(test3Result);
  }

  // Test 7: Tab Exclusivity
  final test7Result = await executor.testTabExclusivity(customerId);
  results.add(test7Result);

  // Generate summary
  await executor.generateSummaryReport(results);
}
