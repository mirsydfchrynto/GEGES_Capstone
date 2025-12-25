// lib/screens/customer/booking_detail_screen.dart (enhanced with countdown timer)
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
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
  // BookingDetailScreen uses QueueService to load the queue; no direct firestore instance needed here.
  Queue? _queue;
  bool _loading = true;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  String? _barbershopName;
  String? _barbermanName;
  String? _servicesLabel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isAwaitingPayment {
    if (_queue == null) return false;
    try {
      // Awaiting payment only when admin approved, payment deadline exists
      // AND customer hasn't uploaded payment proof yet.
      return _queue!.requestStatus == RequestStatus.approved &&
          _queue!.paymentDeadline != null &&
          (_queue!.paymentProofBase64 == null ||
              _queue!.paymentProofBase64!.isEmpty);
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
    // Load related names for a richer, more professional detail view
    if (_queue != null) {
      _fetchRelatedNames();
    }
    _startCountdownTimer();
  }

  Future<void> _fetchRelatedNames() async {
    try {
      final fs = FirebaseFirestore.instance;
      final barbershopF = fs
          .collection('barbershops')
          .doc(_queue!.barbershopId)
          .get();
      final barbermanF = fs
          .collection('barbermen')
          .doc(_queue!.barbermanId)
          .get();
      final serviceDocsF = Future.wait(
        (_queue!.serviceIds ?? []).map(
          (id) => fs.collection('services').doc(id).get(),
        ),
      );

      final results = await Future.wait([
        barbershopF,
        barbermanF,
        serviceDocsF,
      ]);

      final barbershopDoc = results[0] as DocumentSnapshot;
      final barbermanDoc = results[1] as DocumentSnapshot;
      final serviceDocs = results[2] as List<DocumentSnapshot>;

      setState(() {
        final bsData = barbershopDoc.data() as Map<String, dynamic>?;
        final bmData = barbermanDoc.data() as Map<String, dynamic>?;
        _barbershopName = bsData?['name'] as String? ?? 'Barbershop';
        _barbermanName = bmData?['name'] as String? ?? 'Barberman';
        final names = serviceDocs
            .where((d) => d.exists)
            .map(
              (d) =>
                  (d.data() as Map<String, dynamic>?)?['name'] as String? ?? '',
            )
            .where((s) => s.isNotEmpty)
            .toList();
        if (names.isEmpty) {
          _servicesLabel = 'Layanan Tidak Tersedia';
        } else if (names.length == 1) {
          _servicesLabel = names[0];
        } else {
          _servicesLabel = '${names[0]} (+${names.length - 1})';
        }
      });
    } catch (_) {
      // ignore; keep defaults
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    // Don't start countdown if there's no deadline or proof already uploaded
    if (_queue?.paymentDeadline == null) return;
    if (_queue?.paymentProofBase64 != null &&
        _queue!.paymentProofBase64!.isNotEmpty) {
      // Proof uploaded: treat as payment action completed — remove countdown
      setState(() => _remainingTime = Duration.zero);
      return;
    }

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

  String _formatTimestamp(Timestamp ts) =>
      DateFormat('EEE, d MMM HH:mm').format(ts.toDate());

  Future<void> _showCancellationDialog(BuildContext context) async {
    final TextEditingController reasonCtrl = TextEditingController();
    final result = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ajukan Pembatalan'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Jelaskan alasan pembatalan (wajib)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.of(c).pop(true);
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );

    if (result == true) {
      final reason = reasonCtrl.text.trim();
      // ignore: use_build_context_synchronously
      final messenger = ScaffoldMessenger.of(this.context);
      try {
        await _queueService.customerRequestCancellation(
          _queue!.id,
          reason: reason,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Permintaan pembatalan terkirim')),
        );
        // reload queue to reflect new status
        await _load();
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal mengirim permintaan: $e')),
        );
      }
    }
  }

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

  // Upload of payment proof is handled exclusively in `PaymentScreen`.
  // BookingDetailScreen will only navigate to PaymentScreen when customer needs to pay.

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
          ? const Center(
              child: Text(
                'Booking tidak ditemukan',
                style: TextStyle(color: Colors.white),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Detail Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kDarkGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status: ${_queue!.status.name.replaceAll('_', ' ')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Waktu: ${_formatTimestamp(_queue!.bookingTime)}',
                          style: const TextStyle(color: kTextGrey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Barbershop: ${_barbershopName ?? _queue!.barbershopId}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Layanan: ${_servicesLabel ?? 'Loading...'}',
                          style: const TextStyle(color: kTextGrey),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Barberman: ${_barbermanName ?? _queue!.barbermanId}',
                          style: const TextStyle(color: kTextGrey),
                        ),
                        const SizedBox(height: 8),
                        if (_queue!.estimatedDuration != null)
                          Text(
                            'Durasi: ${_queue!.estimatedDuration} menit',
                            style: const TextStyle(color: kTextGrey),
                          ),
                        const SizedBox(height: 8),
                        if (_queue!.totalPrice != null)
                          Text(
                            'Total: Rp ${_queue!.totalPrice}',
                            style: const TextStyle(color: kBrownAccent),
                          ),
                        if ((_queue!.barberSelectionFee ?? 0) > 0)
                          const SizedBox(height: 4),
                        if ((_queue!.barberSelectionFee ?? 0) > 0)
                          Text(
                            'Biaya pilih barber: Rp ${_queue!.barberSelectionFee}',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 12),
                        // Show payment proof state if present
                        if (_queue!.paymentProofBase64 != null &&
                            _queue!.paymentProofBase64!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Bukti pembayaran telah terunggah — menunggu verifikasi oleh admin',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              // show full preview dialog
                              try {
                                final bytes = base64Decode(
                                  _queue!.paymentProofBase64!,
                                );
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    backgroundColor: Colors.transparent,
                                    child: InteractiveViewer(
                                      child: Image.memory(bytes),
                                    ),
                                  ),
                                );
                              } catch (_) {}
                            },
                            child: SizedBox(
                              height: 140,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(_queue!.paymentProofBase64!),
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Show cancellation details
                        if (_queue!.status == QueueStatus.cancelled) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              border: Border.all(color: Colors.red, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '❌ Booking Dibatalkan',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (_queue!.rejectionReason != null &&
                                    _queue!.rejectionReason!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Alasan: ${_queue!.rejectionReason}',
                                    style: const TextStyle(
                                      color: kTextGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                if (_queue!.refundReason != null &&
                                    _queue!.refundReason!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Refund: ${_queue!.refundReason}',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        // Show refund information when cancelled & refunded
                        if (_queue!.status == QueueStatus.cancelled &&
                            _queue!.isRefunded == true) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '💰 Refund Diproses',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_queue!.refundedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Tanggal refund: ${_formatTimestamp(_queue!.refundedAt!)}',
                              style: const TextStyle(
                                color: kTextGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Countdown Timer (only while customer still must pay)
                  if (_isAwaitingPayment && _queue!.paymentDeadline != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getCountdownColor().withValues(alpha: 0.15),
                        border: Border.all(
                          color: _getCountdownColor(),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'SISA WAKTU PEMBAYARAN',
                            style: TextStyle(
                              color: _getCountdownColor(),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatCountdown(_remainingTime),
                            style: TextStyle(
                              color: _getCountdownColor(),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Batas: ${DateFormat('EEE, d MMM HH:mm').format(_queue!.paymentDeadline!.toDate())}',
                            style: const TextStyle(
                              color: kTextGrey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Payment / Proof actions (customer)
                  if (_queue!.requestStatus == RequestStatus.approved) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // If no proof yet, allow pay
                        if (_isAwaitingPayment)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                                        bookingTime: _queue!.bookingTime
                                            .toDate(),
                                        serviceIds: _queue!.serviceIds,
                                        paymentDeadline: _queue!.paymentDeadline
                                            ?.toDate(),
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text(
                                  'Bayar Sekarang',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Allow customer to cancel the order while still awaiting payment
                              OutlinedButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool?>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Batalkan Pesanan'),
                                      content: const Text(
                                        'Apakah Anda yakin ingin membatalkan pesanan ini?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(c).pop(false),
                                          child: const Text('Batal'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(c).pop(true),
                                          child: const Text('Ya, Batalkan'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (!mounted) return;

                                  if (confirm == true) {
                                    try {
                                      await _queueService.cancelQueue(
                                        _queue!.id,
                                        reason: 'Cancelled by customer',
                                      );
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        // ignore: use_build_context_synchronously
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Pesanan dibatalkan'),
                                        ),
                                      );
                                      await _load();
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        // ignore: use_build_context_synchronously
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Gagal membatalkan: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text(
                                  'Batalkan Pesanan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        // Allow refund only when payment is verified/processed or the service already started/completed
                        if (((_queue!.paymentProofBase64 != null &&
                                    _queue!.paymentProofBase64!.isNotEmpty) &&
                                (_queue!.verifiedBy != null &&
                                    _queue!.verifiedBy!.isNotEmpty)) ||
                            _queue!.status == QueueStatus.ongoing ||
                            _queue!.status == QueueStatus.served ||
                            (_queue!.isRefunded == true))
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: OutlinedButton(
                              onPressed: () => _showCancellationDialog(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.orange),
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: const Text(
                                'Minta Pembatalan / Refund',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],

                  // Action button for cancelled bookings: offer to create new booking
                  if (_queue!.status == QueueStatus.cancelled)
                    ElevatedButton(
                      onPressed: () {
                        // Go back to booking screen to create new booking
                        Navigator.of(context).pop();
                        Navigator.of(
                          context,
                        ).pop(); // back to my_bookings or home
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text(
                        'Buat Booking Baru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
