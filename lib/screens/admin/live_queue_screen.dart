// lib/screens/admin/live_queue_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/widgets/admin/queue_card.dart';
import 'package:geges_smartbarber/widgets/utility/loading_widget.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkSurface = Color(0xFF1E1E1E);
const Color kBlack = Colors.black;

class LiveQueueScreen extends StatefulWidget {
  final String barbershopId;
  final List<String> initialFilter;
  final String title;
  const LiveQueueScreen({super.key, required this.barbershopId, required this.initialFilter, this.title = 'Antrean Live'});
  @override State<LiveQueueScreen> createState() => _LiveQueueScreenState();
}

class _LiveQueueScreenState extends State<LiveQueueScreen> {
  final QueueService _queueService = QueueService();
  late List<String> _currentStatusFilter;
  String _activeFilterLabel = 'Live';
  Timer? _timer;

  @override void initState() {
    super.initState();
    _currentStatusFilter = List.from(widget.initialFilter);
    if (_currentStatusFilter.contains('booked')) _activeFilterLabel = 'Live';
    
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) { setState(() {}); _queueService.cancelExpiredBookings(widget.barbershopId); }
    });
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _startService(Queue q) async { try { await _queueService.startService(q.id); } catch (_) {} }
  Future<void> _finishService(Queue q) async { try { await _queueService.finishService(q.id, q.startTime); } catch (_) {} }
  Future<void> _cancelQueue(Queue q) async { try { await _queueService.cancelQueue(q.id); } catch (_) {} }

  void _updateFilter(String label, List<String> statuses) {
    setState(() {
      _activeFilterLabel = label;
      _currentStatusFilter = statuses;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlack,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)), 
        backgroundColor: kBlack, 
        iconTheme: const IconThemeData(color: Colors.white), 
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildFilterBar(),
        ),
      ),
      body: SafeArea(child: StreamBuilder<List<Queue>>(
        stream: _queueService.streamQueuesForBarbershop(
          widget.barbershopId, 
          statusFilter: _currentStatusFilter.isEmpty ? null : _currentStatusFilter
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting) return const LoadingWidget();
          
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 16),
                  Text('Tidak ada data ${_activeFilterLabel.toLowerCase()}', style: const TextStyle(color: Colors.white24, fontSize: 16)),
                ],
              ),
            );
          }

          // Sort: Ongoing first, then by time
          list.sort((a, b) {
            if (a.status == QueueStatus.ongoing && b.status != QueueStatus.ongoing) return -1;
            if (b.status == QueueStatus.ongoing && a.status != QueueStatus.ongoing) return 1;
            return a.bookingTime.toDate().compareTo(b.bookingTime.toDate());
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16), 
            itemCount: list.length, 
            itemBuilder: (context, i) => QueueCard(
              queue: list[i], 
              onStartService: () => _startService(list[i]), 
              onFinishService: () => _finishService(list[i]), 
              onCancelQueue: () => _cancelQueue(list[i])
            )
          );
        },
      )),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filterChip('Live', ['booked', 'ongoing']),
          _filterChip('Pending', ['waiting', 'awaiting_payment', 'cancellation_requested']),
          _filterChip('Selesai', ['served']),
          _filterChip('Batal', ['cancelled']),
          _filterChip('Semua', []),
        ],
      ),
    );
  }

  Widget _filterChip(String label, List<String> statuses) {
    final bool isSelected = _activeFilterLabel == label;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
        selected: isSelected,
        onSelected: (val) { if (val) _updateFilter(label, statuses); },
        selectedColor: kBrownAccent,
        backgroundColor: kDarkSurface,
        side: BorderSide(color: isSelected ? kBrownAccent : Colors.white.withValues(alpha: 0.05)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),
    );
  }
}