// lib/screens/admin/booking_confirmation_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

// ==========================
// Konstanta warna tema
// ==========================
const kDarkSurface = Color(0xFF1E1E1E);
const kBrownAccent = Color(0xFFD4A373);

class BookingConfirmationScreen extends StatefulWidget {
  const BookingConfirmationScreen({super.key});

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  final _processingIds = <String>{};
  final QueueService _queueService = QueueService();

  Stream<QuerySnapshot<Map<String, dynamic>>> _waitingBookingsStream() {
    // Menampilkan semua queue yang status == 'waiting' dan belum disetujui (request_status == 'pending')
    // Ini mencegah dokumen yang sudah dipindah ke 'awaiting_payment' untuk muncul kembali.
    return FirebaseFirestore.instance
      .collection('queues')
      .where('status', isEqualTo: 'waiting')
      .where('request_status', isEqualTo: 'pending')
      .orderBy('booking_time', descending: false)
      .snapshots();
  }

  // Ambil field bukti pembayaran dari dokumen (mendukung beberapa nama field)
  String? _extractProof(Map<String, dynamic> data) {
    if (data['payment_proof_base64'] != null &&
        (data['payment_proof_base64'] as String).isNotEmpty) {
      return data['payment_proof_base64'] as String;
    }
    if (data['payment_proof_url'] != null &&
        (data['payment_proof_url'] as String).isNotEmpty) {
      return data['payment_proof_url'] as String;
    }
    if (data['payment_proof'] != null && (data['payment_proof'] as String).isNotEmpty) {
      return data['payment_proof'] as String;
    }
    return null;
  }

