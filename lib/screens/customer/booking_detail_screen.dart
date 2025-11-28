/// Booking Detail Screen - Professional Production Version
///
/// Features:
/// - Complete booking information display
/// - Smart payment button logic (only visible if awaiting_payment AND no proof locked)
/// - Real-time countdown timer with color-coding
/// - Professional Material Design 3 cards
/// - Status tracking with clear visual indicators
/// - Payment proof upload tracking
/// - Refund and cancellation handling
/// - Deep booking details (date, time, services, price breakdown)
/// - Professional styling and animations

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'payment_screen.dart';

// ============================================================
// Color Palette
// ============================================================
const Color kColorPrimary = Color(0xFF2C3E50);
const Color kColorPrimaryDark = Color(0xFF1A252F);
const Color kColorSuccess = Color(0xFF27AE60);
const Color kColorWarning = Color(0xFFF39C12);
const Color kColorDanger = Color(0xFFE74C3C);
const Color kColorInfo = Color(0xFF3498DB);
const Color kColorPending = Color(0xFF8E44AD);
const Color kColorBackground = Color(0xFFF5F6F7);
const Color kTextGrey = Colors.white70;

// ============================================================
// Status Mapping
// ============================================================
const Map<String, String> _statusLabelMap = {
  'created': 'Menunggu Konfirmasi',
  'confirmed': 'Confirmed',
  'awaiting_payment': 'Menunggu Pembayaran',
  'payment_pending': 'Pembayaran Dikirim',
  'paid_verified': 'Terbayar',
  'cancelled': 'Dibatalkan',
};

// ============================================================
// Main Screen
// ============================================================
class BookingDetailScreen extends StatefulWidget {
  final String queueId;

