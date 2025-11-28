// lib/screens/customer/booking_detail_screen.dart (enhanced with countdown timer)
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment_screen.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;

class BookingDetailScreen extends StatefulWidget {
  final String queueId;
  const BookingDetailScreen({super.key, required this.queueId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final QueueService _queueService = QueueService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Queue? _queue;
  bool _loading = true;
  bool _uploading = false;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isAwaitingPayment {
    if (_queue == null) return false;
    try {
      // Consider awaiting_payment when admin has approved the request and a payment deadline is set
      return _queue!.requestStatus == RequestStatus.approved && _queue!.paymentDeadline != null;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final q = await _queueService.getQueueById(widget.queueId);
    setState(() {
      _queue = q;
      _loading = false;
    });
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    if (_queue?.paymentDeadline == null) return;

    // Calculate initial remaining time
    final now = DateTime.now();
    final deadline = _queue!.paymentDeadline!.toDate();
    final remaining = deadline.difference(now);

    if (remaining.isNegative || remaining.inSeconds == 0) {
      setState(() => _remainingTime = Duration.zero);
      return;
    }

    setState(() => _remainingTime = remaining);

    // Periodically update the timer every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final deadline = _queue!.paymentDeadline!.toDate();
      final remaining = deadline.difference(now);

      if (remaining.isNegative) {
        timer.cancel();
        if (mounted) setState(() => _remainingTime = Duration.zero);
      } else {
        if (mounted) setState(() => _remainingTime = remaining);
      }
    });
  }

  String _formatTimestamp(Timestamp ts) => DateFormat('EEE, d MMM HH:mm').format(ts.toDate());

  String _formatCountdown(Duration duration) {
    if (duration.isNegative) return 'Waktu habis';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getCountdownColor() {
    if (_remainingTime.isNegative) return Colors.red;
    if (_remainingTime.inMinutes < 2) return Colors.red;
    if (_remainingTime.inMinutes < 5) return Colors.orange;
    return Colors.green;
  }

  Future<void> _pickAndUploadProof() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda harus login')));
      }
      return;
    }

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 70);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await File(file.path).readAsBytes();
      final base64Str = base64Encode(bytes);

      await _firestore.collection('queues').doc(widget.queueId).update({
        'payment_proof_base64': base64Str,
        'payment_submitted_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bukti pembayaran berhasil diunggah'), backgroundColor: Colors.green));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengunggah: $e')));
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Booking Detail'),
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kBrownAccent))
          : _queue == null
              ? const Center(child: Text('Booking tidak ditemukan', style: TextStyle(color: Colors.white)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Detail Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${_queue!.status.name.replaceAll('_', ' ')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Waktu: ${_formatTimestamp(_queue!.bookingTime)}', style: const TextStyle(color: kTextGrey)),
                            const SizedBox(height: 8),
                            if (_queue!.estimatedDuration != null) Text('Durasi: ${_queue!.estimatedDuration} menit', style: const TextStyle(color: kTextGrey)),
                            const SizedBox(height: 8),
                            if (_queue!.totalPrice != null) Text('Total: Rp ${_queue!.totalPrice}', style: const TextStyle(color: kBrownAccent)),
                            const SizedBox(height: 12),
                            // Only show payment proof confirmation during awaiting_payment phase
                            if (_isAwaitingPayment && _queue!.paymentProofBase64 != null) ...[
                              const SizedBox(height: 4),
                              const Text('✓ Bukti pembayaran terunggah', style: TextStyle(color: Colors.green)),
                            ],
                            // Show refund information when cancelled & refunded
                            if (_queue!.status.name == 'cancelled' && _queue!.isRefunded == true) ...[
                              const SizedBox(height: 4),
                              const Text('💰 Refund Diproses', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                              if (_queue!.refundReason != null) ...[
                                const SizedBox(height: 4),
                                Text('Alasan: ${_queue!.refundReason}', style: const TextStyle(color: kTextGrey, fontSize: 12)),
                              ],
                              if (_queue!.refundedAt != null) ...[
                                const SizedBox(height: 4),
                                Text('Tanggal refund: ${_formatTimestamp(_queue!.refundedAt!)}', style: const TextStyle(color: kTextGrey, fontSize: 12)),
                              ],
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Countdown Timer (if awaiting_payment)
                      if (_isAwaitingPayment && _queue!.paymentDeadline != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getCountdownColor().withValues(alpha: 0.15),
                            border: Border.all(color: _getCountdownColor(), width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text('SISA WAKTU PEMBAYARAN', style: TextStyle(color: _getCountdownColor(), fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 8),
                              Text(
                                _formatCountdown(_remainingTime),
                                style: TextStyle(color: _getCountdownColor(), fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Batas: ${DateFormat('EEE, d MMM HH:mm').format(_queue!.paymentDeadline!.toDate())}',
                                style: const TextStyle(color: kTextGrey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Upload Button - Only show during awaiting_payment phase
                      if (_isAwaitingPayment)
                        ElevatedButton(
                          onPressed: _uploading ? null : _pickAndUploadProof,
                          style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, minimumSize: const Size.fromHeight(48)),
                          child: _uploading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Unggah Bukti Pembayaran'),
                        ),
                      const SizedBox(height: 8),

                      // Pay Button - Direct navigation to payment screen
                      if (_isAwaitingPayment)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => PaymentScreen(
                                  orderId: _queue!.id,
                                  totalPrice: _queue!.totalPrice ?? 0,
                                  barbershopId: _queue!.barbershopId,
                                  barbermanId: _queue!.barbermanId,
                                  bookingTime: _queue!.bookingTime.toDate(),
                                  serviceIds: _queue!.serviceIds,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('Bayar Sekarang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      const SizedBox(height: 8),

                      // View Proof Button - Only show during awaiting_payment with proof uploaded
                      if (_isAwaitingPayment && _queue!.paymentProofBase64 != null)
                        ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                backgroundColor: kDarkGrey,
                                content: SingleChildScrollView(child: Image.memory(base64Decode(_queue!.paymentProofBase64!))),
                                actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup'))],
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], minimumSize: const Size.fromHeight(44)),
                          child: const Text('Lihat Bukti Pembayaran'),
                        ),
                    ],
                  ),
                ),
    );
  }
}
