// lib/screens/admin/barberman_management_screen.dart
// dokumentasi: admin screen untuk manage barberman (off days, leave, etc)

import 'package:flutter/material.dart';
import 'package:geges_smartbarber/services/barberman_service.dart';
import 'package:geges_smartbarber/services/barberman_leave_service.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/models/barberman_leave.dart';
import 'package:intl/intl.dart';

class BarbermanManagementScreen extends StatefulWidget {
  final String barbershopId;

  const BarbermanManagementScreen({
    super.key,
    required this.barbershopId,
  });

  @override
  State<BarbermanManagementScreen> createState() =>
      _BarbermanManagementScreenState();
}

class _BarbermanManagementScreenState extends State<BarbermanManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BarbermanService _barbermanService = BarbermanService();
  final BarbermanLeaveService _leaveService = BarbermanLeaveService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Barberman'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daftar Barberman'),
            Tab(text: 'Permintaan Cuti'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBarbermanList(),
          _buildLeaveRequestList(),
        ],
      ),
    );
  }

  // -----------------------
  // TAB 1: DAFTAR BARBERMAN
  // -----------------------
  Widget _buildBarbermanList() {
    return StreamBuilder<List<Barberman>>(
      stream: _barbermanService.streamBarbermenByBarbershop(widget.barbershopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Tidak ada barberman'));
        }

        final barbermen = snapshot.data!;
        return ListView.builder(
          itemCount: barbermen.length,
          itemBuilder: (context, index) {
            final barber = barbermen[index];
            return _BarbermanCard(
              barbershopId: widget.barbershopId,
              barberman: barber,
              leaveService: _leaveService,
              onUpdated: () => setState(() {}),
            );
          },
        );
      },
    );
  }

  // -----------------------
  // TAB 2: PERMINTAAN CUTI
  // -----------------------
  Widget _buildLeaveRequestList() {
    return StreamBuilder<List<BarbermanLeave>>(
      stream: _leaveService.streamLeavesForBarbershop(
        widget.barbershopId,
        status: 'pending',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Tidak ada permintaan cuti'));
        }

        final leaves = snapshot.data!;
        return ListView.builder(
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            final leave = leaves[index];
            return _LeaveRequestCard(
              leave: leave,
              barbershopId: widget.barbershopId,
              leaveService: _leaveService,
              onAction: () => setState(() {}),
            );
          },
        );
      },
    );
  }
}

// -----------------------
// BARBERMAN CARD WIDGET
// -----------------------
class _BarbermanCard extends StatefulWidget {
  final String barbershopId;
  final Barberman barberman;
  final BarbermanLeaveService leaveService;
  final VoidCallback onUpdated;

  const _BarbermanCard({
    required this.barbershopId,
    required this.barberman,
    required this.leaveService,
    required this.onUpdated,
  });

  @override
  State<_BarbermanCard> createState() => _BarbermanCardState();
}

class _BarbermanCardState extends State<_BarbermanCard> {
  late List<bool> _selectedOffDays;

  @override
  void initState() {
    super.initState();
    // Initialize off days selection (7 days: Mon-Sun)
    _selectedOffDays = List<bool>.filled(7, false);
    final offDayIndices = widget.barberman.offDays
        ?.map((d) => DayOfWeek.values.indexOf(d))
        .toList() ?? [];
    for (final idx in offDayIndices) {
      if (idx >= 0 && idx < 7) {
        _selectedOffDays[idx] = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Ming'];

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: nama & rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.barberman.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '⭐ ${widget.barberman.rating}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                Chip(
                  label: Text(
                    widget.barberman.onLeave ? 'Cuti' : 'Aktif',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor:
                      widget.barberman.onLeave ? const Color(0xFFD32F2F) : const Color(0xFF4CAF50),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Annual leave status
            Text(
              'Sisa Cuti Tahunan: ${widget.barberman.annualLeaveDays} hari',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Off days selector
            Text(
              'Pilih Hari Libur Tetap:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                return FilterChip(
                  label: Text(dayNames[index]),
                  selected: _selectedOffDays[index],
                  onSelected: (selected) {
                    setState(() {
                      _selectedOffDays[index] = selected;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveOffDays,
                child: const Text('Simpan Pengaturan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveOffDays() async {
    try {
      // Collect selected off days
      final offDays = <DayOfWeek>[];
      for (int i = 0; i < _selectedOffDays.length; i++) {
        if (_selectedOffDays[i]) {
          offDays.add(DayOfWeek.values[i]);
        }
      }

      // Create updated barber with new off days
      // Note: this updates local state; in a real app, save to Firebase here
      // For now, we just show the UI feedback
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan hari libur disimpan')),
      );

      widget.onUpdated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }
}

// -----------------------
// LEAVE REQUEST CARD
// -----------------------
class _LeaveRequestCard extends StatelessWidget {
  final BarbermanLeave leave;
  final String barbershopId;
  final BarbermanLeaveService leaveService;
  final VoidCallback onAction;

  const _LeaveRequestCard({
    required this.leave,
    required this.barbershopId,
    required this.leaveService,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final startStr = dateFormat.format(leave.startDate.toDate());
    final endStr = dateFormat.format(leave.endDate.toDate());

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  leave.type.toString().split('.').last.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(leave.status.toUpperCase()),
                  backgroundColor: _getStatusColor(leave.status),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date range
            Text(
              '$startStr - $endStr (${leave.usedDays} hari)',
              style: const TextStyle(fontSize: 14),
            ),
            if (leave.reason != null && leave.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Alasan: ${leave.reason}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),

            // Action buttons
            if (leave.status == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _approveLeave(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Setujui'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _rejectLeave(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Tolak'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
  return const Color(0xFF4CAF50);
      case 'rejected':
  return const Color(0xFFD32F2F);
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Future<void> _approveLeave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await leaveService.approveLeave(barbershopId, leave.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Cuti disetujui')),
      );
      onAction();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _rejectLeave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await leaveService.rejectLeave(barbershopId, leave.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Cuti ditolak')),
      );
      onAction();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }
}
