// lib/screens/admin/live_queue_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/widgets/admin/queue_card.dart';
import 'package:geges_smartbarber/widgets/utility/loading_widget.dart';

// --- THEME COLORS ---
const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkSurface = Color(0xFF1E1E1E);
const Color kBlack = Colors.black;

class LiveQueueScreen extends StatefulWidget {
  final String barbershopId;
  final List<String> initialFilter;
  final String title;

  const LiveQueueScreen({
    super.key,
    required this.barbershopId,
    required this.initialFilter,
    this.title = 'Antrean Live',
  });

  @override
  State<LiveQueueScreen> createState() => _LiveQueueScreenState();
}

class _LiveQueueScreenState extends State<LiveQueueScreen> {
  final QueueService _queueService = QueueService();

  late List<String> _currentStatusFilter;

  @override
  void initState() {
    super.initState();
    // Default to showing confirmed bookings (booked) and ongoing services for Live Queue.
    _currentStatusFilter = (widget.initialFilter.isNotEmpty)
        ? List.from(widget.initialFilter)
        : ['booked', 'ongoing'];
  }

  Future<void> _startService(Queue queue) async {
    try {
      await _queueService.startService(queue.id);
      _showSnackBar('Layanan untuk antrean #${queue.id.substring(0, 6)} dimulai', isError: false);
    } catch (e) {
      _showSnackBar('Gagal memulai layanan: $e', isError: true);
    }
  }

  Future<void> _finishService(Queue queue) async {
    try {
      if (queue.startTime == null) {
        _showSnackBar('Waktu mulai tidak ditemukan!', isError: true);
        return;
      }
      // Jika QueueService.finishService membutuhkan startTime sebagai argumen kedua,
      // pastikan implementasi service yang kamu pakai menerima (queueId, startTime).
      // Di beberapa versi ada yang hanya butuh queueId — sesuaikan jika perlu.
      await _queueService.finishService(queue.id, queue.startTime!);
      _showSnackBar('Layanan selesai untuk #${queue.id.substring(0, 6)}', isError: false);
    } catch (e) {
      _showSnackBar('Gagal menyelesaikan layanan: $e', isError: true);
    }
  }

  Future<void> _cancelQueue(Queue queue) async {
    try {
      await _queueService.cancelQueue(queue.id, reason: 'Dibatalkan oleh Admin');
      _showSnackBar('Antrean dibatalkan (#${queue.id.substring(0, 6)})', isError: true);
    } catch (e) {
      _showSnackBar('Gagal membatalkan: $e', isError: true);
    }
  }

  Future<void> _confirmBooking(Queue queue) async {
    try {
      await _queueService.manualConfirmBooking(queue.id);
      _showSnackBar('Booking dikonfirmasi — status BOOKED', isError: false);
    } catch (e) {
      _showSnackBar('Gagal konfirmasi booking: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : kBrownAccent,
      duration: const Duration(seconds: 2),
    ));
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'waiting':
        return 'Menunggu Konfirmasi';
      case 'booked':
        return 'Terkonfirmasi (Antrean)';
      case 'ongoing':
        return 'Sedang Berlangsung';
      case 'served':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  List<Queue> _filterAndSortQueues(List<Queue> queues) {
    final filtered = queues.where((q) => _currentStatusFilter.contains(q.status.value)).toList();

    filtered.sort((a, b) {
      int priority(String s) {
        if (s == 'ongoing') return 1;
        if (s == 'booked' || s == 'waiting') return 2;
        if (s == 'served') return 3;
        return 4; // cancelled or others
      }

      final pa = priority(a.status.value);
      final pb = priority(b.status.value);
      if (pa != pb) return pa.compareTo(pb);

      // bandingkan booking time
      return a.bookingTime.toDate().compareTo(b.bookingTime.toDate());
    });

    return filtered;
  }

  void _showFilterModal() {
    final allStatuses = ['waiting', 'booked', 'ongoing', 'served', 'cancelled'];
    List<String> tmp = List.from(_currentStatusFilter);

    showModalBottomSheet(
      context: context,
      backgroundColor: kDarkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 12),
                const Text('Filter Status Antrean', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...allStatuses.map((s) {
                  return CheckboxListTile(
                    value: tmp.contains(s),
                    title: Text(_getStatusDisplayName(s), style: const TextStyle(color: Colors.white)),
                    onChanged: (v) {
                      setModal(() {
                        if (v == true) {
                          tmp.add(s);
                        } else {
                          tmp.remove(s);
                        }
                      });
                    },
                    activeColor: kBrownAccent,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _currentStatusFilter = ['booked', 'ongoing']);
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(side: BorderSide(color: kBrownAccent)),
                        child: const Text('Default', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (tmp.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih minimal 1 status'), backgroundColor: Colors.redAccent));
                            return;
                          }
                          setState(() => _currentStatusFilter = List.from(tmp));
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent),
                        child: const Text('Terapkan', style: TextStyle(color: Colors.black)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _queue_service_stream();

    return Scaffold(
      backgroundColor: kBlack,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kBrownAccent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list_rounded, color: Colors.black), onPressed: _showFilterModal),
          IconButton(icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.black), onPressed: () => _showSnackBar('Tambah manual belum diaktifkan')),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Queue>>(
          stream: stream,
          initialData: const <Queue>[],
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Error stream data: ${snapshot.error}\nCek Firestore index & rules.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ));
            }

            final allQueues = snapshot.data ?? [];
            // ongoingCount = jumlah ongoing
            final ongoingCount = allQueues.where((q) => q.status.value == 'ongoing').length;
            // waitingCount here is the number of booked (confirmed) items waiting in queue
            final waitingCount = allQueues.where((q) => q.status.value == 'booked').length;

            Widget header = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(27, 94, 32, 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color.fromRGBO(51, 105, 30, 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cut, color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 6),
                      Text('Sedang Dicukur: $ongoingCount', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(195, 164, 123, 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color.fromRGBO(195, 164, 123, 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.access_time_filled, color: kBrownAccent, size: 14),
                      const SizedBox(width: 6),
                      Text('Menunggu: $waitingCount', style: const TextStyle(color: kBrownAccent, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ),
            );

            final filtered = _filterAndSortQueues(allQueues);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Expanded(
                  child: Builder(builder: (context) {
                    if (snapshot.connectionState == ConnectionState.waiting && allQueues.isEmpty) {
                      return const LoadingWidget();
                    }

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined, size: 56, color: const Color.fromRGBO(195, 164, 123, 0.6)),
                              const SizedBox(height: 12),
                              const Text('Tidak ada antrean yang cocok.', style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 6),
                              Text('Filter: ${_currentStatusFilter.map(_getStatusDisplayName).join(', ')}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final q = filtered[idx];

                        // provide onConfirmBooking only for waiting items (so admin confirms payment -> booked)
                        final FutureOr<void> Function()? onConfirm = (q.status.value == 'waiting')
                            ? () => _confirmBooking(q)
                            : null;

                        // provide start/finish/cancel as usual
                        return QueueCard(
                          queue: q,
                          onConfirmBooking: onConfirm,
                          onStartService: () => _startService(q),
                          onFinishService: () => _finishService(q),
                          onCancelQueue: () => _cancelQueue(q),
                        );
                      },
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Helper to build the stream using the current status filter
  Stream<List<Queue>> _queue_service_stream() {
    // ensure we don't pass 'pending' anywhere and use the dynamic filter.
    return _queueService.streamQueuesForBarbershop(
      widget.barbershopId,
      statusFilter: _currentStatusFilter,
    );
  }
}
