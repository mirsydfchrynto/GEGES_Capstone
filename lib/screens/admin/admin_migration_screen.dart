/// Admin Migration & QA Screen
/// 
/// Untuk admin menjalankan:
/// 1. Dry-run analysis (identify duplicates)
/// 2. QA tests (verify fix works)
/// 3. Full cleanup (mark duplicates)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geges_smartbarber/test_dry_run_migration.dart';
import 'package:geges_smartbarber/test_qa_execution.dart';

class AdminMigrationScreen extends StatefulWidget {
  const AdminMigrationScreen({super.key});

  @override
  State<AdminMigrationScreen> createState() => _AdminMigrationScreenState();
}

class _AdminMigrationScreenState extends State<AdminMigrationScreen> {
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String _output = '';
  final ScrollController _scrollController = ScrollController();

  void _log(String message) {
    setState(() {
      _output += '$message\n';
    });
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _runDryRun() async {
    setState(() {
      _isLoading = true;
      _output = '🔍 Starting dry-run analysis...\n\n';
    });

    try {
      final migration = DuplicateBookingMigration();
      await migration.dryRun();
      _log('\n✅ Dry-run completed. Check console for full output.');
    } catch (e) {
      _log('\n❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runQATests() async {
    setState(() {
      _isLoading = true;
      _output = '🧪 Starting QA tests...\n\n';
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _log('❌ Not logged in');
        return;
      }

      // For testing, use dummy IDs (in production, get from UI inputs)
      await runQATests(
        customerId: userId,
        barbermanId: 'test-barberman-1',
        barbershopId: 'test-barbershop-1',
      );
      _log('\n✅ QA tests completed. Check console for details.');
    } catch (e) {
      _log('\n❌ Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showConfirmDialog(
    String title,
    String message,
    Future<void> Function() onConfirm,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Proceed', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _runFullCleanup() async {
    await _showConfirmDialog(
      'Full Cleanup Confirmation',
      'This will mark all duplicate bookings as "duplicate_removed".\n\n'
      'Make sure you ran dry-run first and reviewed the report.\n\n'
      'This action cannot be easily undone!',
      () async {
        setState(() {
          _isLoading = true;
          _output = '⚠️ Running full cleanup...\n\n';
        });

        try {
          final migration = DuplicateBookingMigration();
          await migration.runFullCleanup();
          _log('\n✅ Full cleanup completed.');
        } catch (e) {
          _log('\n❌ Error: $e');
        } finally {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migration & QA Tools'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Migration & QA Panel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _runDryRun,
                      icon: const Icon(Icons.search),
                      label: const Text('1. Dry-Run\nAnalysis'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _runQATests,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('2. Run QA\nTests'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _runFullCleanup,
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('3. Full\nCleanup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        disabledBackgroundColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '⚠️ Always run Dry-Run first before Full Cleanup',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
          // Output Console
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.grey[700]!, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      child: Text(
                        _output.isEmpty ? 'Output will appear here...' : _output,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Courier',
                          fontSize: 12,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

/// Usage:
/// Add to admin dashboard:
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const AdminMigrationScreen()),
/// );