  const BookingDetailScreen({
    super.key,
    required this.queueId,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  final QueueService _queueService = QueueService();
  Queue? _queue;
  bool _loading = true;
  String? _loadError;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final q = await _queueService.getQueueById(widget.queueId);
      setState(() {
        _queue = q;
        _loading = false;
      });
      _startCountdownTimer();
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    if (_queue?.paymentDeadline == null) return;

    // Calculate initial remaining time
    final now = DateTime.now();
    final deadline = _queue!.paymentDeadline!.toDate();
    final remaining = deadline.difference(now);

    if (remaining.isNegative) {
      setState(() => _remainingTime = Duration.zero);
      return;
    }

    setState(() => _remainingTime = remaining);

    // Update timer every second
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

  /// Check if user can pay
  /// Only show pay button if:
  /// 1. Status is 'awaiting_payment' or 'booked'/'confirmed'
  /// 2. Payment proof is NOT locked
  /// 3. No proof has been uploaded yet (or proof is null)
  bool get _canShowPayButton {
    if (_queue == null) return false;
    
    final status = _queue!.status?.toString() ?? '';
    final paymentData = _getPaymentData();
    final proofLocked = paymentData['proofLocked'] as bool? ?? false;
    final proofUrl = paymentData['proofUrl'] as String?;

    // Can pay if: (status is awaiting/confirmed) AND (not locked) AND (no existing proof)
    final correctStatus = status == 'awaiting_payment' || 
                          status == 'booked' || 
                          status == 'confirmed';
    
    return correctStatus && !proofLocked && proofUrl == null;
  }

  /// Check if we can view the uploaded proof
  bool get _canShowViewProofButton {
    if (_queue == null) return false;
    
    final paymentData = _getPaymentData();
    final proofUrl = paymentData['proofUrl'] as String?;
    final proofLocked = paymentData['proofLocked'] as bool? ?? false;
    
    return proofUrl != null && proofLocked;
  }

  /// Get payment data from queue
  Map<String, dynamic> _getPaymentData() {
    if (_queue == null) return {};
    
    final data = _queue!.toJson();
    return Map<String, dynamic>.from(data['payment'] ?? {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Booking'),
          backgroundColor: kColorPrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null || _queue == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Booking'),
          backgroundColor: kColorPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 60, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text(
                'Gagal memuat booking',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                _loadError ?? 'Booking tidak ditemukan',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorInfo,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final paymentData = _getPaymentData();
    final status = _queue!.status?.toString() ?? 'unknown';

    return Scaffold(
      backgroundColor: kColorBackground,
      appBar: AppBar(
        title: const Text('Detail Booking'),
        backgroundColor: kColorPrimary,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================================================
            // Header Card: Status & ID
            // ============================================================
            _buildHeaderCard(),
            const SizedBox(height: 16),

            // ============================================================
            // Booking Info Card
            // ============================================================
            _buildBookingInfoCard(),
            const SizedBox(height: 16),

            // ============================================================
            // Payment Status Card
            // ============================================================
            _buildPaymentStatusCard(paymentData),
            const SizedBox(height: 16),

            // ============================================================
            // Countdown Timer (if awaiting payment)
            // ============================================================
            if (_queue!.paymentDeadline != null && status == 'awaiting_payment')
              _buildCountdownCard(),
            if (_queue!.paymentDeadline != null && status == 'awaiting_payment')
              const SizedBox(height: 16),

            // ============================================================
            // Cancellation/Refund Info (if cancelled)
            // ============================================================
            if (status == 'cancelled')
              _buildCancellationCard(),
            if (status == 'cancelled')
              const SizedBox(height: 16),

            // ============================================================
            // Action Buttons
            // ============================================================
            _buildActionButtons(paymentData),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Card Builders
  // ============================================================

  Widget _buildHeaderCard() {
    final status = _queue!.status?.toString() ?? 'unknown';
    final statusLabel = _getStatusLabel(status);
    final statusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withOpacity(0.1),
              statusColor.withOpacity(0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Booking ID',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _queue!.id,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: kColorPrimaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingInfoCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Booking',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kColorPrimaryDark,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey[200], height: 1),
            const SizedBox(height: 12),
            // Date & Time
            _buildInfoRow(
              icon: Icons.event,
              label: 'Jadwal',
              value: _queue!.bookingTime != null
                  ? DateFormat('EEEE, d MMM yyyy pukul HH:mm')
                      .format(_queue!.bookingTime!.toDate())
                  : '-',
            ),
            const SizedBox(height: 12),
            // Duration
            _buildInfoRow(
              icon: Icons.schedule,
              label: 'Durasi',
              value: _queue!.estimatedDuration != null
                  ? '${_queue!.estimatedDuration} menit'
                  : '-',
            ),
            const SizedBox(height: 12),
            // Barbershop
            _buildInfoRow(
              icon: Icons.storefront,
              label: 'Barbershop',
              value: _queue!.barbershopId ?? '-',
            ),
            const SizedBox(height: 12),
            // Barber
            _buildInfoRow(
              icon: Icons.person,
              label: 'Barber',
              value: _queue!.barbermanId ?? '-',
            ),
            const SizedBox(height: 12),
            // Price
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Pembayaran',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'Rp ${NumberFormat('#,###', 'id_ID').format(_queue!.totalPrice ?? 0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusCard(Map<String, dynamic> paymentData) {
    final proofUrl = paymentData['proofUrl'] as String?;
    final proofLocked = paymentData['proofLocked'] as bool? ?? false;
    final verificationStatus = paymentData['verificationStatus'] as String?;
    final proofUploadedAt = paymentData['proofUploadedAt'] as Timestamp?;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Pembayaran',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kColorPrimaryDark,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey[200], height: 1),
            const SizedBox(height: 12),
            // Proof Status
            if (proofUrl != null) ...[
              _buildStatusIndicator(
                icon: Icons.check_circle,
                color: Colors.green,
                label: 'Bukti pembayaran terunggah',
                timestamp: proofUploadedAt,
              ),
              const SizedBox(height: 8),
            ] else ...[
              _buildStatusIndicator(
                icon: Icons.cloud_upload,
                color: Colors.grey,
                label: 'Menunggu bukti pembayaran',
              ),
              const SizedBox(height: 8),
            ],

            // Lock Status
            if (proofLocked) ...[
              _buildStatusIndicator(
                icon: Icons.lock,
                color: Colors.orange,
                label: 'Upload terkunci - menunggu verifikasi admin',
              ),
              const SizedBox(height: 8),
            ],

            // Verification Status
            if (verificationStatus != null) ...[
              if (verificationStatus == 'pending') ...[
                _buildStatusIndicator(
                  icon: Icons.hourglass_empty,
                  color: kColorPending,
                  label: 'Menunggu verifikasi admin',
                ),
              ] else if (verificationStatus == 'approved') ...[
                _buildStatusIndicator(
                  icon: Icons.verified,
                  color: Colors.green,
                  label: 'Verifikasi berhasil - pembayaran diterima',
                ),
              ] else if (verificationStatus == 'rejected') ...[
                _buildStatusIndicator(
                  icon: Icons.close_circle,
                  color: Colors.red,
                  label: 'Bukti ditolak - silahkan upload ulang',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownCard() {
    final hasExpired = _remainingTime.inSeconds <= 0;
    Color countdownColor = kColorInfo;
    
    if (hasExpired) {
      countdownColor = Colors.red;
    } else if (_remainingTime.inMinutes < 2) {
      countdownColor = Colors.red;
    } else if (_remainingTime.inMinutes < 5) {
      countdownColor = Colors.orange;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: countdownColor,
            width: 2,
          ),
          color: countdownColor.withOpacity(0.05),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'SISA WAKTU PEMBAYARAN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: countdownColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _formatCountdown(_remainingTime),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: countdownColor,
                fontFamily: 'monospace',
                fontVariations: const [FontVariation('wght', 900)],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Batas waktu: ${DateFormat('EEEE, d MMM HH:mm').format(_queue!.paymentDeadline!.toDate())}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            if (hasExpired) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '⚠️ Waktu pembayaran telah habis. Silahkan hubungi admin.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCancellationCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red, width: 1),
          color: Colors.red.withOpacity(0.05),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel, color: Colors.red[600], size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Booking Dibatalkan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_queue!.rejectionReason != null &&
                _queue!.rejectionReason!.isNotEmpty) ...[
              Text(
                'Alasan: ${_queue!.rejectionReason}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_queue!.isRefunded == true) ...[
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 18),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Refund telah diproses',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Action Buttons
  // ============================================================
  Widget _buildActionButtons(Map<String, dynamic> paymentData) {
    return Column(
      children: [
        // Pay Button (ONLY show if: awaiting_payment && no proof locked && no existing proof)
        if (_canShowPayButton) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => PaymentScreen(
                      orderId: _queue!.id,
                      totalPrice: _queue!.totalPrice ?? 0,
                      barbershopId: _queue!.barbershopId,
                      barbermanId: _queue!.barbermanId,
                      bookingTime: _queue!.bookingTime!.toDate(),
                      serviceIds: _queue!.serviceIds,
                      paymentDeadline: _queue!.paymentDeadline?.toDate(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.payment, size: 20),
              label: const Text('Bayar Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // View Proof Button (show if proof locked)
        if (_canShowViewProofButton) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => PaymentScreen(
                      orderId: _queue!.id,
                      totalPrice: _queue!.totalPrice ?? 0,
                      barbershopId: _queue!.barbershopId,
                      barbermanId: _queue!.barbermanId,
                      bookingTime: _queue!.bookingTime!.toDate(),
                      serviceIds: _queue!.serviceIds,
                      paymentDeadline: _queue!.paymentDeadline?.toDate(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.image, size: 20),
              label: const Text('Lihat Bukti Pembayaran'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // New Booking Button (show if cancelled)
        if (_queue!.status?.toString() == 'cancelled') ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Buat Booking Baru'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kColorInfo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Back Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 20),
            label: const Text('Kembali'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Helper Methods
  // ============================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required Color color,
    required String label,
    Timestamp? timestamp,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM HH:mm').format(timestamp.toDate()),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    return _statusLabelMap[status] ?? status;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'created':
        return kColorInfo;
      case 'confirmed':
        return Colors.blue;
      case 'awaiting_payment':
      case 'booked':
        return kColorWarning;
      case 'payment_pending':
        return kColorPending;
      case 'paid_verified':
        return kColorSuccess;
      case 'cancelled':
        return kColorDanger;
      default:
        return Colors.grey;
    }
  }

  String _formatCountdown(Duration duration) {
    if (duration.inSeconds <= 0) {
      return 'WAKTU HABIS';
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