  // Safe decode: remove `data:image/...;base64,` prefix jika ada
  Uint8List? _tryDecodeBase64(String raw) {
    try {
      final dataPrefix = RegExp(r'data:image\/[a-zA-Z0-9.+-]+;base64,');
      final cleaned = raw.replaceAll(dataPrefix, '');
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  // ==========================
  // KONFIRMASI BOOKING REQUEST (waiting → awaiting_payment)
  // ==========================
  // PENTING: Admin hanya confirm request di sini
  // Booking TIDAK langsung bisa masuk Live Queue
  // Harus: waiting → awaiting_payment (tunggu customer bayar)
  //       → awaiting_payment + payment_proof → booked (setelah admin verify payment)
  //       → booked → masuk Live Queue baru
  Future<void> _confirmPayment(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final id = doc.id;
    if (_processingIds.contains(id)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kDarkSurface,
        title: const Text('Konfirmasi Permintaan Booking',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Konfirmasi permintaan booking ini?\n\n'
          'Setelah konfirmasi:\n'
          '• Status berubah ke MENUNGGU PEMBAYARAN (awaiting_payment)\n'
          '• Customer punya 10 menit untuk upload bukti pembayaran\n'
          '• Tidak langsung masuk Live Queue\n'
          '• Anda harus verifikasi pembayaran dahulu',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal', style: TextStyle(color: kBrownAccent))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Konfirmasi Request', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingIds.add(id));
    try {
      // Gunakan adminConfirmRequest dari QueueService
      // Ini akan set status ke 'awaiting_payment' dan start payment window (10 menit)
      await _queueService.adminConfirmRequest(id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Booking request dikonfirmasi — menunggu customer pembayaran (10 menit)'),
            backgroundColor: kBrownAccent,
            duration: Duration(seconds: 3)),
      );
    } catch (e) {
      debugPrint('Error _confirmPayment: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal konfirmasi: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _processingIds.remove(id));
    }
  }

  // ==========================
  // TOLAK / REJECT BOOKING -> cancelled
  // ==========================
  Future<void> _rejectBooking(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final id = doc.id;
    if (_processingIds.contains(id)) return;

    final confirmedBy = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final ref = doc.reference;

    // input alasan singkat (opsional)
    final TextEditingController reasonC = TextEditingController();

    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: kDarkSurface,
        title: const Text('Tolak Booking', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Berikan alasan penolakan (opsional):', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(controller: reasonC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Alasan...', hintStyle: TextStyle(color: Colors.white38))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal', style: TextStyle(color: kBrownAccent))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldReject != true) return;

    setState(() => _processingIds.add(id));
    try {
      await ref.update({
        'status': 'cancelled',
        'cancellation_reason': (reasonC.text.isNotEmpty) ? reasonC.text : 'Ditolak oleh admin',
        'cancelled_by_uid': confirmedBy,
        'cancelled_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking berhasil ditolak'), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      debugPrint('Error rejectBooking: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menolak booking: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _processingIds.remove(id));
    }
  }

  // ==========================
  // VIEWER BUKTI PEMBAYARAN
  // ==========================
  Future<void> _showProofDialog(String? proofBase64OrUrl) async {
    if (proofBase64OrUrl == null || proofBase64OrUrl.isEmpty) {
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: kDarkSurface,
          content: const Text('Tidak ada bukti pembayaran', style: TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup'))],
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (c) => FullScreenProofViewer(proof: proofBase64OrUrl),
      ),
    );
  }

  Widget _buildProofViewerWidget(String? proofBase64OrUrl) {
    if (proofBase64OrUrl == null || proofBase64OrUrl.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(8)),
        child: const Text('Belum ada bukti pembayaran', style: TextStyle(color: Colors.white54)),
      );
    }

    if (proofBase64OrUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(proofBase64OrUrl, height: 160, fit: BoxFit.cover),
      );
    }

    final bytes = _tryDecodeBase64(proofBase64OrUrl);
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(bytes, height: 160, fit: BoxFit.cover),
      );
    }

    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(8)),
      child: const Text('Format bukti tidak dikenali', style: TextStyle(color: Colors.white54)),
    );
  }

  // ==========================
  // BUILD UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkSurface,
      appBar: AppBar(
        backgroundColor: kDarkSurface,
        title: const Text('Konfirmasi Booking', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _waitingBookingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kBrownAccent));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Tidak ada booking waiting', style: TextStyle(color: Colors.white70)));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              final id = doc.id;
              final name = (data['customer_name'] as String?) ?? (data['customer_id'] as String?) ?? 'Tanpa Nama';
              final service = (data['service_name'] as String?) ?? '-';
              final proof = _extractProof(data);
              final bookingTime = (data['booking_time'] is Timestamp) ? (data['booking_time'] as Timestamp) : null;
              final isLoading = _processingIds.contains(id);

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                      if (bookingTime != null) Text(DateTime.fromMillisecondsSinceEpoch(bookingTime.seconds * 1000).toLocal().toString().split('.').first, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ]),
                    const SizedBox(height: 6),
                    Text('Layanan: $service', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showProofDialog(proof),
                      child: _buildProofViewerWidget(proof),
                    ),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                        onPressed: isLoading ? null : () => _rejectBooking(doc),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        child: const Text('Tolak'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: isLoading ? null : () => _confirmPayment(doc),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrownAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.check_circle),
                        label: Text(isLoading ? 'Memproses...' : 'Konfirmasi'),
                      ),
                    ])
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================
// FULL SCREEN VIEWER
// ==========================
class FullScreenProofViewer extends StatelessWidget {
  final String proof;
  const FullScreenProofViewer({super.key, required this.proof});

  Uint8List? _tryDecodeBase64(String raw) {
    try {
      final dataPrefix = RegExp(r'data:image\/[a-zA-Z0-9.+-]+;base64,');
      final cleaned = raw.replaceAll(dataPrefix, '');
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  Widget _buildContent() {
    if (proof.startsWith('http')) {
      return Image.network(proof, fit: BoxFit.contain);
    }
    final bytes = _tryDecodeBase64(proof);
    if (bytes != null) return Image.memory(bytes, fit: BoxFit.contain);
    return const Center(child: Text('Format gambar tidak dikenali', style: TextStyle(color: Colors.white70)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Bukti Pembayaran', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: _buildContent(),
        ),
      ),
    );
  }
}
