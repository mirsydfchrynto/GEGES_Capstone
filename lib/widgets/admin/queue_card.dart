// lib/widgets/admin/queue_card.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkSurface = Color(0xFF1E1E1E);
const Color kRedAlert = Color(0xFFFF3B30);
const Color kYellowWarning = Color(0xFFFFCC00);
const Color kGreenSuccess = Color(0xFF4CAF50);

class QueueCard extends StatefulWidget {
  final Queue queue;
  final FutureOr<void> Function()? onStartService;
  final FutureOr<void> Function()? onFinishService;
  final FutureOr<void> Function()? onCancelQueue;
  final FutureOr<void> Function()? onConfirmBooking;
  const QueueCard({super.key, required this.queue, this.onStartService, this.onFinishService, this.onCancelQueue, this.onConfirmBooking});
  @override State<QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<QueueCard> {
  final AuthService _authService = AuthService();
  final BarbershopService _barbershopService = BarbershopService();
  String _customerName = 'Loading...'; String _barberName = 'Loading...'; bool _isProcessing = false;

  @override void initState() { super.initState(); _loadDetails(); }
  @override void didUpdateWidget(QueueCard old) { super.didUpdateWidget(old); if (old.queue.id != widget.queue.id) _loadDetails(); }

  Future<void> _loadDetails() async {
    if (widget.queue.customerName != null && widget.queue.customerName!.isNotEmpty) setState(() => _customerName = widget.queue.customerName!);
    else { final user = await _authService.getUserById(widget.queue.customerId); if (mounted) setState(() => _customerName = user?.name ?? 'Pelanggan'); }
    final barber = await _barbershopService.getBarbermanById(widget.queue.barbermanId); if (mounted) setState(() => _barberName = barber?.name ?? 'Barber Unknown');
  }

  @override Widget build(BuildContext context) {
    final q = widget.queue;
    final now = DateTime.now();
    final bTime = q.bookingTime.toDate();
    final isToday = bTime.year == now.year && bTime.month == now.month && bTime.day == now.day;
    final diff = bTime.difference(now).inMinutes;
    
    BoxBorder? border;
    if (q.status == QueueStatus.booked && isToday) {
      if (diff < -10) border = Border.all(color: kRedAlert, width: 2);
      else if (diff <= 15) border = Border.all(color: kYellowWarning, width: 2);
    }

    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kDarkSurface, borderRadius: BorderRadius.circular(16), border: border), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Text('#${q.id.substring(0, 6).toUpperCase()}', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: (q.status == QueueStatus.ongoing ? kGreenSuccess : Colors.blue).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)), child: Text(q.status.value.toUpperCase(), style: TextStyle(color: q.status == QueueStatus.ongoing ? kGreenSuccess : Colors.blue, fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        Text(DateFormat('HH:mm').format(bTime), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),
      Text(_customerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      Text('Barber: $_barberName', style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 16),
      if (q.status != QueueStatus.served && q.status != QueueStatus.cancelled) Row(children: [
        Expanded(child: OutlinedButton(onPressed: _isProcessing ? null : () async { setState(() => _isProcessing = true); await widget.onCancelQueue?.call(); if (mounted) setState(() => _isProcessing = false); }, style: OutlinedButton.styleFrom(foregroundColor: kRedAlert, side: const BorderSide(color: kRedAlert)), child: const Text('BATAL'))),
        const SizedBox(width: 12),
        Expanded(child: _buildAction(q, isToday)),
      ])
    ]));
  }

  Widget _buildAction(Queue q, bool isToday) {
    onTap(FutureOr<void> Function()? f) async { if (f == null || _isProcessing) return; setState(() => _isProcessing = true); await f(); if (mounted) setState(() => _isProcessing = false); }
    if (q.status == QueueStatus.waiting) return ElevatedButton(onPressed: () => onTap(widget.onConfirmBooking), style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black), child: const Text('KONFIRMASI'));
    if (q.status == QueueStatus.booked) return ElevatedButton(onPressed: isToday ? () => onTap(widget.onStartService) : null, style: ElevatedButton.styleFrom(backgroundColor: kGreenSuccess, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey[800]), child: Text(isToday ? 'MULAI' : 'HARI LAIN'));
    if (q.status == QueueStatus.ongoing) return ElevatedButton(onPressed: () => onTap(widget.onFinishService), style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black), child: const Text('SELESAI'));
    return const SizedBox.shrink();
  }
}