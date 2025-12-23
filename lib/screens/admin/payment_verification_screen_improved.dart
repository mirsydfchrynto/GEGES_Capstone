// Admin Payment Verification Screen
//
// Menampilkan hanya booking dengan payment.verificationStatus == 'pending'
// Satu entry per bookingId (deduplicated)
//
// Admin dapat:
// - Accept → verificationStatus='accepted', status='paid_verified'
// - Reject → verificationStatus='rejected', status='confirmed' (allow re-upload)
// - View payment proof

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:geges_smartbarber/services/booking_anti_duplicate_service.dart';

class PaymentVerificationScreenImproved extends StatefulWidget {
  const PaymentVerificationScreenImproved({super.key});

  @override
  State<PaymentVerificationScreenImproved> createState() =>
      _PaymentVerificationScreenImprovedState();
}

class _PaymentVerificationScreenImprovedState
    extends State<PaymentVerificationScreenImproved> {
  late BookingAntiDuplicateService _antiDupService;

  @override
  void initState() {
    super.initState();
    _antiDupService = BookingAntiDuplicateService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Pembayaran'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<DocumentSnapshot>>(
        stream: _antiDupService.streamPaymentVerificationQueue(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final bookings = snapshot.data ?? [];

          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.done_all, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Tidak ada pembayaran yang perlu diverifikasi',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (context, i) => _buildBookingCard(bookings[i]),
          );
        },
      ),
    );
  }

  Widget _buildBookingCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bookingId = doc.id;
    final payment = Map<String, dynamic>.from(data['payment'] ?? {});
    final totalPrice = payment['amount'] as int? ?? 0;
    final proofUrl = payment['proofUrl'] as String?;
    final uploadedAt = payment['proofUploadedAt'] as Timestamp?;
    // final uploadedBy = payment['proofUploadedBy'] as String?;
    final scheduledAt = data['scheduledAt'] as Timestamp?;
    final userId = data['userId'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dengan Booking ID dan Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking: $bookingId',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (userId != null)
                        Text(
                          'Customer: $userId',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Detail booking
            _buildDetailRow('Total Pembayaran', 'Rp ${NumberFormat('#,###', 'id_ID').format(totalPrice)}'),
            if (scheduledAt != null)
              _buildDetailRow(
                'Jadwal Booking',
                DateFormat('dd MMM yyyy, HH:mm').format(scheduledAt.toDate()),
              ),
            if (uploadedAt != null)
              _buildDetailRow(
                'Bukti Dikirim',
                DateFormat('dd MMM yyyy, HH:mm:ss').format(uploadedAt.toDate()),
              ),
            const SizedBox(height: 12),

            // Preview bukti pembayaran
            if (proofUrl != null && proofUrl.isNotEmpty)
              _buildProofPreview(proofUrl)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tidak ada bukti pembayaran',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRejectDialog(bookingId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleAccept(bookingId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Terima'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofPreview(String proofUrl) {
    return GestureDetector(
      onTap: () => _showProofFullscreen(proofUrl),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (proofUrl.startsWith('http'))
              CachedNetworkImage(
                imageUrl: proofUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Center(child: Text('Gagal load gambar')),
              )
            else
              Center(
                child: Icon(Icons.image, size: 60, color: Colors.grey[400]),
              ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProofFullscreen(String proofUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Bukti Pembayaran'),
              automaticallyImplyLeading: true,
            ),
            Expanded(
              child: Container(
                color: Colors.grey[900],
                child: proofUrl.startsWith('http')
                    ? CachedNetworkImage(imageUrl: proofUrl, fit: BoxFit.contain, placeholder: (c, u) => const Center(child: CircularProgressIndicator()), errorWidget: (c, u, e) => const Center(child: Text('Gambar tidak tersedia')))
                    : const Center(child: Text('Gambar tidak tersedia')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAccept(String bookingId) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) {
      _showError('Admin tidak authenticated');
      return;
    }

    try {
      await _antiDupService.acceptPaymentVerification(
        bookingId: bookingId,
        adminUid: admin.uid,
        adminNotes: 'Verified by admin ${admin.email}',
      );

      if (mounted) {
        _showSuccess('Pembayaran diterima!');
        // Stream listener akan otomatis update list
      }
    } catch (e) {
      if (mounted) {
        _showError('Gagal terima: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  void _showRejectDialog(String bookingId) {
    final reasonCtrl = TextEditingController();
    final allowReuploadCtrl = ValueNotifier(true);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'Alasan penolakan',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: allowReuploadCtrl,
              builder: (context, allowReupload, _) => CheckboxListTile(
                title: const Text('Izinkan customer upload ulang'),
                value: allowReupload,
                onChanged: (val) {
                  allowReuploadCtrl.value = val ?? true;
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleReject(bookingId, reasonCtrl.text, allowReuploadCtrl.value);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReject(
    String bookingId,
    String reason,
    bool allowReupload,
  ) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) {
      _showError('Admin tidak authenticated');
      return;
    }

    try {
      await _antiDupService.rejectPaymentVerification(
        bookingId: bookingId,
        adminUid: admin.uid,
        rejectionReason: reason.isNotEmpty ? reason : 'Bukti tidak valid',
        allowReupload: allowReupload,
      );

      if (mounted) {
        _showSuccess('Pembayaran ditolak${allowReupload ? ' — customer dapat upload ulang' : ''}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Gagal tolak: ${e.toString().replaceAll('Exception: ', '')}');
      }
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
}
