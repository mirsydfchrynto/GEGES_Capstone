// lib/screens/admin/live_queue_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/widgets/admin/queue_card.dart';
import 'package:geges_smartbarber/widgets/utility/loading_widget.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
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
  Timer? _timer;

  @override void initState() {
    super.initState();
    _currentStatusFilter = List.from(widget.initialFilter);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) { setState(() {}); _queueService.cancelExpiredBookings(widget.barbershopId); }
    });
  }

  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _startService(Queue q) async { try { await _queueService.startService(q.id); } catch (_) {} }
  Future<void> _finishService(Queue q) async { try { await _queueService.finishService(q.id, q.startTime); } catch (_) {} }
  Future<void> _cancelQueue(Queue q) async { try { await _queueService.cancelQueue(q.id); } catch (_) {} }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlack,
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: kBrownAccent, iconTheme: const IconThemeData(color: Colors.black), elevation: 0),
      body: SafeArea(child: StreamBuilder<List<Queue>>(
        stream: _queueService.streamQueuesForBarbershop(widget.barbershopId, statusFilter: _currentStatusFilter),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          if (snapshot.connectionState == ConnectionState.waiting) return const LoadingWidget();
          final list = snapshot.data ?? [];
          if (list.isEmpty) return const Center(child: Text('Tidak ada antrean saat ini', style: TextStyle(color: Colors.white54)));
          list.sort((a, b) {
            if (a.status == QueueStatus.ongoing && b.status != QueueStatus.ongoing) return -1;
            if (b.status == QueueStatus.ongoing && a.status != QueueStatus.ongoing) return 1;
            return a.bookingTime.toDate().compareTo(b.bookingTime.toDate());
          });
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (context, i) => QueueCard(queue: list[i], onStartService: () => _startService(list[i]), onFinishService: () => _finishService(list[i]), onCancelQueue: () => _cancelQueue(list[i])));
        },
      )),
    );
  }
}