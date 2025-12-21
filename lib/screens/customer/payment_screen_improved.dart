// Payment Screen yang diperbaiki untuk mencegah double-upload
//
// Features:
// - Disable upload button setelah submit sukses
// - Optimistic UI (tampilkan loading saat submit)
// - Snapshot listener untuk real-time status
// - Error handling & user feedback
// - Countdown timer untuk payment deadline
// Gunakan sebagai pengganti/patch untuk payment_screen.dart yang sudah ada

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:geges_smartbarber/services/booking_anti_duplicate_service.dart';

class PaymentScreenImproved extends StatefulWidget {
  final String bookingId;
  final int totalPrice;

  const PaymentScreenImproved({
    super.key,
    required this.bookingId,
    required this.totalPrice,
  });

  @override
  State<PaymentScreenImproved> createState() => _PaymentScreenImprovedState();
}

class _PaymentScreenImprovedState extends State<PaymentScreenImproved> {
  late BookingAntiDuplicateService _antiDupService;
  
  bool _isSubmitting = false;
  String? _proofUrl;
  bool _proofLocked = false;
  String? _verificationStatus;
  DateTime? _paymentDeadline;
  Duration _timeRemaining = const Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _antiDupService = BookingAntiDuplicateService();
    _startListeningToBookingChanges();
    _startCountdown();
  }

  void _startListeningToBookingChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen ke booking snapshot untuk real-time updates
    FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? {};
      final payment = Map<String, dynamic>.from(data['payment'] ?? {});

      setState(() {
        _proofUrl = payment['proofUrl'] as String?;
        _proofLocked = payment['proofLocked'] as bool? ?? false;
        _verificationStatus = payment['verificationStatus'] as String?;

        if (payment['deadlineAt'] is Timestamp) {
          _paymentDeadline = (payment['deadlineAt'] as Timestamp).toDate();
        }
      });
    });
  }

  void _startCountdown() {
    // Update countdown setiap detik
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _paymentDeadline != null) {
        final remaining = _paymentDeadline!.difference(DateTime.now());
        setState(() {
          _timeRemaining = remaining.isNegative ? Duration.zero : remaining;
        });
        
        if (_timeRemaining.inSeconds > 0) {
          _startCountdown();
        }
      }
    });
  }

  Future<void> _submitProof(String proofUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('User tidak authenticated');
      return;
    }

    if (_proofLocked) {
      _showError('Bukti pembayaran sudah dikirim — tidak dapat submit ulang');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _antiDupService.submitPaymentProof(
        bookingId: widget.bookingId,
        proofUrl: proofUrl,
        userId: user.uid,
      );

      if (mounted) {
        _showSuccess('Bukti pembayaran berhasil dikirim!\nMenunggu verifikasi admin...');
        
        // Snapshot listener akan otomatis update UI
        setState(() => _proofLocked = true);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        _showError('Gagal submit: $errorMsg');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(int amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0)
        .format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final isTimeExpired = _timeRemaining.inSeconds <= 0;
    final hasProof = _proofUrl != null && _proofUrl!.isNotEmpty;
    final isPending = _verificationStatus == 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== HEADER INFORMASI ==========
            _buildInfoCard('Total Pembayaran', _formatCurrency(widget.totalPrice)),

            const SizedBox(height: 20),

            // ========== COUNTDOWN TIMER ==========
            _buildTimerCard(isTimeExpired),

            const SizedBox(height: 20),

            // ========== BANK DETAILS ==========
            _buildBankDetailsCard(),

            const SizedBox(height: 20),

            // ========== STATUS BADGE ==========
            if (hasProof)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPending ? Colors.orange[100] : Colors.green[100],
                  border: Border.all(
                    color: isPending ? Colors.orange : Colors.green,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPending ? Icons.hourglass_bottom : Icons.check_circle,
                      color: isPending ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPending ? 'Pembayaran Dikirim' : 'Pembayaran Diverifikasi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isPending ? Colors.orange[700] : Colors.green[700],
                            ),
                          ),
                          Text(
                            isPending
                                ? 'Menunggu verifikasi admin...'
                                : 'Pembayaran sudah dikonfirmasi',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (_proofLocked)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Colors.grey),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Upload sudah terkunci — hubungi admin jika ada kesalahan',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ========== SUBMIT BUTTON ==========
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting || _proofLocked || isTimeExpired
                    ? null
                    : () => _submitProof('https://example.com/proof'), // TODO: get real proof URL
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  disabledBackgroundColor: Colors.grey,
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  _isSubmitting
                      ? 'Mengirim...'
                      : (_proofLocked ? 'Bukti Sudah Dikirim' : 'Kirim Bukti Pembayaran'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ========== INFO TEXT ==========
            if (isTimeExpired)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Waktu pembayaran sudah habis. Booking dibatalkan.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard(bool isExpired) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpired ? Colors.red[50] : Colors.blue[50],
        border: Border.all(
          color: isExpired ? Colors.red : Colors.blue,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isExpired ? 'Waktu Habis' : 'Selesaikan dalam',
                style: TextStyle(
                  fontSize: 12,
                  color: isExpired ? Colors.red : Colors.blue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isExpired ? '00:00' : _formatDuration(_timeRemaining),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isExpired ? Colors.red : Colors.blue,
                ),
              ),
            ],
          ),
          Icon(
            isExpired ? Icons.close_rounded : Icons.schedule,
            size: 40,
            color: isExpired ? Colors.red : Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail Bank',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Bank', 'BCA'),
          _buildDetailRow('Rekening', '87705955837'),
          _buildDetailRow('Atas Nama', 'FEBRIAN BARBERSHOP'),
          _buildDetailRow('Jumlah', _formatCurrency(widget.totalPrice)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
