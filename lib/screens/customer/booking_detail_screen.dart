// lib/screens/customer/booking_detail_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/models/service.dart' as model;
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'payment_screen.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;
const Color kSuccess = Color(0xFF4CAF50);
const Color kError = Color(0xFFD32F2F);
const Color kWarning = Color(0xFFFFA000);

class BookingDetailScreen extends StatefulWidget {
  final String queueId;
  final QueueService? queueService;
  final BarbershopService? barbershopService;

  const BookingDetailScreen({
    super.key,
    required this.queueId,
    this.queueService,
    this.barbershopService,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late final QueueService _queueService;
  late final BarbershopService _barbershopService;
  
  Barbershop? _barbershop;
  Barberman? _barberman;
  List<model.Service> _services = [];
  bool _metadataLoaded = false;

  @override
  void initState() {
    super.initState();
    _queueService = widget.queueService ?? QueueService();
    _barbershopService = widget.barbershopService ?? BarbershopService();
    _loadMetadata();
  }

  /// Load static metadata once (shop, barber, services names)
  Future<void> _loadMetadata() async {
    try {
      final q = await _queueService.getQueueById(widget.queueId);
      if (q != null) {
        final results = await Future.wait([
          _barbershopService.getBarbershopById(q.barbershopId),
          _barbershopService.getBarbermanById(q.barbermanId),
          _loadServices(q.serviceIds ?? (q.serviceId != null ? [q.serviceId!] : [])),
        ]);
        
        if (mounted) {
          setState(() {
            _barbershop = results[0] as Barbershop?;
            _barberman = results[1] as Barberman?;
            _services = results[2] as List<model.Service>;
            _metadataLoaded = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading metadata: $e");
    }
  }

  Future<List<model.Service>> _loadServices(List<String> ids) async {
    if (ids.isEmpty) return [];
    final all = await _barbershopService.getAllServices();
    return all.where((s) => ids.contains(s.id)).toList();
  }

  Future<void> _contactSupport(String bookingId) async {
    final String message = "Halo Admin Geges SmartBarber, saya butuh bantuan untuk Booking ID: $bookingId";
    final Uri whatsappUrl = Uri.parse("https://wa.me/6281234567890?text=${Uri.encodeComponent(message)}");
    if (!await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka WhatsApp support')),
        );
      }
    }
  }

  Future<void> _handleWithdraw(String qId) async {
    final confirm = await _showConfirmDialog('Tarik Pengajuan?', 'Batalkan permintaan refund dan aktifkan kembali pesanan Anda?');
    if (confirm == true) {
      try {
        await _queueService.withdrawCancellationRequest(qId);
      } catch (e) { _showSnack('Gagal: $e', isError: true); }
    }
  }

  Future<void> _handleRequestCancellation(String qId) async {
    final TextEditingController reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      backgroundColor: kDarkGrey,
      title: const Text('Minta Refund', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: reasonCtrl, maxLines: 3, style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(hintText: 'Alasan pembatalan...', border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kirim')),
      ],
    ));

    if (confirm == true && reasonCtrl.text.isNotEmpty) {
      try {
        await _queueService.customerRequestCancellation(qId, reason: reasonCtrl.text.trim());
      } catch (e) { _showSnack('Gagal: $e', isError: true); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Queue?>(
      stream: _queueService.streamQueueById(widget.queueId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_metadataLoaded) {
          return const Scaffold(backgroundColor: kSurface, body: Center(child: CircularProgressIndicator(color: kBrownAccent)));
        }
        
        final queue = snapshot.data;
        if (queue == null) {
          return const Scaffold(backgroundColor: kSurface, body: Center(child: Text('Data tidak ditemukan', style: TextStyle(color: Colors.white))));
        }

        final bool hasPaid = queue.paymentProofBase64 != null && queue.paymentProofBase64!.isNotEmpty;
        final bool isVerified = queue.verifiedBy != null && queue.verifiedBy!.isNotEmpty;
        final bool isRequested = queue.status == QueueStatus.cancellationRequested;

        return Scaffold(
          backgroundColor: kSurface,
          appBar: AppBar(
            title: const Text('Booking Detail', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: kSurface,
            elevation: 0,
            centerTitle: true,
          ),
          body: RefreshIndicator(
            onRefresh: _loadMetadata,
            color: kBrownAccent,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  _buildTicketCard(queue, hasPaid, isVerified, isRequested),
                  // FIX REFUND VISIBILITY
                  if (queue.isRefunded == true || queue.status == QueueStatus.cancelled || queue.requestStatus == RequestStatus.rejected) 
                    _buildRefundInfo(queue),
                  const SizedBox(height: 24),
                  _buildTimelineSection(queue, hasPaid, isVerified, isRequested),
                  const SizedBox(height: 32),
                  _buildActionButtons(queue, hasPaid, isVerified, isRequested),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildTicketCard(Queue queue, bool hasPaid, bool isVerified, bool isRequested) {
    return Container(
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // Header: Shop Name
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(_barbershop?.name.toUpperCase() ?? 'SMART BARBER', style: const TextStyle(color: kBrownAccent, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text(_barbershop?.addres ?? 'Detail Alamat...', textAlign: TextAlign.center, style: const TextStyle(color: kTextGrey, fontSize: 12)),
                const SizedBox(height: 16),
                _statusBadge(queue, hasPaid, isVerified, isRequested),
              ],
            ),
          ),
          
          _buildDashedLine(),

          // Body: Booking Time & Barber
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _infoColumn('WAKTU', DateFormat('HH:mm').format(queue.bookingTime.toDate())),
                const Spacer(),
                _infoColumn('TANGGAL', DateFormat('dd MMM yyyy').format(queue.bookingTime.toDate())),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: kBrownAccent.withValues(alpha: 0.2),
                  backgroundImage: _barberman?.imageUrl != null ? NetworkImage(_barberman!.imageUrl!) : null,
                  child: _barberman?.imageUrl == null ? const Icon(Icons.person, color: kBrownAccent) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('HAIRSTYLIST', style: TextStyle(color: kTextGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(_barberman?.name ?? 'Assigned by System', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildDashedLine(),

          // Services
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DETAIL LAYANAN', style: TextStyle(color: kTextGrey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._services.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      Text('Rp ${NumberFormat('#,###').format(s.price)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
                if (queue.paidBarberSelection == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Special Order Fee', style: TextStyle(color: kBrownAccent, fontSize: 13, fontStyle: FontStyle.italic)),
                        Text('Rp ${NumberFormat('#,###').format(queue.barberSelectionFee ?? 0)}', style: const TextStyle(color: kBrownAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                const Divider(color: Colors.white10, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL BAYAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text('Rp ${NumberFormat('#,###').format(queue.totalPrice ?? 0)}', style: const TextStyle(color: kBrownAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Center(
              child: Text('BOOKING ID: ${queue.id.toUpperCase()}', style: const TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(Queue queue, bool hasPaid, bool isVerified, bool isRequested) {
    final bool actuallyPaid = hasPaid || (queue.paymentProofUrl != null && queue.paymentProofUrl!.isNotEmpty);
    
    String label = 'BELUM BAYAR'; 
    Color color = Colors.orange;

    if (queue.status == QueueStatus.cancelled || queue.status.value == 'cancelled') { 
      label = 'DIBATALKAN'; color = kError; 
    } else if (queue.status == QueueStatus.cancellationRequested || isRequested) { 
      label = 'PERMOHONAN PEMBATALAN'; color = Colors.orange; 
    } else if (queue.status == QueueStatus.served || queue.status.value == 'served') {
      label = 'SELESAI'; color = kSuccess;
    } else if (queue.status == QueueStatus.ongoing || queue.status.value == 'ongoing') {
      label = 'SEDANG DIPROSES'; color = Colors.blue;
    } else if (queue.status == QueueStatus.booked || queue.status.value == 'booked') {
      label = 'TERJADWAL'; color = kSuccess;
    } else if (actuallyPaid) { 
      label = 'MENUNGGU VERIFIKASI'; color = Colors.amber; 
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStep(String title, String subtitle, bool isDone, {bool isLast = false, bool isCurrent = false}) {
    final Color color = isDone ? kBrownAccent : Colors.white24;
    final Color textColor = isDone ? Colors.white : Colors.white38;

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? Colors.transparent : color,
                  border: isCurrent ? Border.all(color: kBrownAccent, width: 2) : null,
                ),
                child: isDone && !isCurrent ? const Icon(Icons.check, size: 12, color: Colors.black) : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: color,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kTextGrey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDashedLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: List.generate(30, (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.transparent : Colors.white10,
            height: 1,
          ),
        )),
      ),
    );
  }

  Widget _buildTimelineSection(Queue queue, bool hasPaid, bool isVerified, bool isRequested) {
    final bool adminVerified = queue.status == QueueStatus.booked || queue.status == QueueStatus.ongoing || queue.status == QueueStatus.served;
    final bool isOngoing = queue.status == QueueStatus.ongoing || queue.status == QueueStatus.served;
    final bool isServed = queue.status == QueueStatus.served;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TRACKING STATUS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildStep('Booking Dibuat', 'Pesanan Anda telah diterima sistem', true),
        _buildStep('Pembayaran', hasPaid ? 'Bukti transfer telah diterima' : 'Menunggu penyelesaian pembayaran', hasPaid),
        _buildStep('Verifikasi Admin', adminVerified ? 'Pembayaran valid & Jadwal terkunci' : 'Menunggu validasi pembayaran', adminVerified),
        _buildStep('Sedang Dicukur', isOngoing ? 'Hairstylist sedang memberikan layanan' : 'Menunggu giliran layanan', isOngoing),
        if (isRequested) _buildStep('Refund', 'Dana dalam proses pengembalian', true, isCurrent: true),
        _buildStep('Selesai', 'Selesai layanan dan meninggalkan barbershop', isServed, isLast: true),
      ],
    );
  }

  Widget _buildRefundInfo(Queue queue) {
    final proof = queue.refundProofBase64;
    final bool isTextProof = proof != null && proof.startsWith('REF:');
    final String proofText = isTextProof ? proof.substring(4) : (proof ?? '-');
    final String reason = queue.refundReason ?? queue.rejectionReason ?? queue.cancellationReason ?? '-';

    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('INFORMASI PEMBATALAN / REFUND', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Alasan: $reason', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          
          if (proof != null && proof.isNotEmpty) ...[
            const Text('Bukti Refund:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (isTextProof)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                child: SelectableText(proofText, style: const TextStyle(color: Colors.white, fontFamily: 'Monospace')),
              )
            else
              GestureDetector(
                onTap: () => _showFullImage(context, proof),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                    image: DecorationImage(
                      image: MemoryImage(base64Decode(proof)),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              )
          ],
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String base64) {
    try {
      final Uint8List bytes = base64Decode(base64);
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showSnack('Gagal memuat gambar bukti', isError: true);
    }
  }

  Widget _buildActionButtons(Queue queue, bool hasPaid, bool isVerified, bool isRequested) {
    // 1. Status: Refund Requested -> Withdraw option
    if (isRequested) {
      return Column(
        children: [
          ElevatedButton(
            onPressed: () => _handleWithdraw(queue.id), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
            child: const Text('TARIK PENGAJUAN REFUND', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
          const SizedBox(height: 16),
          _buildCustomerServiceButton(queue.id),
        ],
      );
    }

    // 2. Status: Cancelled or Served -> Delete option (Cleanup)
    if (queue.status == QueueStatus.cancelled || queue.status == QueueStatus.served) {
      return Column(
        children: [
          _buildCustomerServiceButton(queue.id),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _handleDeleteOrder(queue.id),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('HAPUS PESANAN', style: TextStyle(color: Colors.white54)),
          ),
        ],
      );
    }

    // 3. Status: Waiting Payment -> Pay or Cancel
    if (!hasPaid) {
      return Column(children: [
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen(orderId: queue.id, totalPrice: queue.totalPrice ?? 0))),
          style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('BAYAR SEKARANG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 16),
        TextButton(onPressed: () => _showCancelUnpaidDialog(queue.id), child: const Text('Batalkan Pesanan', style: TextStyle(color: kError))),
      ]);
    }

    // Check if status is effectively confirmed regardless of 'verifiedBy' field
    final bool isStatusConfirmed = queue.status == QueueStatus.booked || queue.status == QueueStatus.ongoing || queue.status == QueueStatus.served;

    // 4. Status: Paid but Not Verified (and NOT confirmed via status) -> Wait + Info
    if (hasPaid && !isStatusConfirmed) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05), 
              borderRadius: BorderRadius.circular(16), 
              border: Border.all(color: Colors.white10)
            ),
            child: Column(children: [
              const Text(
                'Pembayaran sedang diverifikasi admin. Mohon tunggu.', 
                textAlign: TextAlign.center, 
                style: TextStyle(color: Colors.white70, fontSize: 13)
              ),
              const SizedBox(height: 16),
              _buildCustomerServiceButton(queue.id),
            ]),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pengajuan refund/pembatalan dapat dilakukan setelah verifikasi selesai.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      );
    }

    // 5. Status: Booked (Verified) -> Request Refund & CS
    if (queue.status == QueueStatus.booked) {
      return Column(
        children: [
          OutlinedButton(
            onPressed: () => _handleRequestCancellation(queue.id), 
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kWarning), 
              minimumSize: const Size.fromHeight(50), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ), 
            child: const Text('MINTA REFUND / BATAL', style: TextStyle(color: kWarning, fontWeight: FontWeight.bold))
          ),
          const SizedBox(height: 16),
          _buildCustomerServiceButton(queue.id),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCustomerServiceButton(String bookingId) {
    return ElevatedButton.icon(
      onPressed: () => _contactSupport(bookingId), 
      icon: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.black), 
      label: const Text('HUBUNGI ADMIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white, 
        elevation: 0,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
      ),
    );
  }

  Future<void> _handleDeleteOrder(String qId) async {
    final confirm = await _showConfirmDialog('Hapus Pesanan?', 'Pesanan akan dihapus permanen dari riwayat Anda.');
    if (confirm == true) {
      try {
        await _queueService.deleteQueue(qId);
        if (mounted) Navigator.pop(context); // Close detail screen
      } catch (e) {
        _showSnack('Gagal menghapus: $e', isError: true);
      }
    }
  }

  Future<void> _showCancelUnpaidDialog(String qId) async {
    final confirm = await _showConfirmDialog('Batal?', 'Pesanan belum dibayar dan akan langsung dibatalkan.');
    if (confirm == true) {
      try {
        await _queueService.cancelQueue(qId);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (_) {
        _showSnack('Gagal');
      }
    }
  }

  Future<bool?> _showConfirmDialog(String t, String d) {
    return showDialog<bool>(context: context, builder: (c) => AlertDialog(backgroundColor: kDarkGrey, title: Text(t, style: const TextStyle(color: Colors.white)), content: Text(d, style: const TextStyle(color: Colors.white70)), actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('KEMBALI')),
      ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent), child: const Text('OK', style: TextStyle(color: Colors.black))),
    ]));
  }

  void _showSnack(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: isError ? kError : kBrownAccent));
  }
}