// lib/widgets/admin/queue_card.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/models/user_data.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Theme colors
const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkSurface = Color(0xFF1E1E1E);
const Color kBlack = Colors.black;
const Color kGreenAccent = Color(0xFF4CAF50);

class QueueCard extends StatefulWidget {
  final Queue queue;
  final FutureOr<void> Function()? onStartService;
  final FutureOr<void> Function()? onFinishService;
  final FutureOr<void> Function()? onCancelQueue;
  /// optional confirm callback (useful for "waiting" -> "booked")
  final FutureOr<void> Function()? onConfirmBooking;

  const QueueCard({
    super.key,
    required this.queue,
    this.onStartService,
    this.onFinishService,
    this.onCancelQueue,
    this.onConfirmBooking,
  });

  @override
  State<QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<QueueCard> {
  final AuthService _authService = AuthService();
  final BarbershopService _barbershopService = BarbershopService();
  final QueueService _queueService = QueueService();

  late Future<UserData?> _customerFuture;
  late Future<Barberman?> _barbermanFuture;

  bool _processingStart = false;
  bool _processingFinish = false;
  bool _processingCancel = false;
  bool _processingConfirm = false;
  bool _processingRefund = false;

  @override
  void initState() {
    super.initState();
    _initFutures();
  }

  @override
  void didUpdateWidget(covariant QueueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queue.id != widget.queue.id) {
      _initFutures();
    }
  }

  void _initFutures() {
    _customerFuture = _authService.getUserById(widget.queue.customerId);
    _barbermanFuture = _getBarbermanSafe(widget.queue.barbermanId);
  }

  // wrapper to avoid throwing if barbermanId empty
  Future<Barberman?> _getBarbermanSafe(String id) {
    if (id.isEmpty) return Future.value(null);
    return _barbershopService.getBarbermanById(id);
  }

  String _formatBookingTime(Timestamp ts) {
    try {
      return DateFormat('HH:mm', 'id_ID').format(ts.toDate());
    } catch (_) {
      return '-:-';
    }
  }

