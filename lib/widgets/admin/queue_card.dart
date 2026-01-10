// lib/widgets/admin/queue_card.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/widgets/app_image.dart';

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

  const QueueCard({
    super.key, 
    required this.queue, 
    this.onStartService, 
    this.onFinishService, 
    this.onCancelQueue, 
    this.onConfirmBooking
  });

  @override
  State<QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<QueueCard> {
  final AuthService _authService = AuthService();
  final BarbershopService _barbershopService = BarbershopService();
  String _customerName = 'Loading...'; 
  String _barberName = 'Loading...'; 
  String? _customerPhoto;
  List<String> _serviceNames = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void didUpdateWidget(QueueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queue.id != widget.queue.id) {
      _loadDetails();
    }
  }

  Future<void> _loadDetails() async {
    // 1. Load Customer Info
    if (widget.queue.customerName != null && widget.queue.customerName!.isNotEmpty) {
      if (mounted) setState(() => _customerName = widget.queue.customerName!);
    } else { 
      final user = await _authService.getUserById(widget.queue.customerId); 
      if (mounted) {
        setState(() {
          _customerName = user?.name ?? 'Pelanggan';
          _customerPhoto = user?.photoBase64;
        });
      }
    }

    // 2. Load Barber Info
    final barber = await _barbershopService.getBarbermanById(widget.queue.barbermanId); 
    if (mounted) {
      setState(() => _barberName = barber?.name ?? 'Barber Unknown');
    }

    // 3. Load Service Names
    if (widget.queue.serviceIds != null && widget.queue.serviceIds!.isNotEmpty) {
      final services = await _barbershopService.getServicesByIds(widget.queue.serviceIds!);
      if (mounted) {
        setState(() => _serviceNames = services.map((s) => s.name).toList());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.queue;
    final now = DateTime.now();
    final bTime = q.bookingTime.toDate();
    final isToday = bTime.year == now.year && bTime.month == now.month && bTime.day == now.day;
    final diff = bTime.difference(now).inMinutes;
    
    BoxBorder? border;
    if (q.status == QueueStatus.booked && isToday) {
      if (diff < -10) {
        border = Border.all(color: kRedAlert.withValues(alpha: 0.5), width: 1.5);
      } else if (diff <= 15) {
        border = Border.all(color: kYellowWarning.withValues(alpha: 0.5), width: 1.5);
      }
    }

    final Color statusColor = _getStatusColor(q.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16), 
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: kDarkSurface, 
        borderRadius: BorderRadius.circular(20), 
        border: border,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          // Top Header: ID & Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                child: Text('#${q.id.substring(0, 6).toUpperCase()}', style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
              ),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Text(DateFormat('HH:mm').format(bTime), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                ],
              ),
            ]
          ),
          const SizedBox(height: 16),
          
          // Middle: Customer & Status
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kBrownAccent.withValues(alpha: 0.1),
                ),
                child: ClipOval(
                  child: AppImage(
                    imageUrl: _customerPhoto, 
                    width: 50, height: 50,
                    fit: BoxFit.cover,
                    errorWidget: const Icon(Icons.person, color: kBrownAccent, size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_customerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: statusColor.withValues(alpha: 0.3))), 
                      child: Text(q.status.value.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5))
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // Services List
          if (_serviceNames.isNotEmpty) ...[
            const Text('LAYANAN:', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _serviceNames.map((name) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
                child: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Barber Info
          Row(
            children: [
              const Icon(Icons.content_cut, color: Colors.white38, size: 16),
              const SizedBox(width: 8),
              const Text('Barber:', style: TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(width: 6),
              Text(_barberName, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),

          const SizedBox(height: 20),

          // Actions
          if (q.status != QueueStatus.served && q.status != QueueStatus.cancelled) 
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildAction(q, isToday)
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => _confirmCancel(), 
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kRedAlert, 
                      side: BorderSide(color: kRedAlert.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14)
                    ), 
                    child: const Text('BATAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
                  ),
                ),
              ]
            )
        ]
      ),
    );
  }

  Color _getStatusColor(QueueStatus status) {
    switch (status) {
      case QueueStatus.ongoing: return kGreenSuccess;
      case QueueStatus.booked: return Colors.blue;
      case QueueStatus.waiting: return Colors.amber;
      case QueueStatus.cancelled: return kRedAlert;
      case QueueStatus.served: return Colors.grey;
      default: return Colors.white54;
    }
  }

  void _confirmCancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDarkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Batalkan Antrean?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Tindakan ini tidak dapat dibatalkan. Pelanggan akan menerima notifikasi pembatalan.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('TUTUP', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (mounted) setState(() => _isProcessing = true);
              await widget.onCancelQueue?.call();
              if (mounted) setState(() => _isProcessing = false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: kRedAlert),
            child: const Text('BATALKAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(Queue q, bool isToday) {
    onTap(FutureOr<void> Function()? f) async { 
      if (f == null || _isProcessing) return; 
      if (mounted) setState(() => _isProcessing = true); 
      await f(); 
      if (mounted) setState(() => _isProcessing = false); 
    }
    
    if (q.status == QueueStatus.waiting) {
      return ElevatedButton.icon(
        onPressed: () => onTap(widget.onConfirmBooking), 
        icon: const Icon(Icons.check_circle_outline, size: 18),
        label: const Text('KONFIRMASI', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kBrownAccent, 
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14)
        ),
      );
    }
    
    if (q.status == QueueStatus.booked) {
      return ElevatedButton.icon(
        onPressed: isToday ? () => onTap(widget.onStartService) : null, 
        icon: Icon(isToday ? Icons.play_arrow_rounded : Icons.calendar_today, size: 18),
        label: Text(isToday ? 'MULAI SEKARANG' : 'HARI LAIN', style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreenSuccess, 
          foregroundColor: Colors.white, 
          disabledBackgroundColor: Colors.white10,
          disabledForegroundColor: Colors.white24,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14)
        ),
      );
    }
    
    if (q.status == QueueStatus.ongoing) {
      return ElevatedButton.icon(
        onPressed: () => onTap(widget.onFinishService), 
        icon: const Icon(Icons.done_all_rounded, size: 18),
        label: const Text('SELESAI LAYANAN', style: TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kBrownAccent, 
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14)
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