  String _statusToLabel(QueueStatus s) {
    switch (s) {
      case QueueStatus.waiting:
        return 'Menunggu Konfirmasi';
      case QueueStatus.booked:
        return 'Terkonfirmasi';
      case QueueStatus.ongoing:
        return 'Sedang Dicukur';
      case QueueStatus.served:
        return 'Selesai';
      case QueueStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  Color _statusToColor(QueueStatus s) {
    switch (s) {
      case QueueStatus.waiting:
        return Colors.orangeAccent;
      case QueueStatus.booked:
        return Colors.blueAccent;
      case QueueStatus.ongoing:
        return kGreenAccent;
      case QueueStatus.served:
        return Colors.grey;
      case QueueStatus.cancelled:
        return Colors.redAccent;
    }
  }

  Future<void> _callCallbackSafely(FutureOr<void> Function()? cb) async {
    if (cb == null) return;
    final res = cb();
    if (res is Future) await res;
  }

  Future<void> _handleStart() async {
    setState(() => _processingStart = true);
    try {
      await _callCallbackSafely(widget.onStartService);
      _showSnack('Layanan dimulai');
    } catch (e) {
      _showSnack('Gagal memulai layanan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processingStart = false);
    }
  }

  Future<void> _handleConfirm() async {
    if (widget.onConfirmBooking == null) {
      // If confirm callback is not provided we should NOT auto-start the service.
      // Instead show a warning so developer knows to wire the callback.
      _showSnack('Aksi konfirmasi belum dihubungkan (onConfirmBooking null)', isError: true);
      return;
    }

    setState(() => _processingConfirm = true);
    try {
      await _callCallbackSafely(widget.onConfirmBooking);
      _showSnack('Booking dikonfirmasi');
    } catch (e) {
      _showSnack('Gagal konfirmasi booking: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processingConfirm = false);
    }
  }

  Future<void> _handleFinish() async {
    final confirmed = await _showConfirmDialog(
      'Selesaikan Layanan',
      'Tandai antrean ini sebagai selesai?',
  const Color(0xFF4CAF50),
    );
    if (!confirmed) return;

    setState(() => _processingFinish = true);
    try {
      await _callCallbackSafely(widget.onFinishService);
      _showSnack('Layanan selesai');
    } catch (e) {
      _showSnack('Gagal menyelesaikan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processingFinish = false);
    }
  }

  Future<void> _handleCancel() async {
    final confirmed = await _showConfirmDialog(
      'Batalkan Antrean',
      'Yakin ingin membatalkan antrean ini?',
  const Color(0xFFD32F2F),
    );
    if (!confirmed) return;

    setState(() => _processingCancel = true);
    try {
      await _callCallbackSafely(widget.onCancelQueue);
      _showSnack('Antrean dibatalkan');
    } catch (e) {
      _showSnack('Gagal membatalkan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processingCancel = false);
    }
  }

  Future<void> _handleRefund() async {
    // Show dialog for refund reason
    String reason = 'Dibatalkan oleh admin';
    bool shouldRefund = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        TextEditingController reasonCtrl = TextEditingController(text: reason);
        return AlertDialog(
          backgroundColor: kDarkSurface,
          title: const Text('Proses Refund', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: reasonCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Alasan pembatalan/refund',
              hintStyle: const TextStyle(color: Colors.white54),
              fillColor: Colors.black26,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Batal', style: TextStyle(color: kBrownAccent)),
            ),
            ElevatedButton(
              onPressed: () {
                reason = reasonCtrl.text.trim();
                shouldRefund = true;
                Navigator.pop(dialogCtx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Proses Refund', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );

    if (!shouldRefund) return;

    setState(() => _processingRefund = true);
    try {
      // Call refund service directly
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      await _queueService.adminRefundBooking(
        widget.queue.id,
        reason: reason,
        adminUid: adminUid,
      );
      _showSnack('Refund diproses');
    } catch (e) {
      _showSnack('Gagal proses refund: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processingRefund = false);
    }
  }

  Future<bool> _showConfirmDialog(String title, String msg, Color color) async {
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: kDarkSurface,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Text(msg, style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                style: ElevatedButton.styleFrom(backgroundColor: color),
                child: const Text('Ya', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
  backgroundColor: isError ? const Color(0xFFD32F2F) : kBrownAccent,
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _buildServiceList() {
    final ids = widget.queue.serviceIds ?? (widget.queue.serviceId != null ? [widget.queue.serviceId!] : []);
    if (ids.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.white70));
    }
    return Text(ids.join(', '), style: const TextStyle(color: Colors.white70));
  }

  Widget? _buildPaymentProof() {
    final base64 = widget.queue.paymentProofBase64;
    if (base64 == null || base64.isEmpty) return null;

    try {
      final Uint8List bytes = base64Decode(base64);
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Center(child: InteractiveViewer(child: Image.memory(bytes))),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: Container(
          width: 90,
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          clipBehavior: Clip.hardEdge,
          child: Image.memory(bytes, fit: BoxFit.cover),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = widget.queue;
    final QueueStatus status = queue.status;
    final bool isWaitingOrBooked = status == QueueStatus.waiting || status == QueueStatus.booked;
    final bool isOngoing = status == QueueStatus.ongoing;
    final Color borderColor = _statusToColor(status);

    final paymentWidget = _buildPaymentProof();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // HEADER
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Waktu Booking:", style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(_formatBookingTime(queue.bookingTime), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            Chip(
              label: Text(
                _statusToLabel(status).toUpperCase(),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
              ),
              backgroundColor: borderColor,
            ),
          ]),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12),
          const SizedBox(height: 6),

          // CUSTOMER
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.person, color: kBrownAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: FutureBuilder<UserData?>(
                future: _customerFuture,
                builder: (c, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Text('Memuat...', style: TextStyle(color: Colors.white70));
                  }
                  final name = snap.data?.name ?? queue.customerId;
                  final phone = snap.data?.phoneNumber ?? '-';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(phone, style: const TextStyle(color: Colors.white70)),
                    ],
                  );
                },
              ),
            ),
            if (paymentWidget != null) paymentWidget,
          ]),
          const SizedBox(height: 12),

          // BARBERMAN
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.content_cut, color: kBrownAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: FutureBuilder<Barberman?>(
                future: _barbermanFuture,
                builder: (c, snap) {
                  final name = snap.data?.name ?? queue.barbermanId;
                  final dur = queue.estimatedDuration ?? (snap.data?.avgDuration ?? 30);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      Text('~ ${dur.toInt()} menit', style: const TextStyle(color: Colors.white70)),
                    ],
                  );
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // LAYANAN & HARGA
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Layanan', style: TextStyle(color: Colors.white54, fontSize: 12)),
                _buildServiceList(),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Total', style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(
                queue.totalPrice != null ? 'Rp ${queue.totalPrice}' : '-',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ]),
          ]),
          const SizedBox(height: 14),

          // ACTION BUTTONS
          if (isWaitingOrBooked || isOngoing)
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _processingCancel ? null : _handleCancel,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    foregroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _processingCancel
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD32F2F)))
                      : const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Builder(builder: (ctx) {
                  // Waiting: show Confirm (requires onConfirmBooking to be provided)
                  if (status == QueueStatus.waiting) {
                    return ElevatedButton.icon(
                      onPressed: (_processingConfirm ? null : _handleConfirm),
                      icon: _processingConfirm
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.check, size: 16),
                      label: const Text('Konfirmasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrownAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  }

                  // Booked: start service
                  if (status == QueueStatus.booked) {
                    return ElevatedButton.icon(
                      onPressed: (_processingStart ? null : _handleStart),
                      icon: _processingStart
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Mulai Potong'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreenAccent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  }

                  // Ongoing: finish
                  return ElevatedButton.icon(
                    onPressed: (_processingFinish ? null : _handleFinish),
                    icon: _processingFinish
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Selesai Potong'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBrownAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                }),
              ),
            ]),
          
          // REFUND ACTION BUTTON - Show for cancelled bookings that haven't been refunded yet
          if (status == QueueStatus.cancelled && (queue.isRefunded != true))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processingRefund ? null : _handleRefund,
                  icon: _processingRefund
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.money_off, size: 16),
                  label: const Text('Proses Refund'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
